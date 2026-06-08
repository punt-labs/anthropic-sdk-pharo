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
