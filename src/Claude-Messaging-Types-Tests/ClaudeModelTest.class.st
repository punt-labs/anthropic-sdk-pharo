"
Tests for ClaudeModel factory methods.
"
Class {
	#name : 'ClaudeModelTest',
	#superclass : 'TestCase',
	#category : 'Claude-Messaging-Types-Tests',
	#package : 'Claude-Messaging-Types-Tests'
}

{ #category : 'tests' }
ClaudeModelTest >> testDefault [
	self assert: ClaudeModel default equals: 'claude-opus-5-5'
]

{ #category : 'tests' }
ClaudeModelTest >> testDefaultIsOpus55 [
	self assert: ClaudeModel default equals: ClaudeModel opus55
]

{ #category : 'tests' }
ClaudeModelTest >> testFable52 [
	self assert: ClaudeModel fable52 equals: 'claude-fable-5-2'
]

{ #category : 'tests' }
ClaudeModelTest >> testHaiku55 [
	self assert: ClaudeModel haiku55 equals: 'claude-haiku-5-5'
]

{ #category : 'tests' }
ClaudeModelTest >> testOpus48 [
	self assert: ClaudeModel opus48 equals: 'claude-opus-4-8'
]

{ #category : 'tests' }
ClaudeModelTest >> testOpus5 [
	self assert: ClaudeModel opus5 equals: 'claude-opus-5'
]

{ #category : 'tests' }
ClaudeModelTest >> testOpus55 [
	self assert: ClaudeModel opus55 equals: 'claude-opus-5-5'
]

{ #category : 'tests' }
ClaudeModelTest >> testSonnet5 [
	self assert: ClaudeModel sonnet5 equals: 'claude-sonnet-5'
]

{ #category : 'tests' }
ClaudeModelTest >> testSonnet55 [
	self assert: ClaudeModel sonnet55 equals: 'claude-sonnet-5-5'
]
