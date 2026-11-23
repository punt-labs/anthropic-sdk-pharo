"
PHARO-LOG-5, PHARO-LOG-6: DEBUG outcome of an observed API request. Success and failure are reported at the same level (symmetric coverage).

	String streamContents: [ :stream | (ClaudeApiOutcomeSignal completed: #models retries: 0) printOneLineContentsOn: stream ]
	>>> 'API request completed operation=models retries=0'
"
Class {
	#name : 'ClaudeApiOutcomeSignal',
	#superclass : 'ClaudeApiSignal',
	#category : 'Claude-Messaging-Observability-Diagnostics',
	#package : 'Claude-Messaging-Observability',
	#tag : 'Diagnostics'
}

{ #category : 'instance creation' }
ClaudeApiOutcomeSignal class >> completed: anOperation retries: anInteger [
	^ self new
		message: 'API request completed';
		operation: anOperation;
		retries: anInteger;
		yourself
]

{ #category : 'instance creation' }
ClaudeApiOutcomeSignal class >> failed: anOperation exception: anException retries: anInteger [
	^ self new
		message: 'API request failed';
		operation: anOperation;
		retries: anInteger;
		exception: anException;
		yourself
]

{ #category : 'accessing' }
ClaudeApiOutcomeSignal class >> level [
	^ PuntLogLevel debug
]
