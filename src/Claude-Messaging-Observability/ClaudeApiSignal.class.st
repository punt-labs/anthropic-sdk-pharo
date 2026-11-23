"
PHARO-LOG-1, PHARO-LOG-5: Typed Beacon diagnostic for one ClaudeClient API request. Renders only approved metadata (operation, retry counts, delay, exception class, HTTP status), never request or response content, URLs, keys or exception text. Subclasses fix the level.

	String streamContents: [ :stream | ((ClaudeApiRetrySignal operation: #messages retry: 1 of: 5) exception: (ClaudeOverloadedError new statusCode: 529; message: 'private'; yourself); delayMs: 500; printOneLineContentsOn: stream) ]
	>>> 'API request retry scheduled operation=messages retries=1 maxRetries=5 delayMs=500 errorClass=ClaudeOverloadedError statusCode=529'
"
Class {
	#name : 'ClaudeApiSignal',
	#superclass : 'PuntLogSignal',
	#instVars : [
		'operation',
		'retries',
		'maxRetries',
		'errorClass',
		'statusCode',
		'delayMs'
	],
	#category : 'Claude-Messaging-Observability-Diagnostics',
	#package : 'Claude-Messaging-Observability',
	#tag : 'Diagnostics'
}

{ #category : 'accessing' }
ClaudeApiSignal >> delayMs [
	^ delayMs
]

{ #category : 'accessing' }
ClaudeApiSignal >> delayMs: anInteger [
	delayMs := anInteger
]

{ #category : 'accessing' }
ClaudeApiSignal >> errorClass [
	^ errorClass
]

{ #category : 'initialization' }
ClaudeApiSignal >> exception: anException [
	"Keep only the exception class and HTTP status: never the message text,
	 which can echo request or response content."
	errorClass := anException class name asString.
	statusCode := anException claudeStatusCode
]

{ #category : 'printing' }
ClaudeApiSignal >> fieldsOn: aStream [
	self optionalField: 'operation' value: operation on: aStream.
	self optionalField: 'retries' value: retries on: aStream.
	self optionalField: 'maxRetries' value: maxRetries on: aStream.
	self optionalField: 'delayMs' value: delayMs on: aStream.
	self optionalField: 'errorClass' value: errorClass on: aStream.
	self optionalField: 'statusCode' value: statusCode on: aStream
]

{ #category : 'initialization' }
ClaudeApiSignal >> initialize [
	super initialize.
	component := 'claude-client'
]

{ #category : 'accessing' }
ClaudeApiSignal >> maxRetries [
	^ maxRetries
]

{ #category : 'accessing' }
ClaudeApiSignal >> maxRetries: anInteger [
	maxRetries := anInteger
]

{ #category : 'accessing' }
ClaudeApiSignal >> operation [
	^ operation
]

{ #category : 'accessing' }
ClaudeApiSignal >> operation: aSymbol [
	operation := aSymbol
]

{ #category : 'printing' }
ClaudeApiSignal >> optionalField: aName value: anObject on: aStream [
	anObject ifNil: [ ^ self ].
	self field: aName value: anObject asString on: aStream
]

{ #category : 'accessing' }
ClaudeApiSignal >> retries [
	^ retries
]

{ #category : 'accessing' }
ClaudeApiSignal >> retries: anInteger [
	retries := anInteger
]

{ #category : 'accessing' }
ClaudeApiSignal >> statusCode [
	^ statusCode
]
