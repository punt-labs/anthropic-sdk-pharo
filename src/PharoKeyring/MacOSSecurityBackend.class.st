"
Read-only keyring backend for macOS using security(1) to look up secrets in the system Keychain. This backend only LOOKS UP secrets the user has already provisioned through Keychain Access or security(1) -- it never adds or deletes keychain items.

### Examples

MacOSSecurityBackend new name
>>> 'security'

"
Class {
	#name : 'MacOSSecurityBackend',
	#superclass : 'PharoKeyringBackend',
	#category : 'PharoKeyring',
	#package : 'PharoKeyring'
}

{ #category : 'testing' }
MacOSSecurityBackend >> isAvailable [
	^ (self exitCodeFrom: (LibC runCommand: 'which security > /dev/null 2>&1')) = 0
]

{ #category : 'operations' }
MacOSSecurityBackend >> lookupService: serviceString account: accountString [
	| cmd result |
	cmd := 'security find-generic-password -s ', (self shellQuote: serviceString), ' -a ', (self shellQuote: accountString), ' -w 2>/dev/null'.
	result := LibC resultOfCommand: cmd.
	result ifNil: [ ^ nil ].
	result := result trimRight.
	result ifEmpty: [ ^ nil ].
	^ result
]

{ #category : 'accessing' }
MacOSSecurityBackend >> name [
	^ 'security'
]
