"
A PuntLogDebugSignal carrying a single integration-test narration message, component integration-test.

It is emitted by ClaudeTestLog. ClaudeFileSignalLogger renders it into the per-run activity file, MemoryLogger captures it in tests, and while PuntLog runs it lands in the escaped, redacted durable log like any other DEBUG signal.

	(ClaudeTestSignal new message: 'hello'; yourself) message
	>>> 'hello'

	(MemoryLogger new runDuring: [ ClaudeTestSignal emit: 'hi' ]) recordings
		anyOne message
	>>> 'hi'
"
Class {
	#name : 'ClaudeTestSignal',
	#superclass : 'PuntLogDebugSignal',
	#category : 'Claude-Messaging-Client-Tests',
	#package : 'Claude-Messaging-Client-Tests'
}

{ #category : 'signalling' }
ClaudeTestSignal class >> emit: aString [
	^ self new
		message: aString;
		emit
]

{ #category : 'initialization' }
ClaudeTestSignal >> initialize [
	super initialize.
	component := 'integration-test'
]

{ #category : 'accessing' }
ClaudeTestSignal >> messageText [
	^ message
]
