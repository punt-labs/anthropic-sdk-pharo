"
Demonstrate extended thinking. Builds a ClaudeMessageRequest that
turns on adaptive thinking with a summarized display and asks the
model a reasoning-heavy question. The response carries at least one
ClaudeThinkingBlock alongside the assistant's final ClaudeTextBlock.

Extended thinking is uniquely well-suited to live integration tests
because both the thinking content and its cryptographic signature are
server-computed. The client cannot fabricate either value: the
signature is derived from the thinking content plus server-side
secrets and is required to round-trip thinking blocks in subsequent
requests.

**Adaptive, not a fixed budget.** Current models (the Claude 5
family) reject `thinking: {type: enabled, budget_tokens: N}` with a
400; the model decides how much to think, steered by effort. The
`display: summarized` option makes the response carry a readable
summary of the reasoning. Without it these models default to
`omitted`, which returns thinking blocks whose text is empty.

**Why Monty Hall.** The prompt is a reasoning-heavy puzzle whose
counter-intuitive answer (2/3, not 1/2) drives the model to produce
visible chain-of-thought. A trivia question would often collapse to
a single text block.

**Wiring.** `ClaudeMessageRequest` has no `thinkingParams:` setter.
Set thinking via `req thinking: aDict`, where the dict is built from
`(ClaudeThinkingParams adaptiveWithDisplay: aString) asDictionary`.
The request serializer reads back into `thinkingParams` and appends a
`thinking` field to the wire body.

  ClaudeMessagingThinkingExample buildRequest model
  >>> 'claude-opus-5-5'

  ClaudeMessagingThinkingExample buildRequest maxTokens
  >>> 2048

  ClaudeMessagingThinkingExample buildRequest thinkingParams type
  >>> 'adaptive'

  ClaudeMessagingThinkingExample buildRequest thinkingParams display
  >>> 'summarized'

"
Class {
	#name : 'ClaudeMessagingThinkingExample',
	#superclass : 'Object',
	#category : 'Claude-Messaging-Examples',
	#package : 'Claude-Messaging-Examples'
}

{ #category : 'building' }
ClaudeMessagingThinkingExample class >> buildRequest [
	"Build a ClaudeMessageRequest that turns on adaptive thinking with a
	 summarized display and asks a reasoning-heavy question. The response
	 will carry at least one ClaudeThinkingBlock with readable text
	 alongside the assistant's final text."
	| req |
	req := ClaudeMessageRequest new.
	req model: ClaudeModel opus55.
	req maxTokens: 2048.
	req thinking: (ClaudeThinkingParams adaptiveWithDisplay: 'summarized') asDictionary.
	req addUserMessage:
		'What is the Monty Hall problem? Show your reasoning step by step, then give the final answer.'.
	^ req
]

{ #category : 'private' }
ClaudeMessagingThinkingExample class >> resolveClient [
	^ ClaudeSDKExampleSupport resolveClient
]

{ #category : 'examples' }
ClaudeMessagingThinkingExample class >> run [
	"Send the example thinking-enabled request and return the response."
	^ self runOn: self resolveClient
]

{ #category : 'examples' }
ClaudeMessagingThinkingExample class >> runOn: aClient [
	"Send the thinking-enabled request using the given client and return the
	 response. The response content includes at least one ClaudeThinkingBlock
	 when the model decides the question warrants deliberation."
	^ aClient sendMessage: self buildRequest
]
