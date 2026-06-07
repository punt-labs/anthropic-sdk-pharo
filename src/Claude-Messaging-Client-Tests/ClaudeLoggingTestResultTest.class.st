"
Unit tests for ClaudeLoggingTestResult. Each test runs a throwaway probe (ClaudeLoggingProbeTestCase) under a logging result with an injected WriteStream, then asserts on the captured log. Covers: errors are logged, ClaudeApiError status is enriched, passing tests and assertion failures are not logged, and that no secret ever reaches the log.

  ClaudeLoggingTestResultTest buildSuite run
  >>> 6 run, 6 passes, 0 failures, 0 errors

"
Class {
	#name : 'ClaudeLoggingTestResultTest',
	#superclass : 'TestCase',
	#instVars : [
		'tempLogFile'
	],
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

{ #category : 'running' }
ClaudeLoggingTestResultTest >> runProbe: aSelector into: aStream withDurableFile: aFileReference [
	"Run the named probe under a logging result that writes the Transcript tail to aStream and
	the durable block to aFileReference. Writes a header line to the file first, mirroring the
	runFullWithErrorLogging lifecycle. Answer the result."
	| result |
	aFileReference ensureDelete.
	aFileReference ensureCreateFile.
	aFileReference writeStreamDo: [ :s |
		s nextPutAll: '=== Claude test errors (run start) ==='; nextPut: Character lf ].
	result := ClaudeLoggingTestResult new
		logStream: aStream;
		errorLogFile: aFileReference;
		yourself.
	result runCase: (ClaudeLoggingProbeTestCase selector: aSelector).
	^ result
]

{ #category : 'running' }
ClaudeLoggingTestResultTest >> tearDown [
	tempLogFile ifNotNil: [ :f | f ensureDelete ].
	super tearDown
]

{ #category : 'running' }
ClaudeLoggingTestResultTest >> tempLogFile [
	"A unique throwaway log file under .tmp, lazily created per test and removed in tearDown."
	^ tempLogFile ifNil: [
		tempLogFile := (FileSystem disk workingDirectory / '.tmp') ensureCreateDirectory
			/ ('test-errors-probe-' , UUID new asString36 , '.log') ]
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
ClaudeLoggingTestResultTest >> testDurableFileContainsErrorBlock [
	"The durable file must carry the full error block independent of the Transcript, proving the
	trace survives on disk after the run: the header, the ERROR marker, and a method frame."
	| stream fileContents |
	stream := WriteStream on: String new.
	self runProbe: #testRaisesError into: stream withDurableFile: self tempLogFile.
	fileContents := self tempLogFile contents.
	self assert: (fileContents includesSubstring: '=== Claude test errors (run start) ===').
	self assert: (fileContents includesSubstring: '[Claude test ERROR]').
	self assert: (fileContents includesSubstring: 'ClaudeLoggingProbeTestCase>>raiseWithSecret')
]

{ #category : 'tests' }
ClaudeLoggingTestResultTest >> testErrorReportsEmptyOnPass [
	"A passing test leaves the retained reports collection empty."
	| stream result |
	stream := WriteStream on: String new.
	result := self runProbe: #testPasses into: stream withDurableFile: self tempLogFile.
	self assert: result errorReports isEmpty
]

{ #category : 'tests' }
ClaudeLoggingTestResultTest >> testErrorReportsRetainedOnError [
	"An erroring test leaves exactly one retained report block on the result."
	| stream result |
	stream := WriteStream on: String new.
	result := self runProbe: #testRaisesError into: stream withDurableFile: self tempLogFile.
	self assert: result errorReports size equals: 1.
	self assert: (result errorReports first includesSubstring: '[Claude test ERROR]')
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
ClaudeLoggingTestResultTest >> testSecretIsNeverInDurableFile [
	"The planted sk-ant-SECRET must never reach the durable file, only the method frame."
	| stream fileContents |
	stream := WriteStream on: String new.
	self runProbe: #testRaisesError into: stream withDurableFile: self tempLogFile.
	fileContents := self tempLogFile contents.
	self assert: (fileContents includesSubstring: 'ClaudeLoggingProbeTestCase>>raiseWithSecret').
	self deny: (fileContents includesSubstring: 'sk-ant-SECRET')
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
