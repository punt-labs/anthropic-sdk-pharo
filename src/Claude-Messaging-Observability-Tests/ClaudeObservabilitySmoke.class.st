"
Installed-path smoke entry run by scripts/smoke in a fresh image with an isolated HOME: starts ClaudeObservability at DEBUG, drives ClaudeClient against ClaudeMockServer through a retried success, an auth failure and exhausted retries with fixture secrets in every body, optionally writes rotation filler, stops, and writes a JSON report. Object subclass: a one-shot script with no domain superclass.
"
Class {
	#name : 'ClaudeObservabilitySmoke',
	#superclass : 'Object',
	#instVars : [
		'mockServer',
		'client',
		'telemetry',
		'logger'
	],
	#category : 'Claude-Messaging-Observability-Tests',
	#package : 'Claude-Messaging-Observability-Tests'
}

{ #category : 'running' }
ClaudeObservabilitySmoke class >> run [
	"Entry point for scripts/smoke: answer 'smoke-ok' after one installed run."
	^ self new run
]

{ #category : 'private' }
ClaudeObservabilitySmoke >> environment: aName default: aString [
	^ OSEnvironment current at: aName ifAbsent: [ aString ]
]

{ #category : 'running' }
ClaudeObservabilitySmoke >> exerciseClient [
	"One retried success, one auth failure and one exhausted server failure:
	 INFO, DEBUG and WARNING records plus three telemetry spans. The mock
	 counts requests per path, so one sequence serves all six requests."
	mockServer respondTo: '/v1/messages' withSequence: {
		self privateError: 529. mockServer successResponse: self messageResponseJson.
		self privateError: 401.
		self privateError: 500. self privateError: 500. self privateError: 500 }.
	client sendMessage: self newRequest.
	[ client sendMessage: self newRequest ] on: ClaudeAuthError do: [ :error | error return: nil ].
	[ client sendMessage: self newRequest ] on: ClaudeServerError do: [ :error | error return: nil ]
]

{ #category : 'running' }
ClaudeObservabilitySmoke >> finish: anOutcome [
	mockServer stop.
	ClaudeObservability stop.
	self writeReport: anOutcome
]

{ #category : 'private' }
ClaudeObservabilitySmoke >> messageResponseJson [
	^ '{"id": "msg_smoke", "type": "message", "role": "assistant", "content": [{"type": "text", "text": "PRIVATE-REPLY"}], "model": "claude-sonnet-4-5-20250514", "stop_reason": "end_turn", "stop_sequence": null, "usage": {"input_tokens": 10, "output_tokens": 20}}'
]

{ #category : 'private' }
ClaudeObservabilitySmoke >> newRequest [
	^ ClaudeMessageRequest new
		model: 'claude-sonnet-4-5-20250514';
		maxTokens: 64;
		addUserMessage: 'PRIVATE-PROMPT smoke.customer@example.invalid';
		yourself
]

{ #category : 'private' }
ClaudeObservabilitySmoke >> privateError: aStatus [
	^ mockServer errorResponse: aStatus message: 'PRIVATE-ERROR-BODY Bearer FIXTURE-BEARER-SECRET https://fixture-user:fixture-pass@fixture.example.invalid/private?fixture-query#fixture-fragment'
]

{ #category : 'running' }
ClaudeObservabilitySmoke >> run [
	| disabled |
	disabled := (self environment: 'PUNT_SMOKE_CONFIG_DISABLED' default: '0') = '1'.
	telemetry := ClaudeObservability startRole: 'smoke' level: PuntLogLevel debug telemetry: disabled not.
	logger := PuntLog current.
	self startClient.
	[ self exerciseClient.
	  self writeRecords: (self environment: 'PUNT_SMOKE_RECORDS' default: '0') asNumber ]
		ifCurtailed: [ self finish: 'failed' ].
	self finish: 'ok'.
	^ 'smoke-ok'
]

{ #category : 'running' }
ClaudeObservabilitySmoke >> startClient [
	mockServer := ClaudeMockServer startOn: 0.
	client := (ClaudeClient
		apiKey: 'sk-ant-smoke-FIXTURE-KEY-0123456789'
		baseUrl: 'http://localhost:' , mockServer port printString
		timeout: 5)
		maxRetries: 2;
		yourself
]

{ #category : 'running' }
ClaudeObservabilitySmoke >> writeRecords: aCount [
	"DEBUG filler of about 47 KB per record to drive rotation, plus one line
	 carrying fixture secrets that PuntLog must redact."
	| payload |
	ClaudeTestLog log: 'redaction fixture Bearer FIXTURE-BEARER-SECRET https://fixture-user:fixture-pass@fixture.example.invalid/private?fixture-query#fixture-fragment'.
	payload := String streamContents: [ :stream | 500 timesRepeat: [ stream nextPutAll: (String new: 93 withAll: $p); space ] ].
	1 to: aCount do: [ :index |
		ClaudeTestLog log: (String streamContents: [ :stream |
			stream nextPutAll: 'TAG-'; print: index; space; nextPutAll: payload; nextPutAll: 'END-'; print: index ]) ]
]

{ #category : 'running' }
ClaudeObservabilitySmoke >> writeReport: anOutcome [
	| report |
	report := Dictionary newFrom: {
		'outcome' -> anOutcome.
		'telemetry_enabled' -> telemetry queue notNil.
		'worker_stopped' -> telemetry worker isNil.
		'telemetry_dropped' -> telemetry dropped.
		'log_drops' -> (Dictionary newFrom: (logger dropCounts associations collect: [ :pair | pair key asString -> pair value ])) }.
	(self environment: 'PUNT_SMOKE_REPORT' default: 'smoke-report.json') asFileReference
		writeStreamDo: [ :stream | stream nextPutAll: (STONJSON toString: report) ]
]
