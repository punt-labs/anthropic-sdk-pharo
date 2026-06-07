Class {
	#name : 'LinuxPassToolBackendTest',
	#superclass : 'TestCase',
	#instVars : [
		'backend'
	],
	#category : 'PharoKeyring-Tests',
	#package : 'PharoKeyring-Tests'
}

{ #category : 'running' }
LinuxPassToolBackendTest >> setUp [
	super setUp.
	backend := LinuxPassToolBackend new
]

{ #category : 'tests' }
LinuxPassToolBackendTest >> testExitCodeExtraction [
	self assert: (backend exitCodeFrom: 0) equals: 0.
	self assert: (backend exitCodeFrom: 256) equals: 1.
	self assert: (backend exitCodeFrom: 512) equals: 2
]

{ #category : 'tests' }
LinuxPassToolBackendTest >> testIsAvailable [
	self assert: backend isAvailable
]

{ #category : 'tests' }
LinuxPassToolBackendTest >> testName [
	self assert: backend name equals: 'pass'
]

{ #category : 'tests' }
LinuxPassToolBackendTest >> testPathForServiceAccount [
	self
		assert: (backend pathForService: 'anthropic' account: 'api-key')
		equals: 'anthropic/api-key'
]

{ #category : 'tests' }
LinuxPassToolBackendTest >> testPathQuotingIsApplied [
	"The path is interpolated into commands shell-quoted. Verify the
	building block (shellQuote: of the path) wraps a slash-bearing path
	in single quotes without corrupting the slash."
	| path quoted sq |
	sq := String with: (Character value: 39).
	path := backend pathForService: 'svc' account: 'acct'.
	quoted := backend shellQuote: path.
	self assert: quoted equals: sq, 'svc/acct', sq
]
