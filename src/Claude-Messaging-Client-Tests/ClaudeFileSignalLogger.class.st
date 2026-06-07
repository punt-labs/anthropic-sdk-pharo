"
Beacon's missing durable sink: a SignalLogger that appends each received
signal to a file, one rendered line per signal.

Beacon ships TranscriptLogger (live, ephemeral) and MemoryLogger (in-image,
lost on exit) but no file logger. This fills that gap, so an integration-test
run leaves a durable transcript on disk. The file defaults to
`.tmp/test.log` under the image working directory; inject another with
`logFile:` or the class-side `onFile:`.

	| f |
	f := (FileSystem disk workingDirectory / '.tmp') ensureCreateDirectory
		/ 'demo.log'.
	f ensureDelete.
	(ClaudeFileSignalLogger onFile: f)
		runDuring: [ ClaudeTestLog log: 'durable line' ].
	(f contents includesSubstring: 'durable line')
	>>> true

"
Class {
	#name : 'ClaudeFileSignalLogger',
	#superclass : 'SignalLogger',
	#instVars : [
		'file'
	],
	#category : 'Claude-Messaging-Client-Tests',
	#package : 'Claude-Messaging-Client-Tests'
}

{ #category : 'instance creation' }
ClaudeFileSignalLogger class >> onFile: aFileReference [
	^ self new logFile: aFileReference; yourself
]

{ #category : 'accessing' }
ClaudeFileSignalLogger >> file [
	^ file ifNil: [ file := (FileSystem disk workingDirectory / '.tmp') ensureCreateDirectory / 'test.log' ]
]

{ #category : 'accessing' }
ClaudeFileSignalLogger >> logFile: aFileReference [
	file := aFileReference
]

{ #category : 'utilities' }
ClaudeFileSignalLogger >> nextPut: aSignal [
	"Append the signal's rendered one-line text plus a newline to the durable file.
	 The write stream is positioned at end so successive signals accumulate."

	self file writeStreamDo: [ :stream |
		stream setToEnd.
		stream
			nextPutAll: aSignal printOneLineString;
			nextPut: Character lf ]
]
