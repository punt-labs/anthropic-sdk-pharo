"
Tests for ClaudeInvalidRequestError (HTTP 400) — status code, registry wiring, and retryability.
"
Class {
	#name : 'ClaudeInvalidRequestErrorTest',
	#superclass : 'TestCase',
	#category : 'Claude-Messaging-Errors-Tests',
	#package : 'Claude-Messaging-Errors-Tests'
}

{ #category : 'testing' }
ClaudeInvalidRequestErrorTest >> testErrorTypeRegistry [
	"Test that invalid_request_error maps to ClaudeInvalidRequestError"
	| registry |
	registry := ClaudeApiError errorTypeRegistry.
	self assert: (registry at: 'invalid_request_error') equals: ClaudeInvalidRequestError
]

{ #category : 'testing' }
ClaudeInvalidRequestErrorTest >> testGenuineBadRequestIsNotRetryable [
	"A malformed-request 400 (the common case) must not be retried. Both a
	 schema-validation message and a generic one stay non-retryable so the
	 caller fails fast on a real client error."
	#('max_tokens: field required' 'model is required' 'messages: invalid type')
		do: [ :each |
			| error |
			error := ClaudeInvalidRequestError new message: each; yourself.
			self deny: error isRetryable
				description: (String streamContents: [ :s |
					s nextPutAll: 'genuine bad request must not be retryable: '.
					s nextPutAll: each ]).
			self deny: error isMCPConnectionError ]
]

{ #category : 'testing' }
ClaudeInvalidRequestErrorTest >> testMCPConnectionErrorIsRetryable [
	"The transient MCP-connector 400 must be retryable. Uses the exact live
	 message observed from Anthropic when its infrastructure cannot reach the
	 external MCP server."
	| error |
	error := ClaudeInvalidRequestError new
		message: 'Connection error while communicating with MCP server. The server may be unavailable or unresponsive.';
		yourself.
	self assert: error isMCPConnectionError.
	self assert: error isRetryable
]

{ #category : 'testing' }
ClaudeInvalidRequestErrorTest >> testNilMessageIsNotRetryable [
	"Defensive: a nil message (error constructed without a body) must not
	 crash isMCPConnectionError with a DNU and must answer not-retryable."
	| error |
	error := ClaudeInvalidRequestError new.
	self deny: error isMCPConnectionError.
	self deny: error isRetryable
]

{ #category : 'testing' }
ClaudeInvalidRequestErrorTest >> testStatusCode [
	"Test that ClaudeInvalidRequestError returns status code 400"
	| error |
	error := ClaudeInvalidRequestError new.
	self assert: error statusCode equals: 400
]

{ #category : 'testing' }
ClaudeInvalidRequestErrorTest >> testStatusRegistry [
	"Test that status code 400 maps to ClaudeInvalidRequestError"
	| registry |
	registry := ClaudeApiError statusRegistry.
	self assert: (registry at: 400) equals: ClaudeInvalidRequestError
]
