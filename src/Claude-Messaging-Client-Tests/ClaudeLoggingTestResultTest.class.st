"
Unit tests for ClaudeLoggingTestResult. Each test runs a throwaway probe
(ClaudeLoggingProbeTestCase) under a logging result with an injected WriteStream and/or
temp file, then asserts on the captured log. Covers: errors are logged, ClaudeApiError
status is enriched, passing tests and assertion failures are not logged, no secret ever
reaches any sink, a file-sink failure cannot abort the run or mask the real error (C2), a
leaky receiver frame is never rendered (C3), and the Beacon loggers actually attach on the
runFullWithErrorLogging wiring (C1).

  ClaudeLoggingTestResultTest buildSuite run errorCount
  >>> 0

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
ClaudeLoggingTestResultTest >> testFileSinkFailureDoesNotAbortOrMaskError [
	"C2 regression guard. Point the durable-file sink at a child path UNDER a regular file, so any
	attempt to create/write it raises. The original test error MUST still be recorded on the result
	(errorCount = 1) and the run MUST NOT abort — the other sinks (errorReports, logStream) still get
	the block. A sink failure can never change a test result or stop the suite."
	| stream result parentFile badFile |
	stream := WriteStream on: String new.
	parentFile := (FileSystem disk workingDirectory / '.tmp') ensureCreateDirectory
		/ ('c2-parent-' , UUID new asString36).
	parentFile ensureCreateFile.
	badFile := parentFile / 'child-under-a-file.log'.
	[
		result := ClaudeLoggingTestResult new
			logStream: stream;
			errorLogFile: badFile;
			yourself.
		result runCase: (ClaudeLoggingProbeTestCase selector: #testRaisesError).
		self assert: result errorCount equals: 1.
		self assert: result errorReports size equals: 1.
		self assert: (stream contents includesSubstring: '[Claude test ERROR]') ]
		ensure: [ parentFile ensureDelete ]
]

{ #category : 'tests' }
ClaudeLoggingTestResultTest >> testLeakyReceiverFrameIsNotRendered [
	"C3 regression guard. Run a probe that errors through a frame whose RECEIVER (a
	ClaudeLeakySecretHolder) would render sk-ant-LEAK via printString. Because frames are derived
	structurally as class>>selector, the log must contain the method reference
	ClaudeLeakySecretHolder>>raiseInMyOwnFrame but NEVER the leaked receiver state. This fails if the
	logger ever reverts to context printString."
	| stream log |
	stream := WriteStream on: String new.
	self runProbe: #testRaisesViaLeakyReceiver into: stream.
	log := stream contents.
	self assert: (log includesSubstring: 'ClaudeLeakySecretHolder>>raiseInMyOwnFrame').
	self deny: (log includesSubstring: 'sk-ant-LEAK')
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
ClaudeLoggingTestResultTest >> testRunnerAttachesBeaconLoggers [
	"Behavioral C1 regression guard. Drive a tiny suite through the SAME wiring runFullWithErrorLogging
	uses (runSuite:withResult:debugLogFile:) with an injected temp debug-log file. Assert the result is
	a ClaudeLoggingTestResult AND the debug log actually received the ClaudeTestLog line — proving the
	Beacon loggers were attached. Against the old stale override (which omitted the logger nesting) this
	FAILS because nothing writes the debug file; after the fix it PASSES."
	| suite result debugFile |
	debugFile := (FileSystem disk workingDirectory / '.tmp') ensureCreateDirectory
		/ ('test-debug-probe-' , UUID new asString36 , '.log').
	[
		suite := TestSuite named: 'C1 probe'.
		suite addTest: (ClaudeLoggingProbeTestCase selector: #testEmitsLogLine).
		result := ClaudeAbstractTestSuite
			runSuite: suite
			withResult: ClaudeLoggingTestResult new
			debugLogFile: debugFile.
		self assert: (result isKindOf: ClaudeLoggingTestResult).
		self assert: debugFile exists.
		self assert: (debugFile contents includesSubstring: 'probe-debug-line') ]
		ensure: [ debugFile ensureDelete ]
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
