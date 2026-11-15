"
Cross-platform OS keyring RESOLVER. Looks up secrets the user has already provisioned through the real password tools (pass, secret-tool, or the macOS Keychain) and their own UIs. This class is READ-ONLY: it never stores, overwrites, or deletes secrets -- provisioning is the job of the underlying tools, not of this SDK.

It detects the current platform and delegates to the appropriate backend (pass or secret-tool on Linux, security(1) on macOS). Use withBackend: to inject a mock for testing.

### Examples

(PharoKeyring withBackend: MockKeyringBackend new) backendName
>>> 'mock'

(PharoKeyring withBackend: MockKeyringBackend new) isAvailable
>>> true

"
Class {
	#name : 'PharoKeyring',
	#superclass : 'Object',
	#instVars : [
		'backend'
	],
	#category : 'PharoKeyring',
	#package : 'PharoKeyring'
}

{ #category : 'instance creation' }
PharoKeyring class >> default [
	^ self new
]

{ #category : 'instance creation' }
PharoKeyring class >> withBackend: aBackend [
	^ self basicNew
		backend: aBackend;
		yourself
]

{ #category : 'accessing' }
PharoKeyring >> backend [
	^ backend
]

{ #category : 'accessing' }
PharoKeyring >> backend: aBackend [
	backend := aBackend
]

{ #category : 'accessing' }
PharoKeyring >> backendName [
	^ backend name
]

{ #category : 'private' }
PharoKeyring >> detectBackend [
	"Prefer pass(1) on every platform when it is installed -- it is the one
	cross-platform secret store the SDK supports, so a dev with pass gets the
	same backend on macOS and Linux. Otherwise fall back to the OS-native
	tool: the macOS Keychain via security(1), secret-tool on Linux. Selection
	happens once, at detection time. No auto-migration between backends."
	| passBackend |
	passBackend := PassToolBackend new.
	passBackend isAvailable ifTrue: [ ^ backend := passBackend ].
	OSPlatform current isMacOS ifTrue: [ ^ backend := MacOSSecurityBackend new ].
	OSPlatform current isUnix ifTrue: [ ^ backend := LinuxSecretToolBackend new ].
	Error signal: 'Unsupported platform: ', OSPlatform current name
]

{ #category : 'testing' }
PharoKeyring >> has: serviceString account: accountString [
	^ (self lookup: serviceString account: accountString) isNotNil
]

{ #category : 'initialization' }
PharoKeyring >> initialize [
	self detectBackend
]

{ #category : 'testing' }
PharoKeyring >> isAvailable [
	^ backend isAvailable
]

{ #category : 'operations' }
PharoKeyring >> lookup: serviceString account: accountString [
	^ backend lookupService: serviceString account: accountString
]
