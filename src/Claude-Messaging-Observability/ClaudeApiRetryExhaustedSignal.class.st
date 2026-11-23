"
PHARO-LOG-5: WARNING that the retry budget ran out; the error is re-signalled to the caller.

	ClaudeApiRetryExhaustedSignal level
	>>> PuntLogLevel warning
"
Class {
	#name : 'ClaudeApiRetryExhaustedSignal',
	#superclass : 'ClaudeApiSignal',
	#category : 'Claude-Messaging-Observability-Diagnostics',
	#package : 'Claude-Messaging-Observability',
	#tag : 'Diagnostics'
}

{ #category : 'accessing' }
ClaudeApiRetryExhaustedSignal class >> level [
	^ PuntLogLevel warning
]

{ #category : 'instance creation' }
ClaudeApiRetryExhaustedSignal class >> operation: anOperation retries: anInteger exception: anException [
	^ self new
		message: 'API request retries exhausted';
		operation: anOperation;
		retries: anInteger;
		exception: anException;
		yourself
]
