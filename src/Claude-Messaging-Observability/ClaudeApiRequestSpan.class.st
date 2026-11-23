"
PHARO-TEL-1, PHARO-TEL-2: Typed usage span for one SDK API request: closed enums for operation, outcome and cause, a retry count and the inherited duration in milliseconds. No identifiers, model names, content or token counts.

	ClaudeApiRequestSpan signalName
	>>> 'anthropic-sdk-pharo.api.request'

	(ClaudeApiRequestSpan causes includes: #overloaded)
	>>> true
"
Class {
	#name : 'ClaudeApiRequestSpan',
	#superclass : 'PuntTelemetrySchema',
	#instVars : [
		'operation',
		'outcome',
		'cause',
		'retries'
	],
	#category : 'Claude-Messaging-Observability-Telemetry',
	#package : 'Claude-Messaging-Observability',
	#tag : 'Telemetry'
}

{ #category : 'accessing' }
ClaudeApiRequestSpan class >> causes [
	^ #(#none #auth #billing #invalidRequest #notFound #overloaded #permission #rateLimit #server #timeout #network #api #other)
]

{ #category : 'accessing' }
ClaudeApiRequestSpan class >> fieldSpecs [
	^ {
		#operation -> (PuntTelemetryField enum: self operations required: true).
		#outcome -> (PuntTelemetryField enum: #(#ok #failed) required: true).
		#cause -> (PuntTelemetryField enum: self causes required: true).
		#retries -> (PuntTelemetryField kind: #count required: true) } asDictionary
]

{ #category : 'accessing' }
ClaudeApiRequestSpan class >> operations [
	^ #(#messages #countTokens #stream #models #files #skills #batches #other)
]

{ #category : 'accessing' }
ClaudeApiRequestSpan class >> signalName [
	^ ClaudeObservability tool , '.api.request'
]

{ #category : 'accessing' }
ClaudeApiRequestSpan >> cause [
	^ cause
]

{ #category : 'accessing' }
ClaudeApiRequestSpan >> cause: aSymbol [
	cause := aSymbol
]

{ #category : 'accessing' }
ClaudeApiRequestSpan >> operation [
	^ operation
]

{ #category : 'accessing' }
ClaudeApiRequestSpan >> operation: aSymbol [
	operation := aSymbol
]

{ #category : 'accessing' }
ClaudeApiRequestSpan >> outcome [
	^ outcome
]

{ #category : 'accessing' }
ClaudeApiRequestSpan >> outcome: aSymbol [
	outcome := aSymbol
]

{ #category : 'recording' }
ClaudeApiRequestSpan >> record [
	"Answer whether the running telemetry pipeline admitted this span;
	 false when telemetry is off or owned by a tool without this schema."
	^ PuntTelemetry record: self
]

{ #category : 'accessing' }
ClaudeApiRequestSpan >> retries [
	^ retries
]

{ #category : 'accessing' }
ClaudeApiRequestSpan >> retries: anInteger [
	retries := anInteger
]
