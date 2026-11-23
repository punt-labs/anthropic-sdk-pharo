"
PHARO-LOG-5: INFO decision to retry a retryable API error after a backoff delay.

	ClaudeApiRetrySignal level
	>>> PuntLogLevel info
"
Class {
	#name : 'ClaudeApiRetrySignal',
	#superclass : 'ClaudeApiSignal',
	#category : 'Claude-Messaging-Observability-Diagnostics',
	#package : 'Claude-Messaging-Observability',
	#tag : 'Diagnostics'
}

{ #category : 'instance creation' }
ClaudeApiRetrySignal class >> operation: anOperation retry: attempt of: maxAttempts [
	^ self new
		message: 'API request retry scheduled';
		operation: anOperation;
		retries: attempt;
		maxRetries: maxAttempts;
		yourself
]
