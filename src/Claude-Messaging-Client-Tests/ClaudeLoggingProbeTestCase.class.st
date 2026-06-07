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

{ #category : 'tests' }
ClaudeLoggingProbeTestCase >> failWithApiKey: aKey [ ^ Error signal: 'boom (key length: ' , aKey size printString , ')'
]

{ #category : 'tests' }
ClaudeLoggingProbeTestCase >> raiseWithSecret [ self failWithApiKey: 'sk-ant-SECRET'
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
