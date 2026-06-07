"
A BeaconSignal carrying a single test-log message.

It is emitted by ClaudeTestLog and rendered one line at a time by any
SignalLogger (TranscriptLogger for live output, ClaudeFileSignalLogger for
a durable sink, MemoryLogger for assertions in tests).

	(ClaudeTestSignal new message: 'hello') message
	>>> 'hello'

	(MemoryLogger new runDuring: [ ClaudeTestSignal emit: 'hi' ]) recordings
		anyOne message
	>>> 'hi'

"
Class {
	#name : 'ClaudeTestSignal',
	#superclass : 'BeaconSignal',
	#instVars : [
		'message'
	],
	#category : 'Claude-Messaging-Client-Tests',
	#package : 'Claude-Messaging-Client-Tests'
}

{ #category : 'signalling' }
ClaudeTestSignal class >> emit: aString [
	^ self new
		message: aString;
		emit
]

{ #category : 'accessing' }
ClaudeTestSignal >> message [
	^ message
]

{ #category : 'accessing' }
ClaudeTestSignal >> message: anObject [
	message := anObject
]

{ #category : 'accessing' }
ClaudeTestSignal >> messageText [
	^ message
]

{ #category : 'printing' }
ClaudeTestSignal >> printOneLineContentsOn: stream [
	stream nextPutAll: self message
]
