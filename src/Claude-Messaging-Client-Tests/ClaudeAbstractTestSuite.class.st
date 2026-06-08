"
Abstract base class for Claude SDK/Agent test suite factories. Holds the shared filtering machinery — `suiteExcluding:`, `suiteIncluding:`, `testClasses` — and the four entry-point selectors — `suite`, `fastSuite`, `fullSuite`, `integrationSuite`. Concrete subclasses override `packageNames` (required) and `suiteLabel` (optional, for a product-specific TestSuite name).

## Fast / slow / integration protocol convention

Every test method lives in a protocol that classifies its speed and external dependencies:

- `tests` (default): fast, hermetic — mock server or no network
- `tests-slow`: fast but non-hermetic — filesystem, subprocess, measurable wall clock (no network)
- `tests-integration`: live API against api.anthropic.com, requires ANTHROPIC_API_KEY, skipped when the key is absent

## Layer placement

This abstract lives in `Claude-Messaging-Client-Tests` so both the Messaging-layer and Agent-layer concrete factories can inherit from it — Agent already depends on Messaging at the production level. Pharo resolves the cross-layer reference at image time; Metacello does not need to declare it.

## Example (subclass side)

	ClaudeMessagingTestSuite packageNames size
	>>> 9

	ClaudeMessagingTestSuite suite class
	>>> TestSuite

"
Class {
	#name : 'ClaudeAbstractTestSuite',
	#superclass : 'Object',
	#classInstVars : [
		'lastErrorReports'
	],
	#category : 'Claude-Messaging-Client-Tests',
	#package : 'Claude-Messaging-Client-Tests'
}

{ #category : 'instance creation' }
ClaudeAbstractTestSuite class >> fastSuite [
	"Build a TestSuite excluding slow and integration tests."
	^ self suiteExcluding: #('tests-slow' 'tests-integration')
]

{ #category : 'instance creation' }
ClaudeAbstractTestSuite class >> fullSuite [
	"Build a TestSuite including all tests (including integration)."
	^ self suiteExcluding: #()
]

{ #category : 'instance creation' }
ClaudeAbstractTestSuite class >> integrationSuite [
	"Build a TestSuite containing ONLY tests in the tests-integration protocol.
	 Requires ANTHROPIC_API_KEY; individual tests skip cleanly when the key is absent."
	^ self suiteIncluding: #('tests-integration')
]

{ #category : 'accessing' }
ClaudeAbstractTestSuite class >> packageNames [
	"Answer the test package names aggregated by this suite factory.
	 Concrete subclasses override with a literal array."
	^ self subclassResponsibility
]

{ #category : 'running' }
ClaudeAbstractTestSuite class >> runFullWithErrorLogging [
	"Run the full suite (including integration) under a result that logs uncaught test errors as
	secret-safe stacktraces to three sinks: the durable .tmp/test-errors.log file, the result
	errorReports collection, and the Transcript. Every ClaudeTestLog message is captured both live
	(TranscriptLogger) and durably (.tmp/test.log). The reports are stashed class-side in
	lastErrorReports so they survive the eval. Answer the result.

	The durable-logging wiring lives in runSuite:withResult:debugLogFile: so a tiny in-memory suite
	can exercise the exact same path in a test.

	CWD DEPENDENCY: both log files resolve under FileSystem disk workingDirectory / .tmp. If the
	image''s working directory is not the repo root, the logs land under whatever directory the
	image was launched from. The resolved ABSOLUTE paths are echoed to the Transcript at run start."
	| result logFile |
	result := ClaudeLoggingTestResult new.
	logFile := (FileSystem disk workingDirectory / '.tmp') ensureCreateDirectory / 'test.log'.
	self runSuite: self fullSuite withResult: result debugLogFile: logFile.
	lastErrorReports := result errorReports.
	^ result
]

{ #category : 'running' }
ClaudeAbstractTestSuite class >> runSuite: aTestSuite withResult: aLoggingResult debugLogFile: aDebugLogFile [
	"Run aTestSuite under aLoggingResult with the full durable-logging wiring, identical to the
	wiring runFullWithErrorLogging uses. Truncates both the error-log file and aDebugLogFile with a
	header line, echoes their absolute paths to the Transcript, then runs the suite under both Beacon
	loggers (TranscriptLogger live + ClaudeFileSignalLogger durable). Answer aLoggingResult. Factored
	out so a tiny in-memory suite can exercise the exact production wiring without the live full suite."
	aLoggingResult errorLogFile ensureDelete.
	aLoggingResult errorLogFile ensureCreateFile.
	aLoggingResult errorLogFile writeStreamDo: [ :s |
		s nextPutAll: '=== Claude test errors (run start) ===' ; nextPut: Character lf ].
	aDebugLogFile ensureDelete.
	aDebugLogFile writeStreamDo: [ :s |
		s nextPutAll: '=== Claude test log (run start) ===' ; nextPut: Character lf ].
	Transcript
		nextPutAll: '[Claude test logging] error log: ';
		nextPutAll: aLoggingResult errorLogFile fullName;
		nextPut: Character lf;
		nextPutAll: '[Claude test logging] debug log: ';
		nextPutAll: aDebugLogFile fullName;
		nextPut: Character lf.
	TranscriptLogger new runDuring: [
		(ClaudeFileSignalLogger onFile: aDebugLogFile) runDuring: [
			aTestSuite run: aLoggingResult ] ].
	^ aLoggingResult
]

{ #category : 'instance creation' }
ClaudeAbstractTestSuite class >> suite [
	"Build a TestSuite containing all this factory's test cases.
	 Excludes tests in the tests-integration protocol."
	^ self suiteExcluding: #('tests-integration')
]

{ #category : 'instance creation' }
ClaudeAbstractTestSuite class >> suiteExcluding: protocolNames [
	"Build a TestSuite excluding test methods in the named protocols."
	| suite |
	suite := TestSuite named: self suiteLabel.
	self testClasses do: [ :cls |
		| methods |
		methods := cls testSelectors reject: [ :sel |
			protocolNames includes: (cls protocolNameOfSelector: sel) ].
		methods do: [ :sel | suite addTest: (cls selector: sel) ] ].
	^ suite
]

{ #category : 'instance creation' }
ClaudeAbstractTestSuite class >> suiteIncluding: protocolNames [
	"Build a TestSuite including ONLY test methods in the named protocols.
	 Symmetric counterpart to suiteExcluding:."
	| suite |
	suite := TestSuite named: self suiteLabel.
	self testClasses do: [ :cls |
		| methods |
		methods := cls testSelectors select: [ :sel |
			protocolNames includes: (cls protocolNameOfSelector: sel) ].
		methods do: [ :sel | suite addTest: (cls selector: sel) ] ].
	^ suite
]

{ #category : 'accessing' }
ClaudeAbstractTestSuite class >> suiteLabel [
	"The TestSuite name used by the factory entry points. Subclasses override."
	^ 'Claude Tests'
]

{ #category : 'accessing' }
ClaudeAbstractTestSuite class >> testClasses [
	"Answer all concrete TestCase subclasses from this suite factory''s
	 packages. Abstract test classes (isAbstract answers true) are fixtures
	 driven explicitly elsewhere and must not be auto-collected."
	^ self packageNames flatCollect: [ :pn |
		Smalltalk globals allClasses select: [ :c |
			(c includesBehavior: TestCase)
				and: [ c isAbstract not
				and: [ c package name = pn ] ] ] ]
]
