"
Read-only keyring backend for Linux using secret-tool(1), which accesses GNOME Keyring or KDE Wallet via the Secret Service D-Bus API. This backend only LOOKS UP secrets the user has already provisioned through their keyring tools -- it never stores or clears entries.

### Examples

LinuxSecretToolBackend new name
>>> 'secret-tool'

"
Class {
	#name : 'LinuxSecretToolBackend',
	#superclass : 'PharoKeyringBackend',
	#category : 'PharoKeyring',
	#package : 'PharoKeyring'
}

{ #category : 'testing' }
LinuxSecretToolBackend >> isAvailable [
	^ (self exitCodeFrom: (LibC runCommand: 'which secret-tool > /dev/null 2>&1')) = 0
]

{ #category : 'operations' }
LinuxSecretToolBackend >> lookupService: serviceString account: accountString [
	"Look up a secret. Short-circuits with nil when secret-tool is not installed
	(common on CI runners) so the shell does not emit 'sh: secret-tool: not found'
	to stderr on every call. Pipes stderr to /dev/null on the lookup itself so a
	locked or empty keyring is silent too -- the only contract is the return value."
	| cmd result |
	self isAvailable ifFalse: [ ^ nil ].
	cmd := 'secret-tool lookup service ', (self shellQuote: serviceString), ' account ', (self shellQuote: accountString), ' 2>/dev/null'.
	result := LibC resultOfCommand: cmd.
	result ifNil: [ ^ nil ].
	result := result trimRight.
	result ifEmpty: [ ^ nil ].
	^ result
]

{ #category : 'accessing' }
LinuxSecretToolBackend >> name [
	^ 'secret-tool'
]
