"
Proves the SDK diagnostics and telemetry adoption against ClaudeMockServer: typed retry, exhaustion and outcome signals without content, a typed span in a sandboxed telemetry store, the disabled switch opening no store, and the PuntLog source gate over every production package. No live API.

	(ClaudeObservabilityTest run: #testSchemasAreValid) hasPassed
	>>> true
"
Class {
	#name : 'ClaudeObservabilityTest',
	#superclass : 'TestCase',
	#instVars : [
		'home',
		'mockServer',
		'client'
	],
	#category : 'Claude-Messaging-Observability-Tests',
	#package : 'Claude-Messaging-Observability-Tests'
}

{ #category : 'private' }
ClaudeObservabilityTest >> apiSignalsDuring: aBlock [
	^ ((MemoryLogger new runDuring: aBlock) recordings select: [ :each | each isKindOf: ClaudeApiSignal ]) asArray
]

{ #category : 'fixtures' }
ClaudeObservabilityTest >> messageResponseJson [
	^ '{"id": "msg_test123", "type": "message", "role": "assistant", "content": [{"type": "text", "text": "PRIVATE-REPLY"}], "model": "claude-sonnet-4-5-20250514", "stop_reason": "end_turn", "stop_sequence": null, "usage": {"input_tokens": 10, "output_tokens": 20}}'
]

{ #category : 'fixtures' }
ClaudeObservabilityTest >> newRequest [
	^ ClaudeMessageRequest new
		model: 'claude-sonnet-4-5-20250514';
		maxTokens: 64;
		addUserMessage: 'PRIVATE-PROMPT';
		yourself
]

{ #category : 'fixtures' }
ClaudeObservabilityTest >> respondOverloadedThenOk [
	mockServer respondTo: '/v1/messages' withSequence: {
		mockServer errorResponse: 529 message: 'PRIVATE-ERROR-BODY'.
		mockServer successResponse: self messageResponseJson }
]

{ #category : 'private' }
ClaudeObservabilityTest >> rows [
	| db |
	db := PuntTelemetryConnection openOn: (home / '.punt-labs' / ClaudeObservability tool / 'telemetry.db') pathString.
	^ [ db execute: 'SELECT name, attributes FROM signals' with: #() doing: [ :cursor | cursor rows ] ] ensure: [ db forceClose ]
]

{ #category : 'running' }
ClaudeObservabilityTest >> setUp [
	super setUp.
	PuntTelemetry shutdown.
	home := (FileLocator temp / ('claude-observe-' , UUID new asString)) asFileReference ensureCreateDirectory.
	mockServer := ClaudeMockServer startOn: 0.
	client := ClaudeClient apiKey: 'sk-ant-test-key-0123456789abcdef' baseUrl: 'http://localhost:' , mockServer port printString timeout: 5.
	client maxRetries: 2
]

{ #category : 'private' }
ClaudeObservabilityTest >> startTelemetry: aConfig [
	| telemetry |
	telemetry := PuntHome duringHome: home do: [
		PuntTelemetry startTool: ClaudeObservability tool config: aConfig schemas: ClaudeObservability schemas ].
	(aConfig disabled not and: [ telemetry isEnabled not ])
		ifTrue: [ self skip: 'telemetry off switch set in the environment' ].
	telemetry isEnabled ifTrue: [ self waitUntil: [ telemetry worker pipeline notNil ] ].
	^ telemetry
]

{ #category : 'running' }
ClaudeObservabilityTest >> tearDown [
	PuntTelemetry shutdown.
	mockServer stop.
	home ensureDeleteAll.
	super tearDown
]

{ #category : 'tests' }
ClaudeObservabilityTest >> testClientOperationsAreDeclared [
	| observed |
	observed := (ClaudeClient methods select: [ :each | each sendsSelector: #execute:withRetry: ])
		reject: [ :each | each selector = #executeWithRetry: ].
	self denyEmpty: observed.
	observed do: [ :each |
		self assert: (each literals anySatisfy: [ :literal | ClaudeApiRequestSpan operations includes: literal ]) ]
]

{ #category : 'tests' }
ClaudeObservabilityTest >> testDisabledTelemetryOpensNoStore [
	self startTelemetry: (PuntTelemetryConfig new disabled: true; yourself).
	self respondOverloadedThenOk.
	client sendMessage: self newRequest.
	self deny: (home / '.punt-labs' / ClaudeObservability tool / 'telemetry.db') exists
]

{ #category : 'tests' }
ClaudeObservabilityTest >> testFailedRequestEmitsFailedOutcome [
	| signals outcome |
	mockServer respondTo: '/v1/messages' withError: 401 message: 'PRIVATE-ERROR-BODY'.
	signals := self apiSignalsDuring: [
		self should: [ client sendMessage: self newRequest ] raise: ClaudeAuthError ].
	outcome := signals detect: [ :each | each isKindOf: ClaudeApiOutcomeSignal ].
	self assert: outcome message equals: 'API request failed'.
	self assert: outcome errorClass equals: 'ClaudeAuthError'.
	self assert: outcome statusCode equals: 401
]

{ #category : 'tests' }
ClaudeObservabilityTest >> testRetryDiagnosticsCarryNoContent [
	| signals rendered |
	self respondOverloadedThenOk.
	signals := self apiSignalsDuring: [ client sendMessage: self newRequest ].
	self assert: (signals collect: [ :each | each class ]) asArray equals: { ClaudeApiRetrySignal. ClaudeApiOutcomeSignal }.
	self assert: signals first statusCode equals: 529.
	self assert: signals last retries equals: 1.
	rendered := String streamContents: [ :stream | signals do: [ :each | stream nextPutAll: each printOneLineString ] ].
	#('PRIVATE' 'sk-ant' 'localhost') do: [ :secret | self deny: (rendered includesSubstring: secret) ]
]

{ #category : 'tests' }
ClaudeObservabilityTest >> testRetryExhaustionWarns [
	| signals |
	mockServer respondTo: '/v1/messages' withSequence: ((1 to: 3) collect: [ :each | mockServer errorResponse: 500 message: 'PRIVATE-ERROR-BODY' ]).
	signals := self apiSignalsDuring: [
		self should: [ client sendMessage: self newRequest ] raise: ClaudeServerError ].
	self assert: (signals count: [ :each | each isKindOf: ClaudeApiRetrySignal ]) equals: 2.
	self assert: (signals anySatisfy: [ :each | (each isKindOf: ClaudeApiRetryExhaustedSignal) and: [ each retries = 2 ] ])
]

{ #category : 'tests' }
ClaudeObservabilityTest >> testSchemasAreValid [
	ClaudeObservability schemas do: [ :each | each validateDefinition ].
	self assert: ClaudeObservability schemas equals: { ClaudeApiRequestSpan }
]

{ #category : 'tests' }
ClaudeObservabilityTest >> testSmokeEnvironmentFallsBackToDefault [
	self
		assert: (ClaudeObservabilitySmoke new environment: 'ANTHROPIC_SDK_PHARO_SMOKE_UNSET' default: 'fallback')
		equals: 'fallback'
]

{ #category : 'tests' }
ClaudeObservabilityTest >> testSourceGate [
	"ClaudeObservability is the SDK's own logging entry point; no other
	 production class may name a sink."
	| packages |
	packages := (PackageOrganizer default packages collect: [ :each | each name ]) select: [ :name |
		(name beginsWith: 'Claude-Messaging-') and: [ (name endsWith: '-Tests') not ] ].
	self
		assert: (PuntLogSourceGate
			violationsInPackages: packages , #('PharoKeyring')
			allowing: #(#ClaudeObservability))
		equals: OrderedCollection new
]

{ #category : 'tests' }
ClaudeObservabilityTest >> testStreamRetriesCountTowardStreamOutcome [
	| outcome |
	mockServer respondTo: '/v1/messages' withSequence: {
		mockServer errorResponse: 529 message: 'PRIVATE-ERROR-BODY'.
		ZnResponse ok: (ZnEntity text: ClaudeClientStreamingTest new sseResponseBody) }.
	outcome := (self apiSignalsDuring: [ client streamMessage: self newRequest do: [ :event | event ] ])
		detect: [ :each | each isKindOf: ClaudeApiOutcomeSignal ].
	self assert: outcome operation equals: #stream.
	self assert: outcome retries equals: 1
]

{ #category : 'tests' }
ClaudeObservabilityTest >> testTelemetryRecordsTypedSpan [
	| rows attributes |
	self startTelemetry: PuntTelemetryConfig new.
	self respondOverloadedThenOk.
	client sendMessage: self newRequest.
	self waitUntil: [ self rows notEmpty ].
	rows := self rows.
	self assert: rows first first equals: 'anthropic-sdk-pharo.api.request'.
	attributes := STONJSON fromString: rows first last.
	self assert: (attributes at: 'operation') equals: 'messages'.
	self assert: (attributes at: 'outcome') equals: 'ok'.
	self assert: (attributes at: 'retries') equals: 1.
	#('PRIVATE' 'sk-ant') do: [ :secret | self deny: (rows first last includesSubstring: secret) ]
]

{ #category : 'private' }
ClaudeObservabilityTest >> waitUntil: aBlock [
	| started |
	started := Time millisecondClockValue.
	[ aBlock value or: [ (Time millisecondsSince: started) > 5000 ] ] whileFalse: [ (Delay forMilliseconds: 10) wait ].
	self assert: aBlock value
]
