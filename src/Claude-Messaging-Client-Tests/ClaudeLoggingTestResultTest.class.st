"
Unit tests for ClaudeLoggingTestResult. Each test runs a throwaway probe (ClaudeLoggingProbeTestCase) under a logging result with an injected WriteStream, then asserts on the captured log. Covers: errors are logged, ClaudeApiError status is enriched, passing tests and assertion failures are not logged, and that no secret ever reaches the log.

  ClaudeLoggingTestResultTest buildSuite run
  >>> 6 run, 6 passes, 0 failures, 0 errors

"
Class {
	#name : 'ClaudeLoggingTestResultTest',
	#superclass : 'TestCase',
	#category : 'Claude-Messaging-Client-Tests',
	#package : 'Claude-Messaging-Client-Tests'
}

{ #category : 'private' }
ClaudeLoggingTestResultTest >> runProbe: aSelector into: aStream [
	"Run the named probe test under a logging result writing to aStream. Answer the result."
	| result |
	result := ClaudeLoggingTestResult new logStream: aStream; yourself.
	result runCase: (ClaudeLoggingProbeTestCase selector: aSelector).
	^ result
]

{ #category : 'tests' }
ClaudeLoggingTestResultTest >> testApiErrorLogsStatus [
	| stream result log |
	stream := WriteStream on: String new.
	result := self runProbe: #testRaisesApiError into: stream.
	log := stream contents.
	self assert: result errorCount equals: 1.
	self assert: (log includesSubstring: '[Claude test ERROR]').
	self assert: (log includesSubstring: 'status=429')
]

{ #category : 'tests' }
ClaudeLoggingTestResultTest >> testAssertionFailureIsNotLogged [
	| stream result |
	stream := WriteStream on: String new.
	result := self runProbe: #testFails into: stream.
	self assert: result failureCount equals: 1.
	self assert: result errorCount equals: 0.
	self deny: (stream contents includesSubstring: '[Claude test ERROR]')
]

{ #category : 'tests' }
ClaudeLoggingTestResultTest >> testPassingTestIsNotLogged [
	| stream result |
	stream := WriteStream on: String new.
	result := self runProbe: #testPasses into: stream.
	self assert: result errorCount equals: 0.
	self assert: result passedCount equals: 1.
	self deny: (stream contents includesSubstring: '[Claude test ERROR]')
]

{ #category : 'tests' }
ClaudeLoggingTestResultTest >> testPlainErrorIsLogged [
	| stream result log |
	stream := WriteStream on: String new.
	result := self runProbe: #testRaisesError into: stream.
	log := stream contents.
	self assert: result errorCount equals: 1.
	self assert: (log includesSubstring: '[Claude test ERROR]').
	self assert: (log includesSubstring: 'ClaudeLoggingProbeTestCase>>#testRaisesError').
	self assert: (log includesSubstring: 'ClaudeLoggingProbeTestCase>>raiseWithSecret')
]

{ #category : 'tests' }
ClaudeLoggingTestResultTest >> testRunnerReturnsLoggingResultType [
	"Confirm the runner is wired without running the live full suite: it must exist and
	be declared to build a ClaudeLoggingTestResult."
	| source |
	self assert: (ClaudeMessagingTestSuite class >> #runFullWithErrorLogging) notNil.
	source := (ClaudeMessagingTestSuite class >> #runFullWithErrorLogging) sourceCode.
	self assert: (source includesSubstring: 'ClaudeLoggingTestResult new').
	self assert: (source includesSubstring: 'self fullSuite run: result')
]

{ #category : 'tests' }
ClaudeLoggingTestResultTest >> testSecretIsNeverLogged [
	"The probe stores 'sk-ant-SECRET' in a frame receiver before raising. The log must
	contain method references for those frames but never the secret value."
	| stream log |
	stream := WriteStream on: String new.
	self runProbe: #testRaisesError into: stream.
	log := stream contents.
	self assert: (log includesSubstring: 'ClaudeLoggingProbeTestCase>>raiseWithSecret').
	self deny: (log includesSubstring: 'sk-ant-SECRET')
]
