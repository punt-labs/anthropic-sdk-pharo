"
A TestResult that logs a secret-safe stacktrace whenever a test errors (an uncaught exception, never an assertion failure). Each error block is built once and emitted to three sinks: a DURABLE file (errorLogFile, default .tmp/test-errors.log, appended within a run), the retained errorReports collection (so the blocks survive after the run), and an injectable logStream (default Transcript, the live tail). The Transcript is volatile, so the file and errorReports are what make a mid-run error root-causeable after a long suite.

Each frame is written as a method reference only (for example ClaudeClient>>sendMessage:), never the receiver or arguments, so an API key in a frame can never leak into any sink. ClaudeApiError instances are enriched with status= and retryAfter= lines, and nothing else from the response.

  | result stream |
  stream := WriteStream on: String new.
  result := ClaudeLoggingTestResult new logStream: stream; yourself.
  result runCase: (ClaudeLoggingProbeTestCase selector: #testRaisesError).
  stream contents includesSubstring: '[Claude test ERROR]'
  >>> true

  result errorReports size
  >>> 1

"
Class {
	#name : 'ClaudeLoggingTestResult',
	#superclass : 'TestResult',
	#instVars : [
		'logStream',
		'errorReports',
		'errorLogFile'
	],
	#category : 'Claude-Messaging-Client-Tests',
	#package : 'Claude-Messaging-Client-Tests'
}

{ #category : 'logging' }
ClaudeLoggingTestResult >> appendToFile: aString [
	"Append the report block to the durable error-log file, creating it if absent.
	Appends within a run so successive errors accumulate."
	self errorLogFile ensureCreateFile.
	self errorLogFile writeStreamDo: [ :s |
		s setToEnd.
		s nextPutAll: aString ]
]

{ #category : 'logging' }
ClaudeLoggingTestResult >> buildReportFor: ex for: aTestCase [
	"Build the full secret-safe error block as a String: header, exception, optional API
	metadata, and a method-reference-only stack. Returns the block text without emitting it."
	| stream |
	stream := WriteStream on: String new.
	stream
		nextPutAll: '[Claude test ERROR] ';
		nextPutAll: aTestCase class name;
		nextPutAll: '>>#';
		nextPutAll: aTestCase selector;
		nextPut: Character lf.
	stream
		nextPutAll: ex class name;
		nextPutAll: ': ';
		nextPutAll: (ex messageText ifNil: [ '' ]);
		nextPut: Character lf.
	(ex class == ClaudeApiError or: [ ex class inheritsFrom: ClaudeApiError ]) ifTrue: [
		stream
			nextPutAll: 'status=';
			nextPutAll: ex statusCode printString;
			nextPutAll: ' retryAfter=';
			nextPutAll: ex retryAfter printString;
			nextPut: Character lf ].
	self logStackOf: ex on: stream.
	^ stream contents
]

{ #category : 'accessing' }
ClaudeLoggingTestResult >> errorLogFile [
	"The durable sink file. Defaults to .tmp/test-errors.log under the image working directory.
	Injectable via #errorLogFile: so tests can point at a throwaway path."
	^ errorLogFile ifNil: [
		errorLogFile := (FileSystem disk workingDirectory / '.tmp') ensureCreateDirectory / 'test-errors.log' ]
]

{ #category : 'accessing' }
ClaudeLoggingTestResult >> errorLogFile: aFileReference [
	errorLogFile := aFileReference
]

{ #category : 'accessing' }
ClaudeLoggingTestResult >> errorReports [
	^ errorReports ifNil: [ errorReports := OrderedCollection new ]
]

{ #category : 'logging' }
ClaudeLoggingTestResult >> isSUnitBoundary: aContext [
	"Answer whether the context belongs to the SUnit run machinery, which marks the end
	of the application stack worth logging. Stopping here keeps the report focused on the
	failing code and the test method, and drops the generic SUnit driver frames."
	| selector |
	selector := aContext method selector.
	^ #( #runCase: #runCaseManaged #runCase #performTest ) includes: selector
]

{ #category : 'logging' }
ClaudeLoggingTestResult >> logError: ex for: aTestCase [
	"Build the secret-safe error block once, then emit it to every sink: the durable file
	(appended), the retained errorReports collection, and the live logStream (Transcript tail)."
	| block |
	block := self buildReportFor: ex for: aTestCase.
	self appendToFile: block.
	self errorReports add: block.
	self logStream nextPutAll: block
]

{ #category : 'logging' }
ClaudeLoggingTestResult >> logStackOf: ex on: stream [
	"Walk the signaler context chain, writing each frame as a method reference only.
	Never print receivers or arguments, so secrets cannot leak. Cap at 40 frames and
	stop when reaching the SUnit run machinery."
	| context count |
	context := ex signalerContext.
	count := 0.
	[ context notNil and: [ count < 40 ] ] whileTrue: [
		(self isSUnitBoundary: context) ifTrue: [ ^ self ].
		stream
			nextPutAll: '  ';
			nextPutAll: context printString;
			nextPut: Character lf.
		count := count + 1.
		context := context sender ]
]

{ #category : 'accessing' }
ClaudeLoggingTestResult >> logStream [
	^ logStream ifNil: [ logStream := Transcript ]
]

{ #category : 'accessing' }
ClaudeLoggingTestResult >> logStream: aStream [
	logStream := aStream
]

{ #category : 'running' }
ClaudeLoggingTestResult >> runCase: aTestCase [
	[
	aTestCase announce: TestCaseStarted withResult: self.
	aTestCase runCaseManaged.
	aTestCase announce: TestCaseEnded withResult: self.
	self addPass: aTestCase ]
		on: self class failure , self class skip , self class warning , self class error
		do: [ :ex |
			(self shouldLogError: ex) ifTrue: [ self logError: ex for: aTestCase ].
			ex sunitAnnounce: aTestCase toResult: self ]
]

{ #category : 'logging' }
ClaudeLoggingTestResult >> shouldLogError: ex [
	"Answer true only for genuine errors, never assertion failures, skips, or warnings."
	^ (self class error handles: ex)
		and: [ (self class failure handles: ex) not
		and: [ (self class skip handles: ex) not
		and: [ (self class warning handles: ex) not ] ] ]
]
