"
Keyring backend for Linux using pass(1), the standard unix password manager (passwordstore.org). Secrets are GPG-encrypted files in a store tree; a (service, account) pair maps to the entry path service/account. The secret is line 1 of each entry. pass is preferred over secret-tool when both are installed (see PharoKeyring detectBackend). pass has no label concept, so the label argument to store is ignored.

### Examples

LinuxPassToolBackend new name
>>> 'pass'
"
Class {
	#name : 'LinuxPassToolBackend',
	#superclass : 'PharoKeyringBackend',
	#category : 'PharoKeyring',
	#package : 'PharoKeyring'
}

{ #category : 'operations' }
LinuxPassToolBackend >> deleteService: serviceString account: accountString [
	"Remove the pass entry at service/account. --force suppresses the
	confirmation prompt; a missing entry is not treated as an error,
	mirroring secret-tool clear on the sibling backend."
	| cmd |
	cmd := 'pass rm --force ', (self shellQuote: (self pathForService: serviceString account: accountString)).
	LibC runCommand: cmd
]

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
	cmd := 'pass show ', (self shellQuote: (self pathForService: serviceString account: accountString)), ' 2>/dev/null'.
	result := LibC resultOfCommand: cmd.
	result ifNil: [ ^ nil ].
	firstLine := result lines isEmpty ifTrue: [ '' ] ifFalse: [ result lines first ].
	firstLine := firstLine trimBoth.
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

{ #category : 'operations' }
LinuxPassToolBackend >> storeService: serviceString account: accountString secret: secretString label: labelString [
	"Store a secret in the pass store at service/account. The secret is
	piped via STDIN (the printf pipe) and never appears in argv, so it is
	not visible in the process table. labelString is IGNORED: pass has no
	label concept -- the entry path (service/account) is the only identity.
	--multiline reads the secret verbatim from stdin; --force overwrites
	an existing entry without prompting."
	| cmd status exitCode |
	cmd := 'printf %s ', (self shellQuote: secretString),
		' | pass insert --multiline --force ',
		(self shellQuote: (self pathForService: serviceString account: accountString)).
	status := LibC runCommand: cmd.
	exitCode := self exitCodeFrom: status.
	exitCode = 0 ifFalse: [
		KeyringCommandError new
			exitCode: exitCode;
			command: cmd;
			signal ]
]
