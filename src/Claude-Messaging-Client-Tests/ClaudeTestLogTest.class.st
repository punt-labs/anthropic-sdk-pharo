"
Proves the ClaudeTestLog -> ClaudeTestSignal -> SignalLogger pipeline
without any live API call, using a MemoryLogger as the capturing sink.

	ClaudeTestLogTest buildSuite run
	>>> 1 run, 1 passed, 0 failed, 0 errors

"
Class {
	#name : 'ClaudeTestLogTest',
	#superclass : 'TestCase',
	#category : 'Claude-Messaging-Client-Tests',
	#package : 'Claude-Messaging-Client-Tests'
}

{ #category : 'tests' }
ClaudeTestLogTest >> testActivityMarkersWrittenToInjectedFile [
	"startActivityFor:/endActivityFor: append START/END markers to the activity-log file.
	 A temp file is injected via the class-side seam so the real .tmp/integration-activity.log
	 is never touched; the singleton is reset before and after so the logger re-binds to the
	 temp path and no global state leaks."
	| tempFile contents |
	tempFile := (FileSystem disk workingDirectory / '.tmp') ensureCreateDirectory
		/ ('activity-test-' , UUID new asString36 , '.log').
	tempFile ensureDelete.
	[ ClaudeTestLog activityLogFile: tempFile.
	  ClaudeTestLog resetActivityLogger.
	  ClaudeTestLog startActivityFor: #someSel.
	  ClaudeTestLog endActivityFor: #someSel.
	  contents := tempFile contents.
	  self assert: (contents includesSubstring: '=== someSel START ===').
	  self assert: (contents includesSubstring: '=== someSel END ===') ]
		ensure: [
			ClaudeTestLog resetActivityLogger.
			ClaudeTestLog activityLogFile: nil.
			tempFile ensureDelete ].
	"the injected path must not leak: the singleton defaults back to the real path"
	self assert: ClaudeTestLog activityLogFile fullName
		equals: ((FileSystem disk workingDirectory / '.tmp') / 'integration-activity.log') fullName
]

{ #category : 'tests' }
ClaudeTestLogTest >> testLogEmitsSignalCapturedByMemoryLogger [
	"ClaudeTestLog log: emits a ClaudeTestSignal that a running SignalLogger receives.
	 No live API: MemoryLogger records the signal so we can inspect it."
	| logger signals |
	logger := MemoryLogger new.
	logger runDuring: [ ClaudeTestLog log: 'hello' ].
	signals := logger recordings select: [ :s | s isKindOf: ClaudeTestSignal ].
	self assert: signals size equals: 1.
	self assert: signals anyOne message equals: 'hello'
]
