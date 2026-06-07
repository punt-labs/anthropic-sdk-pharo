"
Proves ClaudeFileSignalLogger appends logged messages to its durable file,
exercised over a temp file under .tmp that tearDown removes. No live API.

	ClaudeFileSignalLoggerTest buildSuite run
	>>> 1 run, 1 passed, 0 failed, 0 errors

"
Class {
	#name : 'ClaudeFileSignalLoggerTest',
	#superclass : 'TestCase',
	#instVars : [
		'logFile'
	],
	#category : 'Claude-Messaging-Client-Tests',
	#package : 'Claude-Messaging-Client-Tests'
}

{ #category : 'running' }
ClaudeFileSignalLoggerTest >> setUp [
	super setUp.
	logFile := (FileSystem disk workingDirectory / '.tmp') ensureCreateDirectory
		/ ('claude-file-logger-test-' , UUID new asString36 , '.log')
]

{ #category : 'running' }
ClaudeFileSignalLoggerTest >> tearDown [
	logFile ifNotNil: [ logFile ensureDelete ].
	super tearDown
]

{ #category : 'tests' }
ClaudeFileSignalLoggerTest >> testDurableSinkWritesLoggedMessageToFile [
	"A ClaudeFileSignalLogger running over the pipeline appends the logged
	 message to its file. No live API."
	(ClaudeFileSignalLogger onFile: logFile)
		runDuring: [ ClaudeTestLog log: 'durable' ].
	self assert: logFile exists.
	self assert: (logFile contents includesSubstring: 'durable')
]
