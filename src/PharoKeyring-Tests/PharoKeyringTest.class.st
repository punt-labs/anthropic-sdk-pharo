"
Unit tests for the read-only PharoKeyring resolver using MockKeyringBackend. Covers lookup, has, backend selection, and availability. Fixtures are seeded directly into the mock via seedService:account:secret: -- the keyring itself never stores.
"
Class {
	#name : 'PharoKeyringTest',
	#superclass : 'TestCase',
	#instVars : [
		'keyring',
		'backend'
	],
	#category : 'PharoKeyring-Tests',
	#package : 'PharoKeyring-Tests'
}

{ #category : 'running' }
PharoKeyringTest >> setUp [
	super setUp.
	backend := MockKeyringBackend new.
	keyring := PharoKeyring withBackend: backend
]

{ #category : 'tests' }
PharoKeyringTest >> testBackendName [
	self assert: keyring backendName equals: 'mock'
]

{ #category : 'tests' }
PharoKeyringTest >> testHasExisting [
	backend seedService: 'svc' account: 'acct' secret: 'pw'.
	self assert: (keyring has: 'svc' account: 'acct')
]

{ #category : 'tests' }
PharoKeyringTest >> testHasMissing [
	self deny: (keyring has: 'nosvc' account: 'noacct')
]

{ #category : 'tests' }
PharoKeyringTest >> testIsAvailable [
	self assert: keyring isAvailable
]

{ #category : 'tests' }
PharoKeyringTest >> testLookupExisting [
	backend seedService: 'myservice' account: 'user1' secret: 's3cret'.
	self assert: (keyring lookup: 'myservice' account: 'user1') equals: 's3cret'
]

{ #category : 'tests' }
PharoKeyringTest >> testLookupMissing [
	self assert: (keyring lookup: 'noservice' account: 'nouser') isNil
]
