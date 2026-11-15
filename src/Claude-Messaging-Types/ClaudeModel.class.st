"
Model ID constants for the Claude API. Class-side factory methods return model identifier strings.

The Claude 5 family (current generation) plus Opus 4.8, the one prior-generation
model kept for callers that still pin it. Earlier 4.x and Claude 3 selectors were
removed in the Claude 5 refresh.

default  - alias for the recommended default, claude-opus-5-5
fable52  - Claude Fable 5.2 (most capable)
opus55   - Claude Opus 5.5 (the default)
opus5    - Claude Opus 5
opus48   - Claude Opus 4.8 (prior generation, retained)
sonnet55 - Claude Sonnet 5.5
sonnet5  - Claude Sonnet 5
haiku55  - Claude Haiku 5.5

Model IDs are undated — the Anthropic API resolves the current snapshot, and
appending a date suffix is wrong for these IDs.

Example:
  ClaudeModel opus55 ""=> claude-opus-5-5""

### Examples

```
ClaudeModel default
>>> 'claude-opus-5-5'

ClaudeModel opus55
>>> 'claude-opus-5-5'

ClaudeModel sonnet55
>>> 'claude-sonnet-5-5'

ClaudeModel haiku55
>>> 'claude-haiku-5-5'

ClaudeModel fable52
>>> 'claude-fable-5-2'
```

"
Class {
	#name : 'ClaudeModel',
	#superclass : 'Object',
	#category : 'Claude-Messaging-Types',
	#package : 'Claude-Messaging-Types'
}

{ #category : 'models' }
ClaudeModel class >> default [
	"The recommended default model — Claude Opus 5.5."
	^ self opus55
]

{ #category : 'models' }
ClaudeModel class >> fable52 [
	"Claude Fable 5.2 — most capable"
	^ 'claude-fable-5-2'
]

{ #category : 'models' }
ClaudeModel class >> haiku55 [
	"Claude Haiku 5.5"
	^ 'claude-haiku-5-5'
]

{ #category : 'models' }
ClaudeModel class >> opus48 [
	"Claude Opus 4.8 — prior generation, retained for callers that pin it"
	^ 'claude-opus-4-8'
]

{ #category : 'models' }
ClaudeModel class >> opus5 [
	"Claude Opus 5"
	^ 'claude-opus-5'
]

{ #category : 'models' }
ClaudeModel class >> opus55 [
	"Claude Opus 5.5 — the default model"
	^ 'claude-opus-5-5'
]

{ #category : 'models' }
ClaudeModel class >> sonnet5 [
	"Claude Sonnet 5"
	^ 'claude-sonnet-5'
]

{ #category : 'models' }
ClaudeModel class >> sonnet55 [
	"Claude Sonnet 5.5"
	^ 'claude-sonnet-5-5'
]
