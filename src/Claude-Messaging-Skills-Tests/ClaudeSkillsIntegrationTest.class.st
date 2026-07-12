"
Live end-to-end integration test for the Skills API. Uploads a scratch
skill via `ClaudeMessagingSkillsExample uploadOn:displayTitle:` under a
title that is unique per run, round-trips it through `getSkill:`,
enumerates its versions via `listVersionsFor:`, and then deletes every
version and the skill itself. This is the first live-API test for Skills
-- it exists because PR #103 shipped with 96 mock-green tests and 3
production bugs that the mocks could not have caught.

**Idempotency.** The display title is built fresh every run as
`'Pharo SDK Test Skill ' , UUID new asString36`. The Anthropic Skills
API rejects a second skill that reuses an existing `display_title`, so a
FIXED title would fail deterministically the moment a prior run left a
skill behind (which is exactly what happened with the old hard-coded
'Example Skill' title). A unique title per run never collides with a
leftover. Cleanup is best-effort: a transient non-404 API error during
teardown is logged to Transcript and can leave a skill behind, but
because each run uses a unique display_title, a leftover can never cause
a future run to fail.

**Preconditions.** Requires an Anthropic API key, resolved by
`ClaudeSDKExampleSupport resolveClient` from either the OS keyring
(service `anthropic-api`, account `default`) or the `ANTHROPIC_API_KEY`
environment variable. When no key is present, every test in this class
skips via `self skip` -- tests do not fail on a key-less image. The
default suite (`ClaudeMessagingTestSuite suite`) excludes this class
by protocol; only `integrationSuite` includes it.

**Server-computed assertions.** Every assertion here targets a value
the server produces. The client cannot fake these:

- `skill id` -- server-generated skill identifier (accessor is `id`,
  not `skillId`; `skillId` lives on `ClaudeSkillVersion` as a
  back-pointer to its parent skill). Nil-guarded before content check.
- `skill createdAt` -- server-assigned ISO 8601 timestamp
- `skill latestVersion` -- server-assigned version id populated after
  a successful upload
- `getSkill: id` -- round-trips the uploaded skill, returning a
  `ClaudeSkill` (not a `ClaudeSkillVersion`)
- `listVersionsFor: id` -- server must report at least one version
  after a successful upload

`listSkills` is deliberately NOT asserted. It only returns the first
page (server default 20 items); on an account with >20 existing skills
the just-uploaded skill may land on a later page and produce a false
failure. `getSkill:` above already proves server-side persistence.

Client-constructed properties (e.g. `displayTitle`) are not asserted
here; asserting them would be tautological. Mock tests in
`ClaudeMockServerSkillsTest` cover those.

**Cleanup contract.** The Skills API rejects `deleteSkill:` when any
version still exists. The `ensure:` block re-lists versions rather
than reusing any outer binding -- if an assertion raises before the
outer `versions` variable is assigned, reusing it would silently skip
the delete loop and leak the skill in the real Anthropic account.
Re-listing inside `ensure:` makes the cleanup idempotent and complete.
The inner scratch directory created by `buildSkillUploadDirectory` is
cleaned up by `uploadOn:displayTitle:` itself, so we do not track it here.

  ClaudeSkillsIntegrationTest buildSuite
  >>> a TestSuite



"
Class {
	#name : 'ClaudeSkillsIntegrationTest',
	#superclass : 'TestCase',
	#category : 'Claude-Messaging-Skills-Tests',
	#package : 'Claude-Messaging-Skills-Tests'
}

{ #category : 'accessing' }
ClaudeSkillsIntegrationTest class >> defaultTimeLimit [
	"This test makes ~6 sequential live API round-trips (upload, getSkill:,
	 listVersionsFor:, then cleanup: listVersionsFor:params:, deleteVersion:for:,
	 deleteSkill:). At normal latency that is ~10-12s -- already at or over
	 SUnit's 10s default -- and under load each call may retry with backoff,
	 pushing well past it. A realistic per-test clock keeps the multi-call
	 round-trip from timing out spuriously; every call and every server-computed
	 assertion still runs."
	^ 60 seconds
]

