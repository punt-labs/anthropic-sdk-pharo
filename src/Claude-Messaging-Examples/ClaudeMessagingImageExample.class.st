"
Demonstrate URL-source image input. Builds a ClaudeMessageRequest
whose user turn carries a ClaudeImageBlock with a URL-source pointing
at a stable public PNG, plus a ClaudeTextBlock asking the model to
describe the image. The response carries assistant text and a usage
record whose inputTokens count reflects the processed image.

URL-source image blocks are natively supported by the Messages API.
No beta header is required. The server fetches the image from the URL,
feeds it into the model, and charges inputTokens against both the text
and the image. For this prompt shape, a text-only equivalent is
~50-80 tokens; a processed image typically adds hundreds more,
exceeding the >200 assertion threshold by a wide margin. The delta is
the server-computed proof that the image reached the model's context.
(Hard numbers live in the test-artifact result log, not in docstrings,
so comments don't drift when token pricing or compression changes.)

**URL choice.** The default is a PNG hosted on our own domain
(punt-labs.com). Hosting the asset ourselves removes the third-party
image-host dependency: the test no longer relies on a stranger's asset
availability or fetcher policy. (It still calls Anthropic's API, as any
live integration test must.) URL-source images are natively supported
by the Messages API with no beta header. See `exampleImageUrl` for
specifics.

**Prompt design.** The question asks for a single-sentence description
so the response is cheap and the stopReason is predictable (#end_turn
rather than #max_tokens). The content of the description is irrelevant
to the integration test: the test proves the server received and
processed the image, not that it described it correctly.

  ClaudeMessagingImageExample buildRequest model
  >>> 'claude-sonnet-4-6'

  ClaudeMessagingImageExample buildRequest maxTokens
  >>> 512

  ClaudeMessagingImageExample buildRequest messages first content first type
  >>> 'image'

  ClaudeMessagingImageExample buildRequest messages first content size
  >>> 2

"
Class {
	#name : 'ClaudeMessagingImageExample',
	#superclass : 'Object',
	#category : 'Claude-Messaging-Examples',
	#package : 'Claude-Messaging-Examples'
}

{ #category : 'building' }
ClaudeMessagingImageExample class >> buildRequest [
	"Build a ClaudeMessageRequest carrying a URL-source image block and a
	 one-line text prompt asking the model to describe the image. The server
	 fetches the image from the URL, feeds it into the model, and returns a
	 response whose inputTokens count proves the image was processed."

	| req imageBlock textBlock |
	req := ClaudeMessageRequest new.
	req model: ClaudeModel sonnet46.
	req maxTokens: 512.
	imageBlock := ClaudeImageBlock fromUrl: self exampleImageUrl.
	textBlock := ClaudeTextBlock
		text: 'Describe this image in one sentence.'.
	req addUserContent: { imageBlock. textBlock }.
	^ req
]

{ #category : 'building' }
ClaudeMessagingImageExample class >> exampleImageUrl [
	"Return the default image URL used by this example. The image is a PNG
	 hosted on our own domain (punt-labs.com), so this test no longer relies
	 on a third-party image-host's asset availability or fetcher policy.
	 (It still calls Anthropic's API, as any live integration test must.)
	 URL-source images are natively supported by the Messages API with no
	 beta header required; the server fetches the image and the model
	 downsamples it as needed.

	 If the asset ever moves, update this method."
	^ 'https://www.punt-labs.com/og-default.png'
]

{ #category : 'private' }
ClaudeMessagingImageExample class >> resolveClient [
	^ ClaudeSDKExampleSupport resolveClient
]

{ #category : 'examples' }
ClaudeMessagingImageExample class >> run [
	"Send the example image-input request and return the response."
	^ self runOn: self resolveClient
]

{ #category : 'examples' }
ClaudeMessagingImageExample class >> runOn: aClient [
	"Send the image-input request using the given client and return the
	 response. The response inputTokens will reflect the processed image:
	 a text-only equivalent of this prompt shape is ~50-80 tokens; a
	 processed image typically adds hundreds more, well above the >200
	 assertion threshold."
	^ aClient sendMessage: self buildRequest
]
