"
A throwaway TestCase used only by ClaudeLoggingTestResultTest to exercise ClaudeLoggingTestResult. It offers one passing test, one assertion-failing test, one that raises a plain Error, and one that raises a ClaudeApiError. raiseWithSecret stashes a fake API key in a frame receiver so tests can prove the logger never prints receivers.

  (ClaudeLoggingProbeTestCase selector: #testPasses) run passedCount
  >>> 1

"
Class {
	#name : 'ClaudeLoggingProbeTestCase',
	#superclass : 'TestCase',
	#category : 'Claude-Messaging-Client-Tests',
	#package : 'Claude-Messaging-Client-Tests'
}

{ #category : 'testing' }
ClaudeLoggingProbeTestCase class >> isAbstract [
	"This fixture is driven explicitly by ClaudeLoggingTestResultTest via
	 #selector:; its deliberately failing/raising test methods must never be
	 auto-collected into the package test suite. Answering true is SUnit''s
	 signal that no TestCase instances should be built from this class."
	^ true
]

{ #category : 'private' }
ClaudeLoggingProbeTestCase >> failWithApiKey: aKey [ ^ Error signal: 'boom (key length: ' , aKey size printString , ')'
]

{ #category : 'private' }
ClaudeLoggingProbeTestCase >> raiseViaLeakyReceiver [
	"Drive a frame whose receiver is a ClaudeLeakySecretHolder holding a secret onto the signaler
	stack, so a C3 test can prove the logger never renders that receiver."
	(ClaudeLeakySecretHolder new secret: 'sk-ant-LEAK') raiseInMyOwnFrame
]

{ #category : 'private' }
ClaudeLoggingProbeTestCase >> raiseWithSecret [ self failWithApiKey: 'sk-ant-SECRET'
]

{ #category : 'tests' }
ClaudeLoggingProbeTestCase >> testEmitsLogLine [
	"Emits a ClaudeTestLog line so a behavioral test can prove the Beacon debug loggers were
	actually attached during the run."
	ClaudeTestLog log: 'probe-debug-line'.
	self assert: true
]

{ #category : 'tests' }
ClaudeLoggingProbeTestCase >> testFails [ self assert: 1 equals: 2
]

{ #category : 'tests' }
ClaudeLoggingProbeTestCase >> testPasses [ self assert: 1 + 1 equals: 2
]

{ #category : 'tests' }
ClaudeLoggingProbeTestCase >> testRaisesApiError [ | e | e := ClaudeRateLimitError new. e statusCode: 429; retryAfter: 7. e signal
]

{ #category : 'tests' }
ClaudeLoggingProbeTestCase >> testRaisesError [ self raiseWithSecret
]

{ #category : 'tests' }
ClaudeLoggingProbeTestCase >> testRaisesViaLeakyReceiver [
	"Errors through a frame whose receiver would leak a secret via printString."
	self raiseViaLeakyReceiver
]
