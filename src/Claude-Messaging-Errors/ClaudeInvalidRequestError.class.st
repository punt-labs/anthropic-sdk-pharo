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
ClaudeInvalidRequestError >> isMCPConnectionError [
	"Answer true when this 400 is Anthropic's transient MCP-connector
	 failure rather than a genuine malformed request. The wire payload
	 for both is type=invalid_request_error with HTTP 400, so the only
	 available discriminator is the message text. To avoid matching a
	 real bad-request 400, require BOTH the 'MCP server' phrase AND a
	 connection/availability keyword. The observed transient message is:
	 'Connection error while communicating with MCP server. The server
	 may be unavailable or unresponsive.' A malformed-request 400 (e.g.
	 'max_tokens is required') matches neither clause and stays
	 non-retryable. See bead skills-idempotency / MCP reliability."

	| text |
	text := message ifNil: [ ^ false ].
	(text includesSubstring: 'MCP server') ifFalse: [ ^ false ].
	^ (text includesSubstring: 'Connection error')
		or: [ (text includesSubstring: 'unavailable')
		or: [ text includesSubstring: 'unresponsive' ] ]
]

{ #category : 'testing' }
ClaudeInvalidRequestError >> isRetryable [
	"A 400 invalid-request is normally a permanent client error and is
	 NOT retried. The one exception is Anthropic's transient MCP-connector
	 failure, where the upstream connection from Anthropic to the external
	 MCP server fails intermittently and surfaces as a 400. That specific
	 case (see #isMCPConnectionError) IS retryable: the existing exponential
	 backoff + jitter gives the connector a chance to recover. If the MCP
	 server is genuinely down, retries exhaust and the error surfaces
	 loudly — this is not a green-guard. All other 400s stay non-retryable."

	^ self isMCPConnectionError
]

{ #category : 'accessing' }
ClaudeInvalidRequestError >> statusCode [
	"Return the HTTP status code for invalid request errors"
	^ 400
]
