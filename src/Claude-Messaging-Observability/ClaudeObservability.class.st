"
PHARO-LOG-1, PHARO-TEL-9: Entry point that starts and stops PuntLog and PuntTelemetry when a process runs the SDK as its own tool (~/.punt-labs/anthropic-sdk-pharo). Loading the package starts nothing. A host tool that already owns PuntLog receives the SDK signals in its own log instead. The telemetry argument is the config switch; PUNT_TELEMETRY=off and ANTHROPIC_SDK_PHARO_TELEMETRY=off veto it independently. Object subclass: a class-side lifecycle boundary with no state.

	ClaudeObservability tool
	>>> 'anthropic-sdk-pharo'

	ClaudeObservability schemas
	>>> { ClaudeApiRequestSpan }
"
Class {
	#name : 'ClaudeObservability',
	#superclass : 'Object',
	#category : 'Claude-Messaging-Observability-Lifecycle',
	#package : 'Claude-Messaging-Observability',
	#tag : 'Lifecycle'
}

{ #category : 'accessing' }
ClaudeObservability class >> schemas [
	^ { ClaudeApiRequestSpan }
]

{ #category : 'lifecycle' }
ClaudeObservability class >> startRole: aRole [
	^ self startRole: aRole telemetry: true
]

{ #category : 'operating' }
ClaudeObservability class >> startRole: aRole level: aLevel telemetry: aBoolean [
	"Start PuntLog at aLevel and PuntTelemetry for the SDK as its own tool and
	 answer the telemetry service. aBoolean is the host's telemetry config
	 switch; PUNT_TELEMETRY=off and ANTHROPIC_SDK_PHARO_TELEMETRY=off veto it
	 independently."
	PuntLog startTool: self tool role: aRole level: aLevel.
	^ PuntTelemetry
		startTool: self tool
		config: (PuntTelemetryConfig new disabled: aBoolean not; yourself)
		schemas: self schemas
]

{ #category : 'operating' }
ClaudeObservability class >> startRole: aRole telemetry: aBoolean [
	"Entry point for a process that runs the SDK as its own tool, logging at
	 INFO. See startRole:level:telemetry:."
	^ self startRole: aRole level: PuntLogLevel info telemetry: aBoolean
]

{ #category : 'lifecycle' }
ClaudeObservability class >> stop [
	PuntTelemetry shutdown.
	PuntLog stop
]

{ #category : 'accessing' }
ClaudeObservability class >> tool [
	^ 'anthropic-sdk-pharo'
]
