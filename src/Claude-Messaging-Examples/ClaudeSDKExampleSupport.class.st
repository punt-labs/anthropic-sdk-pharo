"
Shared API-key resolution for every Messaging-SDK example. Walks a fixed, documented ladder of locations and returns a fresh ``ClaudeClient`` bound to the first non-empty key it finds, or raises when none is available.

### When you use it

Every runnable example in ``Claude-Messaging-Examples`` calls ``resolveClient`` as its first line so a developer running an example by hand does not have to thread an API key through every selector. Use it in your own scratch scripts for the same reason. Not meant for library code -- library entry points should take a ``ClaudeClient`` argument and let the caller choose where the key lives.

### The resolution ladder

Two tiers, most-specific first. The Pharo override slot lets you point a Pharo image at a different key without disturbing the general ``ANTHROPIC_API_KEY`` your other tooling uses. Within each slot the environment variable is tried first, then the OS keyring. The first slot that yields a non-empty key wins. A present-but-empty env var counts as absent and falls through.

| Slot | Env var | Keyring service | Keyring account |
|------|---------|-----------------|-----------------|
| 1. Pharo override | ANTHROPIC_PHARO_API_KEY | anthropic | pharo-api-key |
| 2. General        | ANTHROPIC_API_KEY        | anthropic | api-key       |

The SDK reads these documented identities only -- it never inspects key values, never guesses your store layout, and never searches beyond the four locations above.

### Provisioning a key

Set an env var, or store one in the OS keyring under the documented identity:

```
pass insert anthropic/api-key
secret-tool store --label='Anthropic API Key' service anthropic account api-key
security add-generic-password -U -s anthropic -a api-key -w
```

### Lives in Layer 2

This class sits in ``Claude-Messaging-Examples`` deliberately. The Agent-layer example support (``ClaudeExampleSupport``) would pull in Agent dependencies; the Messaging SDK must not depend on them. Keep new Messaging examples on ``ClaudeSDKExampleSupport``.

### Example

```
ClaudeSDKExampleSupport resolveClient
>>> a ClaudeClient
```

```
| client |
client := ClaudeSDKExampleSupport resolveClient.
client baseUrl
>>> 'https://api.anthropic.com'
```

### See also

``ClaudeClient >> apiKey:`` -- the constructor that ``resolveClient`` wraps. ``PharoKeyring`` -- the cross-platform keyring facade. ``ClaudeSimpleMessageExample`` -- the simplest example that demonstrates the typical ``resolveClient`` pattern.

"
Class {
	#name : 'ClaudeSDKExampleSupport',
	#superclass : 'Object',
	#category : 'Claude-Messaging-Examples',
	#package : 'Claude-Messaging-Examples'
}

{ #category : 'private' }
ClaudeSDKExampleSupport class >> keyFor: aSlot [
	"Resolve a non-empty key for one ladder slot, env-first then keyring.
	Answer nil when neither source yields a non-empty string."
	| envName service account key |
	envName := aSlot first.
	service := aSlot second.
	account := aSlot third.
	key := Smalltalk os environment at: envName ifAbsent: [ nil ].
	(key isNil or: [ key isEmpty ]) ifFalse: [ ^ key ].
	key := [ PharoKeyring default lookup: service account: account ]
		on: Error do: [ :e | nil ].
	(key isNil or: [ key isEmpty ]) ifFalse: [ ^ key ].
	^ nil
]

{ #category : 'private' }
ClaudeSDKExampleSupport class >> keySlots [
	"Ordered resolution ladder, most-specific first. Each slot is
	{ envVarName. keyringService. keyringAccount }. Within a slot the
	env var wins over the keyring; the first slot to yield a non-empty
	key wins overall."
	^ {
		{ 'ANTHROPIC_PHARO_API_KEY'. 'anthropic'. 'pharo-api-key' }.
		{ 'ANTHROPIC_API_KEY'. 'anthropic'. 'api-key' } }
]

{ #category : 'accessing' }
ClaudeSDKExampleSupport class >> resolveClient [
	"Resolve a ClaudeClient by walking the two-tier key ladder
	(Pharo override then general), env-first within each slot. Signal
	an Error listing all four locations when no slot yields a key."
	self keySlots do: [ :slot |
		| key |
		key := self keyFor: slot.
		key ifNotNil: [ ^ ClaudeClient apiKey: key ] ].
	Error signal: 'No Anthropic API key found. Provision one of (most-specific first):
1. ANTHROPIC_PHARO_API_KEY env var, or keyring service anthropic account pharo-api-key
2. ANTHROPIC_API_KEY env var, or keyring service anthropic account api-key
Keyring by backend:
  pass:        pass insert anthropic/api-key
  secret-tool: secret-tool store --label=''Anthropic API Key'' service anthropic account api-key
  security:    security add-generic-password -U -s anthropic -a api-key -w'
]
