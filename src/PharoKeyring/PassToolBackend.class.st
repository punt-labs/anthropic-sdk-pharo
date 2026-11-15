"
Read-only keyring backend using pass(1), the standard unix password manager (passwordstore.org). pass runs on every platform the SDK targets -- Linux and macOS both -- so this backend is platform-neutral and is preferred over secret-tool and the macOS Keychain when pass is installed (see PharoKeyring detectBackend). Secrets are GPG-encrypted files in a store tree; a (service, account) pair maps to the entry path service/account, and the secret is line 1 of that entry. This backend only LOOKS UP secrets the user has already provisioned with pass -- it never inserts or removes entries.

### Examples

PassToolBackend new name
>>> 'pass'

PassToolBackend new pathForService: 'anthropic' account: 'api-key'
>>> 'anthropic/api-key'

"
Class {
	#name : 'PassToolBackend',
	#superclass : 'PharoKeyringBackend',
	#category : 'PharoKeyring',
	#package : 'PharoKeyring'
}

{ #category : 'testing' }
PassToolBackend >> isAvailable [
	^ (self exitCodeFrom: (LibC runCommand: 'which pass > /dev/null 2>&1')) = 0
]

{ #category : 'operations' }
PassToolBackend >> lookupService: serviceString account: accountString [
	"Look up a secret. Short-circuits with nil when pass is not installed
	(common on CI runners) so the shell does not emit 'sh: pass: not found'
	to stderr on every call. Pipes stderr to /dev/null so a missing entry or
	locked store is silent too -- the only contract is the return value.
	pass show prints the secret on line 1 (any following lines are metadata),
	so we return the first line, trimmed."
	| cmd result firstLine |
	self isAvailable ifFalse: [ ^ nil ].
	cmd := 'pass show -- ', (self shellQuote: (self pathForService: serviceString account: accountString)), ' 2>/dev/null'.
	result := LibC resultOfCommand: cmd.
	result ifNil: [ ^ nil ].
	firstLine := result lines isEmpty ifTrue: [ '' ] ifFalse: [ result lines first ].
	firstLine := firstLine trimRight.
	firstLine ifEmpty: [ ^ nil ].
	^ firstLine
]

{ #category : 'accessing' }
PassToolBackend >> name [
	^ 'pass'
]

{ #category : 'private' }
PassToolBackend >> pathForService: serviceString account: accountString [
	"The pass entry path. By convention a pass store is organized as a
	directory tree; we map a (service, account) pair to service/account."
	^ serviceString, '/', accountString
]
