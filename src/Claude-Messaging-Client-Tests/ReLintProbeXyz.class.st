Class {
	#name : 'ReLintProbeXyz',
	#superclass : 'Object',
	#category : 'Claude-Messaging-Client-Tests',
	#package : 'Claude-Messaging-Client-Tests'
}

{ #category : 't' }
ReLintProbeXyz >> a [ [ Smalltalk ] on: Error do: [ :e | nil ]
]

{ #category : 't' }
ReLintProbeXyz >> b [ [ 1/0 ] on: Error do: [ :e | ]
]
