"
HTTP 400 Invalid Request Error. Raised when the API rejects a malformed or invalid request.

  ClaudeInvalidRequestError new statusCode
  >>> 400

  (ClaudeApiError fromStatusCode: 400 json: '{""error"":{""message"":""bad param""}}' requestId: 'req_1') class name
  >>> 'ClaudeInvalidRequestError'

"
Class {
	#name : 'ClaudeInvalidRequestError',
	#superclass : 'ClaudeApiError',
	#category : 'Claude-Messaging-Errors',
	#package : 'Claude-Messaging-Errors'
}

{ #category : 'testing' }
ClaudeInvalidRequestError >> isRetryable [
	"A 400 invalid-request is normally a permanent client error and is
	 NOT retried. The one exception is a transient connection/upstream-
	 availability failure that Anthropic surfaces as a 400 — for example
	 an intermittent failure reaching an external MCP server, or any other
	 upstream connection it could not complete. That case (see
	 #isTransientConnectionError) IS retryable: the existing exponential
	 backoff + jitter gives the upstream a chance to recover. If the upstream
	 is genuinely down, retries exhaust and the error surfaces loudly — this
	 is not a green-guard. All other 400s stay non-retryable."

	^ self isTransientConnectionError
]

{ #category : 'testing' }
ClaudeInvalidRequestError >> isTransientConnectionError [
	"Answer true when this 400 is a transient connection/upstream-availability
	 failure that Anthropic surfaces with HTTP 400 + type=invalid_request_error,
	 rather than a genuine malformed request. Because the wire payload is
	 identical for both (status 400, same error type), the only available
	 discriminator is the message text.

	 The match is deliberately conservative: it fires only on
	 connection-specific phrasing that Anthropic uses for transient upstream
	 hiccups, and never on field-validation wording. Matched keywords:

	   'Connection error'            - leading phrase of every observed
	                                     transient (MCP and non-MCP upstream):
	                                     'Connection error while communicating
	                                     with <X> server. ...'
	   'unresponsive'                - the server-may-be-unresponsive tail
	   'unavailable or unresponsive' - the fuller availability tail

	 Why these and not others: each phrase describes a connection or
	 availability fault, never a request-shape fault. Genuine bad-request
	 400s use field-validation wording that contains none of these phrases,
	 e.g. 'max_tokens is required', 'model: field required',
	 'messages: field required', 'model not found'. So those stay
	 non-retryable. The earlier MCP-only matcher required the 'MCP server'
	 phrase; that requirement is dropped here so any transient upstream
	 connection 400 (MCP is now just one source) is covered.

	 nil-message safe: a body-less error answers false without a DNU."

	| text |
	text := message ifNil: [ ^ false ].
	^ (text includesSubstring: 'Connection error')
		or: [ (text includesSubstring: 'unavailable or unresponsive')
		or: [ text includesSubstring: 'unresponsive' ] ]
]

{ #category : 'accessing' }
ClaudeInvalidRequestError >> statusCode [
	"Return the HTTP status code for invalid request errors"
	^ 400
]
