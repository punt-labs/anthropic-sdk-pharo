"
Abstract backend protocol for the read-only OS keyring RESOLVER. Subclasses implement platform-specific LOOKUP commands for pass and secret-tool (Linux) and security(1) (macOS). The protocol is read-only: lookupService:account:, isAvailable, and name. Subclasses never store or delete secrets.

### Examples

PharoKeyringBackend subclasses size >= 2
>>> true

"
Class {
	#name : 'PharoKeyringBackend',
	#superclass : 'Object',
	#category : 'PharoKeyring',
	#package : 'PharoKeyring'
}

{ #category : 'private' }
PharoKeyringBackend >> exitCodeFrom: waitStatus [
	"Extract process exit code from wait(2) status."
	^ (waitStatus >> 8) bitAnd: 16rFF
]

{ #category : 'testing' }
PharoKeyringBackend >> isAvailable [
	^ self subclassResponsibility
]

{ #category : 'operations' }
PharoKeyringBackend >> lookupService: serviceString account: accountString [
	^ self subclassResponsibility
]

{ #category : 'accessing' }
PharoKeyringBackend >> name [
	^ self subclassResponsibility
]

{ #category : 'private' }
PharoKeyringBackend >> shellQuote: aString [
	"POSIX single-quote escaping. Each embedded single-quote is replaced with the four-character sequence: close-quote, backslash, quote, open-quote."
	| sq replacement |
	sq := String with: $'.
	replacement := sq, (String with: $\), sq, sq.
	^ sq, (aString copyReplaceAll: sq with: replacement), sq
]
