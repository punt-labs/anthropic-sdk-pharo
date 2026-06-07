"
Integration test for the read-only PharoKeyring resolver against the real OS keyring. The SDK under test never writes; so the test provisions a throwaway secret OUT OF BAND by shelling directly to the raw active tool (pass, secret-tool, or security) in setUp, asserts that PharoKeyring default lookup:account: retrieves it, and removes it via the raw tool in tearDown. A unique service name avoids collisions. If out-of-band provisioning is not possible in the environment, the test skips rather than fails. Excluded from make test.

  PharoKeyringIntegrationTest buildSuite run
  >>> a TestResult

"
Class {
	#name : 'PharoKeyringIntegrationTest',
	#superclass : 'TestCase',
	#instVars : [
		'keyring',
		'testService',
		'provisioned'
	],
	#category : 'PharoKeyring-Tests',
	#package : 'PharoKeyring-Tests'
}

{ #category : 'private' }
PharoKeyringIntegrationTest >> deprovisionAccount: accountString [
	"Remove the throwaway secret via the RAW active tool. Best-effort:
	failures are ignored because a missing entry is not an error here."
	| backend q |
	backend := keyring backend.
	q := [ :s | backend shellQuote: s ].
	backend name = 'pass' ifTrue: [
		LibC runCommand: 'pass rm --force ', (q value: testService, '/', accountString), ' > /dev/null 2>&1'.
		^ self ].
	backend name = 'secret-tool' ifTrue: [
		LibC runCommand: 'secret-tool clear service ', (q value: testService), ' account ', (q value: accountString), ' > /dev/null 2>&1'.
		^ self ].
	backend name = 'security' ifTrue: [
		LibC runCommand: 'security delete-generic-password -s ', (q value: testService), ' -a ', (q value: accountString), ' > /dev/null 2>&1'.
		^ self ]
]

{ #category : 'private' }
PharoKeyringIntegrationTest >> provisionAccount: accountString secret: secretString [
	"Provision a throwaway secret OUT OF BAND, by shelling out to the
	RAW active tool directly. This is the TEST setting up its fixture,
	not the SDK -- the SDK under test is read-only. Returns true when
	the raw tool reported success (exit 0), false otherwise so the test
	can skip rather than fail in environments where the store is not
	usable."
	| backend q status |
	backend := keyring backend.
	q := [ :s | backend shellQuote: s ].
	backend name = 'pass' ifTrue: [
		status := LibC runCommand: 'printf %s ', (q value: secretString),
			' | pass insert --multiline --force ',
			(q value: testService, '/', accountString), ' > /dev/null 2>&1'.
		^ (backend exitCodeFrom: status) = 0 ].
	backend name = 'secret-tool' ifTrue: [
		status := LibC runCommand: 'printf %s ', (q value: secretString),
			' | secret-tool store --label=', (q value: testService),
			' service ', (q value: testService), ' account ', (q value: accountString),
			' > /dev/null 2>&1'.
		^ (backend exitCodeFrom: status) = 0 ].
	backend name = 'security' ifTrue: [
		status := LibC runCommand: 'security add-generic-password -U -s ',
			(q value: testService), ' -a ', (q value: accountString),
			' -w ', (q value: secretString), ' > /dev/null 2>&1'.
		^ (backend exitCodeFrom: status) = 0 ].
	^ false
]

{ #category : 'running' }
PharoKeyringIntegrationTest >> setUp [
	super setUp.
	self assert: OSPlatform current isUnix description: 'Keyring integration tests require Unix (Linux/macOS).'.
	keyring := PharoKeyring default.
	self assert: keyring isAvailable description: 'Keyring backend not available (pass, secret-tool, or security not installed).'.
	testService := 'pharotest-', UUID new printString.
	provisioned := self provisionAccount: 'testaccount' secret: 'mysecret'
]

{ #category : 'running' }
PharoKeyringIntegrationTest >> tearDown [
	(testService notNil and: [ provisioned == true ]) ifTrue: [
		self deprovisionAccount: 'testaccount' ].
	super tearDown
]

{ #category : 'tests-integration' }
PharoKeyringIntegrationTest >> testLookupProvisionedSecret [
	"The read-only resolver retrieves a secret that was provisioned out
	of band through the raw tool. If provisioning was not possible in
	this environment (e.g. no usable store), skip rather than fail --
	the read-only contract is what is under test, not the raw tool."
	provisioned == true ifFalse: [ ^ self skip: 'Out-of-band provisioning unavailable in this environment.' ].
	self assert: (keyring lookup: testService account: 'testaccount') equals: 'mysecret'
]
