"
Read-only keyring backend for Linux using pass(1), the standard unix password manager (passwordstore.org). Secrets are GPG-encrypted files in a store tree; a (service, account) pair maps to the entry path service/account, and the secret is line 1 of that entry. pass is preferred over secret-tool when both are installed (see PharoKeyring detectBackend). This backend only LOOKS UP secrets the user has already provisioned with pass -- it never inserts or removes entries.

### Examples

LinuxPassToolBackend new name
>>> 'pass'

LinuxPassToolBackend new pathForService: 'anthropic' account: 'api-key'
>>> 'anthropic/api-key'

"
Class {
	#name : 'LinuxPassToolBackend',
	#superclass : 'PharoKeyringBackend',
	#category : 'PharoKeyring',
	#package : 'PharoKeyring'
}

{ #category : 'testing' }
LinuxPassToolBackend >> isAvailable [
	^ (self exitCodeFrom: (LibC runCommand: 'which pass > /dev/null 2>&1')) = 0
]

{ #category : 'operations' }
LinuxPassToolBackend >> lookupService: serviceString account: accountString [
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
LinuxPassToolBackend >> name [
	^ 'pass'
]

{ #category : 'private' }
LinuxPassToolBackend >> pathForService: serviceString account: accountString [
	"The pass entry path. By convention a pass store is organized as a
	directory tree; we map a (service, account) pair to service/account."
	^ serviceString, '/', accountString
]
