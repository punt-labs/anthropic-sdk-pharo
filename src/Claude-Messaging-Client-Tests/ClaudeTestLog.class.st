"
The controlled facade for integration-test logging.

Tests call `ClaudeTestLog log: '...'` instead of touching Transcript
directly. Each call emits a ClaudeTestSignal, so whichever SignalLoggers
are running during the test run receive it: TranscriptLogger writes it
live, ClaudeFileSignalLogger appends it to a durable file, MemoryLogger
records it for assertions.

	(MemoryLogger new runDuring: [ ClaudeTestLog log: '>> hello' ])
		recordings anyOne message
	>>> '>> hello'

"
Class {
	#name : 'ClaudeTestLog',
	#superclass : 'Object',
	#category : 'Claude-Messaging-Client-Tests',
	#package : 'Claude-Messaging-Client-Tests'
}

{ #category : 'logging' }
ClaudeTestLog class >> log: aString [
	^ ClaudeTestSignal emit: aString
]
