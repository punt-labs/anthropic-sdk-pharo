"
End-to-end integration tests against the real Claude API. Resolves the API key via
``ClaudeSDKExampleSupport resolveClient`` (OS keyring first, ``ANTHROPIC_API_KEY``
env var second). When neither is present, ``setUp`` skips cleanly via ``self skip:``
rather than failing -- a key-less image (CI fork PR, fresh dev box) is not a red.

These tests are excluded from ``make test``; they run via ``ClaudeMessagingTestSuite
fullSuite`` in the slow-suite workflow. Rotates across current-catalog models
(opus47, opus46, sonnet46) with low ``maxTokens`` to minimise cost.

  ClaudeIntegrationTest buildSuite run
  >>> a TestResult

"
Class {
	#name : 'ClaudeIntegrationTest',
	#superclass : 'TestCase',
	#instVars : [
		'client'
	],
	#category : 'Claude-Messaging-Client-Tests',
	#package : 'Claude-Messaging-Client-Tests'
}

{ #category : 'private' }
ClaudeIntegrationTest >> modelOpus46 [
	"Current-catalog Opus 4.6 identifier for integration tests"
	^ ClaudeModel opus46
]

{ #category : 'private' }
ClaudeIntegrationTest >> modelOpus47 [
	"Current-catalog Opus 4.7 identifier for integration tests"
	^ ClaudeModel opus47
]

{ #category : 'private' }
ClaudeIntegrationTest >> modelSonnet46 [
	"Current-catalog Sonnet 4.6 identifier for integration tests"
	^ ClaudeModel sonnet46
]

{ #category : 'private' }
ClaudeIntegrationTest >> newParams: prompt maxTokens: max [
	"Default model for tests that don't specify one. Uses Sonnet 4.6 as the lowest-cost current model."
	^ self newParams: prompt maxTokens: max model: self modelSonnet46
]

{ #category : 'private' }
ClaudeIntegrationTest >> newParams: prompt maxTokens: max model: modelId [
	| params |
	params := ClaudeMessageRequest new.
	params model: modelId.
	params maxTokens: max.
	params addUserMessage: prompt.
	^ params
]

{ #category : 'running' }
ClaudeIntegrationTest >> setUp [
	"Resolve a ClaudeClient via the shared keyring/env-var fallback chain. Skips
	cleanly when no key is available so a key-less image (CI fork PR, fresh dev
	box) does not red-fail the suite. This avoids the 'sh: secret-tool: not found'
	noise that came from probing secret-tool unconditionally on Linux runners."
	super setUp.
	[ client := ClaudeSDKExampleSupport resolveClient ]
		on: Error do: [ :e | ^ self skip: e messageText ].
	Transcript
		nextPutAll: '=== ';
		nextPutAll: self selector;
		nextPutAll: ' ===';
		cr
]

{ #category : 'tests' }
ClaudeIntegrationTest >> testCountTokens [
	| params result |
	params := self newParams: 'Hello' maxTokens: 50 model: self modelOpus46.
	ClaudeTestLog log: '>> testCountTokens: counting tokens...'.
	result := client countTokens: params.
	ClaudeTestLog log: '<< Token count: ' , result inputTokens printString , ' input tokens'.
	self assert: (result isKindOf: ClaudeMessageTokensCount).
	self assert: result inputTokens > 0
]

{ #category : 'tests' }
ClaudeIntegrationTest >> testErrorInvalidKey [
	"Model choice is immaterial - the 401 fires before model lookup. Use the default helper."
	| badClient params |
	badClient := ClaudeClient apiKey: 'sk-invalid'.
	params := self newParams: 'Hello' maxTokens: 50.
	ClaudeTestLog log: '>> testErrorInvalidKey: expecting 401...'.
	self
		should: [ badClient sendMessage: params ]
		raise: ClaudeAuthError
		withExceptionDo: [ :e |
			ClaudeTestLog log: '<< Caught: ' , e class name , ' (' , e statusCode printString , ')'.
			self assert: e statusCode equals: 401 ]
]

{ #category : 'tests' }
ClaudeIntegrationTest >> testErrorUnknownModel [
	| params |
	params := ClaudeMessageRequest new.
	params model: 'nonexistent-model-xyz'.
	params maxTokens: 50.
	params addUserMessage: 'Hello'.
	ClaudeTestLog log: '>> testErrorUnknownModel: expecting 404...'.
	self
		should: [ client sendMessage: params ]
		raise: ClaudeNotFoundError
		withExceptionDo: [ :e |
			ClaudeTestLog log: '<< Caught: ' , e class name , ' (' , e statusCode printString , ')' ]
]

{ #category : 'tests' }
ClaudeIntegrationTest >> testListModels [
	| models |
	ClaudeTestLog log: '>> testListModels: fetching model list...'.
	models := client listModels.
	ClaudeTestLog log: '<< Listed: ' , models size printString , ' models'.
	self assert: (models isKindOf: OrderedCollection).
	self deny: models isEmpty.
	self assert: (models allSatisfy: [ :m | m isKindOf: ClaudeModelInfo ]).
	self assert: (models anySatisfy: [ :m | m id includesSubstring: 'claude' ])
]

{ #category : 'tests' }
ClaudeIntegrationTest >> testMultiTurnConversation [
	| params firstResponse secondResponse |
	params := self newParams: 'What is 2+2? Reply with just the number.' maxTokens: 50 model: self modelSonnet46.
	ClaudeTestLog log: '>> testMultiTurnConversation: sending first turn...'.
	firstResponse := client sendMessage: params.
	ClaudeTestLog log: '<< Turn 1: ' , firstResponse textContent size printString , ' chars, ' , firstResponse usage inputTokens printString , ' in / ' , firstResponse usage outputTokens printString , ' out tokens'.
	params addAssistantResponse: firstResponse.
	params addUserMessage: 'And what is that times 3? Reply with just the number.'.
	ClaudeTestLog log: '>> testMultiTurnConversation: sending second turn...'.
	secondResponse := client sendMessage: params.
	ClaudeTestLog log: '<< Turn 2: ' , secondResponse textContent size printString , ' chars, ' , secondResponse usage inputTokens printString , ' in / ' , secondResponse usage outputTokens printString , ' out tokens'.
	self deny: secondResponse textContent isEmpty
]

{ #category : 'tests-integration' }
ClaudeIntegrationTest >> testRealStreamingClose [
	"Verify socket closes cleanly after streaming completes."
	| sock decoder |
	sock := ClaudeStreamingSocket host: 'api.anthropic.com'.
	sock timeout: 30.
	sock connect.
	sock sendPost: '/v1/messages'
		headers: (OrderedDictionary newFromPairs: {
			'x-api-key'. client apiKey.
			'anthropic-version'. '2023-06-01'.
			'content-type'. 'application/json'.
			'accept'. 'text/event-stream' })
		body: (STONJSON toString: {
			'model' -> 'claude-sonnet-4-6'.
			'max_tokens' -> 20.
			'stream' -> true.
			'messages' -> { { 'role' -> 'user'. 'content' -> 'Hi' } asDictionary }
		} asDictionary).
	sock readStatusLine.
	sock readHeaders.
	decoder := ClaudeSSEDecoder onStream: sock.
	[ decoder hasNext ] whileTrue: [ decoder nextEvent ].
	sock close.
	self deny: sock isConnected
]

{ #category : 'tests-integration' }
ClaudeIntegrationTest >> testRealStreamingConnection [
	"Verify the TLS streaming socket connects, sends a request, and gets status 200."
	| sock statusCode headers decoder |
	sock := ClaudeStreamingSocket host: 'api.anthropic.com'.
	sock timeout: 30.
	sock connect.
	self assert: sock isConnected.
	sock sendPost: '/v1/messages'
		headers: (OrderedDictionary newFromPairs: {
			'x-api-key'. client apiKey.
			'anthropic-version'. '2023-06-01'.
			'content-type'. 'application/json'.
			'accept'. 'text/event-stream' })
		body: (STONJSON toString: {
			'model' -> 'claude-sonnet-4-6'.
			'max_tokens' -> 20.
			'stream' -> true.
			'messages' -> { { 'role' -> 'user'. 'content' -> 'Hi' } asDictionary }
		} asDictionary).
	statusCode := sock readStatusLine.
	headers := sock readHeaders.
	self assert: statusCode equals: 200.
	self assert: ((headers at: 'content-type') beginsWith: 'text/event-stream').
	"Drain the response to allow clean close"
	decoder := ClaudeSSEDecoder onStream: sock.
	[ decoder hasNext ] whileTrue: [ decoder nextEvent ].
	sock close
]

{ #category : 'tests-integration' }
ClaudeIntegrationTest >> testRealStreamingErrorHandling [
	"Verify TLS streaming raises ClaudeApiError for invalid API key. Expect ClaudeAuthError (401) or ClaudeTimeoutError if the network is slow."
	| badClient params |
	badClient := ClaudeClient apiKey: 'sk-invalid'.
	badClient streamingTimeout: 30.
	params := ClaudeMessageRequest new.
	params model: 'claude-sonnet-4-6'.
	params maxTokens: 50.
	params addUserMessage: 'Hello'.
	self
		should: [ badClient streamMessage: params do: [ :e | ] ]
		raise: ClaudeApiError
]

{ #category : 'tests-integration' }
ClaudeIntegrationTest >> testRealStreamingEvents [
	"Send a message via real TLS streaming socket, verify SSE events arrive and accumulate correctly."
	| sock decoder message events |
	sock := ClaudeStreamingSocket host: 'api.anthropic.com'.
	sock timeout: 30.
	sock connect.
	sock sendPost: '/v1/messages'
		headers: (OrderedDictionary newFromPairs: {
			'x-api-key'. client apiKey.
			'anthropic-version'. '2023-06-01'.
			'content-type'. 'application/json'.
			'accept'. 'text/event-stream' })
		body: (STONJSON toString: {
			'model' -> 'claude-sonnet-4-6'.
			'max_tokens' -> 50.
			'stream' -> true.
			'messages' -> { { 'role' -> 'user'. 'content' -> 'Say hi in 3 words' } asDictionary }
		} asDictionary).
	sock readStatusLine.
	sock readHeaders.
	decoder := ClaudeSSEDecoder onStream: sock.
	message := ClaudeMessage new.
	events := OrderedCollection new.
	[ decoder hasNext ] whileTrue: [
		| event |
		event := decoder nextEvent.
		events add: (event at: 'event').
		message accumulate: event ].
	sock close.
	self deny: message textContent isEmpty.
	self assert: message stopReason equals: #end_turn.
	self assert: (events includes: 'message_start').
	self assert: (events includes: 'content_block_delta').
	self assert: (events includes: 'message_stop').
	Transcript
		nextPutAll: '<< Real streaming: ';
		nextPutAll: events size printString;
		nextPutAll: ' events, text: ';
		nextPutAll: message textContent;
		cr
]

{ #category : 'tests-integration' }
ClaudeIntegrationTest >> testRealStreamingViaClient [
	"Verify streamMessage:do: uses real TLS streaming for HTTPS base URL."
	| params events message |
	params := ClaudeMessageRequest new.
	params model: 'claude-sonnet-4-6'.
	params maxTokens: 50.
	params addUserMessage: 'Reply with exactly: streaming works'.
	events := OrderedCollection new.
	message := client streamMessage: params do: [ :event |
		events add: (event at: 'event') ].
	self deny: message textContent isEmpty.
	self assert: message stopReason equals: #end_turn.
	self assert: (events includes: 'message_start').
	self assert: (events includes: 'message_stop').
	Transcript
		nextPutAll: '<< Client streaming: ';
		nextPutAll: events size printString;
		nextPutAll: ' events, text: ';
		nextPutAll: message textContent;
		cr
]

{ #category : 'tests' }
ClaudeIntegrationTest >> testSendMessage [
	| params response |
	params := self newParams: 'Reply with exactly: hello' maxTokens: 50 model: self modelOpus47.
	ClaudeTestLog log: '>> testSendMessage: sending to ' , client baseUrl.
	response := client sendMessage: params.
	ClaudeTestLog log: '<< Response: ' , response textContent size printString , ' chars, ' , response usage inputTokens printString , ' in / ' , response usage outputTokens printString , ' out tokens'.
	self assert: (response isKindOf: ClaudeMessage).
	self deny: response textContent isEmpty.
	self assert: response usage inputTokens > 0.
	self assert: response usage outputTokens > 0.
	self assert: response stopReason equals: #end_turn
]

{ #category : 'tests' }
ClaudeIntegrationTest >> testStreamMessage [
	| params events message |
	params := self newParams: 'Reply with exactly: hi' maxTokens: 50 model: self modelOpus46.
	ClaudeTestLog log: '>> testStreamMessage: streaming...'.
	events := OrderedCollection new.
	message := client streamMessage: params do: [ :event |
		events add: event.
		ClaudeTestLog log: '   event: ' , (event at: 'event') ].
	ClaudeTestLog log: '<< Streaming done: ' , events size printString , ' events, text: ' , message textContent size printString , ' chars'.
	self assert: events size >= 3.
	self assert: (events anySatisfy: [ :e | (e at: 'event') = 'message_start' ]).
	self assert: (events anySatisfy: [ :e | (e at: 'event') = 'content_block_start' ]).
	self assert: (events anySatisfy: [ :e | (e at: 'event') = 'message_stop' ]).
	self deny: message textContent isEmpty
]
