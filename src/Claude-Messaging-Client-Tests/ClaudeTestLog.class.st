"
The controlled facade for integration-test logging.

Tests call ""ClaudeTestLog log: '...'"" instead of touching Transcript
directly. Each call emits a ClaudeTestSignal, so whichever SignalLoggers
are running during the test run receive it: TranscriptLogger writes it
live, ClaudeFileSignalLogger appends it to a durable file, MemoryLogger
records it for assertions.

	(MemoryLogger new runDuring: [ ClaudeTestLog log: '>> hello' ])
		recordings anyOne message
	>>> '>> hello'

Activity logging (always-on durable sink).

Integration tests narrate their activity to one shared durable file,
.tmp/integration-activity.log, via a started-once ClaudeFileSignalLogger
held in the ActivityLogger class variable. An integration test setUp calls
""ClaudeTestLog startActivityFor: self selector"" and its tearDown calls
""ClaudeTestLog endActivityFor: self selector""; test bodies add step lines
with ""ClaudeTestLog log: ..."". The sink is attached test-side, so it works
under any runner (Dr Tests GUI, TestCase>>run, make test-full), and the file
accumulates (append, never truncate).

	ClaudeTestLog startActivityFor: #demoTest.
	ClaudeTestLog log: '  -> did a thing'.
	ClaudeTestLog endActivityFor: #demoTest.
	(ClaudeTestLog activityLogFile contents includesSubstring: 'demoTest START')
	>>> true

"
Class {
	#name : 'ClaudeTestLog',
	#superclass : 'Object',
	#classVars : [
		'ActivityLogFile',
		'ActivityLogger'
	],
	#category : 'Claude-Messaging-Client-Tests',
	#package : 'Claude-Messaging-Client-Tests'
}

{ #category : 'activity logging' }
ClaudeTestLog class >> activityLogFile [
	"The single durable file every integration test appends its activity to. All
	Claude*IntegrationTest classes share this one path so a full integration run
	leaves a single interleaved transcript on disk. A test may override the path with
	activityLogFile: (default restored by passing nil); production callers use the default."
	^ ActivityLogFile ifNil: [
		(FileSystem disk workingDirectory / '.tmp') ensureCreateDirectory
			/ 'integration-activity.log' ]
]

{ #category : 'activity logging' }
ClaudeTestLog class >> activityLogFile: aFileReferenceOrNil [
	"Testing seam: override the durable activity-log path. Pass nil to restore the default.
	Production code never sends this; the default path is unchanged."
	ActivityLogFile := aFileReferenceOrNil
]

{ #category : 'activity logging' }
ClaudeTestLog class >> activityLogger [
	"The started-once durable sink for integration-test activity. Created lazily and
	left subscribed to Beacon so that every ClaudeTestLog log: line — from any test,
	driven by any runner (Dr Tests GUI, TestCase>>run, make test-full) — lands in the
	shared file. Started exactly once; repeated sends return the same running logger."
	^ ActivityLogger ifNil: [
		| logger |
		logger := ClaudeFileSignalLogger onFile: self activityLogFile.
		logger start.
		ActivityLogger := logger ]
]

{ #category : 'activity logging' }
ClaudeTestLog class >> endActivityFor: aSelector [
	"Emit an END marker naming the integration test that just finished. Call from an
	integration test tearDown (before super tearDown). The shared sink stays running."
	self log: '=== ' , aSelector , ' END ==='
]

{ #category : 'logging' }
ClaudeTestLog class >> log: aString [
	^ ClaudeTestSignal emit: aString
]

{ #category : 'activity logging' }
ClaudeTestLog class >> resetActivityLogger [
	"Testing seam: stop the started-once singleton (unsubscribing it from Beacon) and drop it
	so the next activityLogger send re-binds lazily to the current activityLogFile. Production
	code never sends this; the always-on started-once semantics are unchanged for real runs."
	ActivityLogger ifNotNil: [ :logger | logger stop ].
	ActivityLogger := nil
]

{ #category : 'activity logging' }
ClaudeTestLog class >> startActivityFor: aSelector [
	"Ensure the shared durable sink is running, then emit a START marker naming the
	integration test about to run. Call from an integration test setUp (after super setUp)."
	self activityLogger.
	self log: '=== ' , aSelector , ' START ==='
]
