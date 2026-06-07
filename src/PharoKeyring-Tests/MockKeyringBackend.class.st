"
In-memory keyring backend for unit testing the read-only resolver. Holds secrets in a nested Dictionary keyed by service then account. Tests provision fixtures with seedService:account:secret: (a test-only helper, not part of the keyring protocol) and then exercise the read-only lookupService:account:.

### Examples

| mock |
mock := MockKeyringBackend new.
mock seedService: 'svc' account: 'acct' secret: 'pw'.
mock lookupService: 'svc' account: 'acct'
>>> 'pw'

"
Class {
	#name : 'MockKeyringBackend',
	#superclass : 'PharoKeyringBackend',
	#instVars : [
		'store'
	],
	#category : 'PharoKeyring-Tests',
	#package : 'PharoKeyring-Tests'
}

{ #category : 'initialization' }
MockKeyringBackend >> initialize [
	store := Dictionary new
]

{ #category : 'testing' }
MockKeyringBackend >> isAvailable [
	^ true
]

{ #category : 'operations' }
MockKeyringBackend >> lookupService: serviceString account: accountString [
	| serviceDict |
	serviceDict := store at: serviceString ifAbsent: [ ^ nil ].
	^ serviceDict at: accountString ifAbsent: [ nil ]
]

{ #category : 'accessing' }
MockKeyringBackend >> name [
	^ 'mock'
]

{ #category : 'test support' }
MockKeyringBackend >> seedService: serviceString account: accountString secret: secretString [
	"Test-only provisioning: place a secret in the in-memory store so
	lookup can retrieve it. This is the test seeding the fixture, not
	part of the read-only keyring protocol."
	| serviceDict |
	serviceDict := store at: serviceString ifAbsentPut: [ Dictionary new ].
	serviceDict at: accountString put: secretString
]
