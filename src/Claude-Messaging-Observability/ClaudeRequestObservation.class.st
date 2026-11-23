"
PHARO-LOG-5, PHARO-TEL-1: Tracks one ClaudeClient API request: counts retries, emits the typed retry and outcome signals, and records one ClaudeApiRequestSpan when the request completes or fails. Object subclass: a value object owned by a single request.

	(ClaudeRequestObservation operation: #files) retries
	>>> 0
"
Class {
	#name : 'ClaudeRequestObservation',
	#superclass : 'Object',
	#instVars : [
		'operation',
		'startedAt',
		'retries'
	],
	#category : 'Claude-Messaging-Observability-Lifecycle',
	#package : 'Claude-Messaging-Observability',
	#tag : 'Lifecycle'
}

{ #category : 'instance creation' }
ClaudeRequestObservation class >> operation: aSymbol [
	^ self new setOperation: aSymbol
]

{ #category : 'reporting' }
ClaudeRequestObservation >> completed [
	(ClaudeApiOutcomeSignal completed: operation retries: retries) emit.
	self recordOutcome: #ok cause: #none
]

{ #category : 'accessing' }
ClaudeRequestObservation >> elapsedMilliseconds [
	^ (Time millisecondsSince: startedAt) max: 0
]

{ #category : 'reporting' }
ClaudeRequestObservation >> exhausted: anException [
	(ClaudeApiRetryExhaustedSignal operation: operation retries: retries exception: anException) emit
]

{ #category : 'reporting' }
ClaudeRequestObservation >> failed: anException [
	(ClaudeApiOutcomeSignal failed: operation exception: anException retries: retries) emit.
	self recordOutcome: #failed cause: anException claudeTelemetryErrorKind
]

{ #category : 'accessing' }
ClaudeRequestObservation >> operation [
	^ operation
]

{ #category : 'private' }
ClaudeRequestObservation >> recordOutcome: anOutcome cause: aCause [
	^ ClaudeApiRequestSpan new
		operation: operation;
		outcome: anOutcome;
		cause: aCause;
		retries: retries;
		duration: self elapsedMilliseconds;
		record
]

{ #category : 'accessing' }
ClaudeRequestObservation >> retries [
	^ retries
]

{ #category : 'reporting' }
ClaudeRequestObservation >> retry: attempt of: maxAttempts error: anException delayMs: milliseconds [
	retries := attempt.
	(ClaudeApiRetrySignal operation: operation retry: attempt of: maxAttempts)
		exception: anException;
		delayMs: milliseconds;
		emit
]

{ #category : 'initialization' }
ClaudeRequestObservation >> setOperation: aSymbol [
	operation := aSymbol.
	startedAt := Time millisecondClockValue.
	retries := 0
]
