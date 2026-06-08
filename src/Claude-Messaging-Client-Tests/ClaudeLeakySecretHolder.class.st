"
A test fixture whose printOn: DELIBERATELY renders a held secret, used only by
ClaudeLoggingTestResultTest to prove ClaudeLoggingTestResult derives stack-frame strings
structurally (class>>selector) and never from a frame receiver printString. If the logger
ever printed receivers, the planted secret would leak into the log; the C3 regression test
asserts it does not.

  (ClaudeLeakySecretHolder new secret: ''sk-ant-LEAK'') printString
  >>> ''ClaudeLeakySecretHolder(sk-ant-LEAK)''

"
Class {
	#name : 'ClaudeLeakySecretHolder',
	#superclass : 'Object',
	#instVars : [
		'secret'
	],
	#category : 'Claude-Messaging-Client-Tests',
	#package : 'Claude-Messaging-Client-Tests'
}

{ #category : 'printing' }
ClaudeLeakySecretHolder >> printOn: aStream [
	"Deliberately leaks the held secret into printString, so a test can prove the logger derives
	frame strings structurally (class>>selector) and never via the receiver printString."
	aStream nextPutAll: 'ClaudeLeakySecretHolder(';
		nextPutAll: (secret ifNil: [ '' ]);
		nextPut: $)
]

{ #category : 'tests' }
ClaudeLeakySecretHolder >> raiseInMyOwnFrame [
	"Raise an Error from a method whose RECEIVER (self) holds a secret and would render it via
	printString. The signaler stack therefore contains a frame whose receiver leaks — the logger
	must not print that receiver."
	Error signal: 'leaky frame boom'
]

{ #category : 'accessing' }
ClaudeLeakySecretHolder >> secret: aString [ secret := aString
]
