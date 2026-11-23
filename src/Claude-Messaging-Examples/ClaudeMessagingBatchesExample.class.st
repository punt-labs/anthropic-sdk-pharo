"
Demonstrate the Batches API: submit a small batch of Messages requests, poll until the batch ends, then stream the JSONL results and dispatch each entry polymorphically on its outcome (succeeded, errored, canceled, expired).

The build helper is pure and doctestable; the run helper takes a `ClaudeClient` and performs the full create -> poll -> stream loop. `runOn:reportingOn:` writes a progress line per entry to a stream the caller displays, for example `ClaudeMessagingBatchesExample runOn: client reportingOn: Transcript`.

The streaming block uses `isSucceeded`, `isErrored`, `isCanceled`, and `isExpired` predicates instead of comparing `result type` strings -- that's the exact ergonomic this example exists to demonstrate. Adding a fifth outcome on the wire would never break this call site.

  ClaudeMessagingBatchesExample buildSampleCreateParams size
  >>> 2

  ClaudeMessagingBatchesExample buildSampleCreateParams requests first customId
  >>> 'r-1'

  ClaudeMessagingBatchesExample buildSampleCreateParams requests second customId
  >>> 'r-2'

  ClaudeMessagingBatchesExample buildSampleCreateParams requests first params model
  >>> 'claude-haiku-4-5-20251001'

  ClaudeMessagingBatchesExample buildSampleCreateParams requests first params maxTokens
  >>> 64

"
Class {
	#name : 'ClaudeMessagingBatchesExample',
	#superclass : 'Object',
	#category : 'Claude-Messaging-Examples',
	#package : 'Claude-Messaging-Examples'
}

{ #category : 'building' }
ClaudeMessagingBatchesExample class >> buildSampleCreateParams [
	"Build a sample ClaudeBatchCreateParams with two trivial Messages requests.
	 Each request uses Haiku with a tiny maxTokens to keep batch turnaround fast
	 when the example is run live. Pure -- no network call, safe to invoke in
	 doctests and unit tests."
	| params |
	params := ClaudeBatchCreateParams new.
	params addRequest: (ClaudeBatchRequest
		customId: 'r-1'
		params: (ClaudeMessageRequest new
			model: ClaudeModel haiku55;
			maxTokens: 64;
			addUserMessage: 'Say hello in one short sentence.';
			yourself)).
	params addRequest: (ClaudeBatchRequest
		customId: 'r-2'
		params: (ClaudeMessageRequest new
			model: ClaudeModel haiku55;
			maxTokens: 64;
			addUserMessage: 'Name one primary color in one word.';
			yourself)).
	^ params
]

{ #category : 'private' }
ClaudeMessagingBatchesExample class >> report: anEntry on: aStream [
	"Write one line for anEntry, dispatched on its outcome predicates."
	anEntry isSucceeded ifTrue: [ ^ self reportSucceeded: anEntry on: aStream ].
	anEntry isErrored ifTrue: [ ^ self reportErrored: anEntry on: aStream ].
	(anEntry isCanceled or: [ anEntry isExpired ])
		ifTrue: [ self reportCanceledOrExpired: anEntry on: aStream ]
]

{ #category : 'private' }
ClaudeMessagingBatchesExample class >> reportCanceledOrExpired: anEntry on: aStream [
	"Write a canceled or expired batch entry with the outcome type."
	aStream
		nextPutAll: anEntry customId;
		space;
		nextPutAll: (anEntry isCanceled ifTrue: [ 'CANCELED' ] ifFalse: [ 'EXPIRED' ]);
		cr
]

{ #category : 'private' }
ClaudeMessagingBatchesExample class >> reportErrored: anEntry on: aStream [
	"Write an errored batch entry with the inner error message."
	| err message |
	err := anEntry result error.
	message := err ifNil: [ '<no error payload>' ] ifNotNil: [ err message ifNil: [ '<no message>' ] ].
	aStream
		nextPutAll: anEntry customId;
		nextPutAll: ' ERROR: ';
		nextPutAll: message;
		cr
]

{ #category : 'private' }
ClaudeMessagingBatchesExample class >> reportSucceeded: anEntry on: aStream [
	"Write a succeeded batch entry, truncating the message text to a leading
	 slice so a noisy generation never floods the report."
	| msg text snippet |
	msg := anEntry result message.
	text := msg ifNil: [ '' ] ifNotNil: [ msg textContent ifNil: [ '' ] ].
	snippet := text size > 60
		ifTrue: [ (text first: 60) , '...' ]
		ifFalse: [ text ].
	aStream
		nextPutAll: anEntry customId;
		nextPutAll: ' OK: ';
		nextPutAll: snippet;
		cr
]

{ #category : 'examples' }
ClaudeMessagingBatchesExample class >> run [
	"Run the example using a client resolved from the keyring or env. Returns the
	 OrderedCollection of ClaudeBatchResults from the live API."
	^ self runOn: ClaudeSDKExampleSupport resolveClient
]

{ #category : 'running' }
ClaudeMessagingBatchesExample class >> runOn: aClaudeClient [
	"Drive the full Batches lifecycle against the given client and answer the
	 OrderedCollection of every ClaudeBatchResult in submission order. To watch
	 progress, use runOn:reportingOn: with a stream such as the Transcript."
	^ self runOn: aClaudeClient reportingOn: (WriteStream on: String new)
]

{ #category : 'running' }
ClaudeMessagingBatchesExample class >> runOn: aClaudeClient reportingOn: aStream [
	"Drive the full Batches lifecycle against the given client:
	   1. Submit the sample batch via createBatch:
	   2. Poll every 2 seconds via pollBatch:untilEndedEvery: until the batch ends
	   3. Stream the JSONL results via streamBatchResults:do:
	      and dispatch each entry polymorphically on its outcome (no `type =` chains).

	 Answers the OrderedCollection of every ClaudeBatchResult yielded by the stream
	 in submission order. Writes one progress line per step and entry to aStream,
	 the caller's display, never a diagnostic sink."
	| created |
	created := aClaudeClient createBatch: self buildSampleCreateParams.
	aStream
		nextPutAll: 'Created batch ';
		nextPutAll: created id;
		nextPutAll: ' (';
		nextPutAll: created processingStatus;
		nextPutAll: ')';
		cr.
	aClaudeClient pollBatch: created id untilEndedEvery: 2.
	aStream
		nextPutAll: 'Batch ';
		nextPutAll: created id;
		nextPutAll: ' ended; streaming results...';
		cr.
	^ aClaudeClient
		streamBatchResults: created id
		do: [ :entry | self report: entry on: aStream ]
]