{ #category : 'running' }
ClaudeSkillsIntegrationTest >> setUp [
	super setUp.
	ClaudeTestLog startActivityFor: self selector
]

{ #category : 'running' }
ClaudeSkillsIntegrationTest >> tearDown [
	ClaudeTestLog endActivityFor: self selector.
	super tearDown
]

{ #category : 'tests-integration' }
ClaudeSkillsIntegrationTest >> testSkillRoundTripAgainstAnthropic [
	"Upload a scratch skill, round-trip it through getSkill:, enumerate
	 versions, then delete every version and the skill. All assertions
	 target server-computed values. Cleanup runs even when an assertion
	 raises.

	 The display title is unique per run -- 'Pharo SDK Test Skill ' plus a
	 fresh UUID -- because the Skills API rejects a second skill that reuses
	 an existing display_title. A fixed title would fail deterministically
	 the moment a prior run left a skill behind. Cleanup is best-effort: a
	 transient non-404 API error during teardown is logged to Transcript and
	 can leave a skill behind, but because each run uses a unique
	 display_title, a leftover can never cause a future run to fail.

	 Note on listSkills: deliberately NOT asserted here. listSkills only
	 returns the first page (server default 20 items) and on accounts
	 with more than 20 existing skills the just-uploaded skill may land
	 on a later page, producing a false failure. The getSkill: round-trip
	 below already proves server-side persistence of the upload."

	| client skill roundTripped versions displayTitle |
	client := [ ClaudeSDKExampleSupport resolveClient ]
		on: Error do: [ :e | ^ self skip ].
	displayTitle := 'Pharo SDK Test Skill ' , UUID new asString36.
	ClaudeTestLog log: 'display title: ' , displayTitle.
	ClaudeTestLog log: 'uploading skill...'.
	skill := ClaudeMessagingSkillsExample uploadOn: client displayTitle: displayTitle.
	ClaudeTestLog log: 'uploaded: skill id=' , skill id printString , ' createdAt=' , skill createdAt printString , ' latestVersion=' , skill latestVersion printString.
	[
		"Nil-guard first, then content. An unexpected nil id would otherwise
		 raise MessageNotUnderstood from isNotEmpty and obscure the real
		 fault (server handed back an unpopulated response)."
		self
			assert: skill id isNotNil
			description: 'server-generated skill id must be present'.
		self
			assert: skill id isNotEmpty
			description: 'server-generated skill id must be non-empty'.
		self
			assert: skill createdAt isNotNil
			description: 'server-assigned createdAt timestamp must be populated'.
		self
			assert: skill latestVersion isNotNil
			description: 'server-assigned latestVersion id must be populated after upload'.
		ClaudeTestLog log: 'getSkill: round-trip for ' , skill id.
		roundTripped := client getSkill: skill id.
		ClaudeTestLog log: 'getSkill: returned id=' , roundTripped id printString , ' matched=' , (roundTripped id = skill id) printString.
		self
			assert: roundTripped class == ClaudeSkill
			description: 'getSkill: must return a ClaudeSkill (not a ClaudeSkillVersion)'.
		self
			assert: roundTripped id isNotNil
			description: 'getSkill: response must carry a non-nil skill id'.
		self
			assert: roundTripped id = skill id
			description: 'getSkill: must round-trip the uploaded skill id'.
		versions := client listVersionsFor: skill id.
		ClaudeTestLog log: 'listVersionsFor: returned ' , versions data size printString , ' version(s)'.
		self
			assert: versions data isNotEmpty
			description: 'listVersionsFor: must report at least one server-side version'
	] ensure: [
		"Paginate through every page of listVersionsFor: before deleting
		 the skill. The Skills API rejects deleteSkill: when any version
		 still exists, so a single-page cleanup would leak versions (and
		 then the skill itself) on any account that has more than the
		 server default page size. First-page-outside-loop with
		 whileTrue: [hasMore] is the correct Smalltalk idiom:
		 whileNotNil: with a pre-nil page token terminates before the
		 first fetch and never deletes anything.

		 Cascade ` ; yourself` on the next-page params is explicit-return
		 style. ClaudeSkillVersionListParams >> #page: has no explicit ^ --
		 in Pharo a ^-less method returns self, so
		 `ClaudeSkillVersionListParams new page: t` already returns the
		 params instance, not the String t. The cascade is retained for
		 clarity (it makes the receiver-as-result intent unambiguous) and
		 to guard against a future refactor that adds an explicit ^
		 returning something else.

		 The per-version handler narrows the swallow to ClaudeNotFoundError
		 (a partial prior cleanup may have removed the resource already);
		 any other ClaudeApiError is logged to Transcript so unexpected
		 failures stay visible on triage. Pharo's BlockClosure has only
		 #on:do: -- a chained on:do:on:do: does not exist -- so we
		 dispatch by `e class` inside a single handler. The same
		 discipline applies to the final deleteSkill:."
		skill ifNotNil: [
			| listParams page |
			ClaudeTestLog log: 'cleanup: deleting versions for ' , skill id.
			[ listParams := ClaudeSkillVersionListParams new.
			  page := client listVersionsFor: skill id params: listParams.
			  [ page data do: [ :v |
				  [ client deleteVersion: v version for: skill id.
				    ClaudeTestLog log: (String streamContents: [ :s |
						s nextPutAll: 'cleanup: deleted version '; nextPutAll: v version ]) ]
					on: ClaudeApiError do: [ :e |
						e class = ClaudeNotFoundError
							ifFalse: [
								Transcript
									nextPutAll: 'unexpected cleanup error deleting version ';
									nextPutAll: v version;
									nextPutAll: ': ';
									print: e;
									cr ] ] ].
			    page hasMore ] whileTrue: [
				listParams := ClaudeSkillVersionListParams new
					page: page nextPage;
					yourself.
				page := client listVersionsFor: skill id params: listParams ] ]
				on: ClaudeApiError do: [ :e |
					Transcript
						nextPutAll: 'unexpected cleanup error listing versions: ';
						print: e;
						cr ].
			[ client deleteSkill: skill id.
			  ClaudeTestLog log: 'cleanup: deleted skill ' , skill id ]
				on: ClaudeApiError do: [ :e |
					e class = ClaudeNotFoundError
						ifFalse: [
							Transcript
								nextPutAll: 'unexpected cleanup error deleting skill: ';
								print: e;
								cr ] ] ].
		ClaudeTestLog log: 'round-trip complete' ]

]
