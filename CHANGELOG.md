# Changelog

All notable changes to the Claude SDK for Pharo are documented
here. The format follows
[Keep a Changelog](https://keepachangelog.com/) and the project adheres
to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- **`make check-baseline` cold-load guard + CI `baseline` job.**
  A fresh-image `Metacello baseline: 'ClaudeSDK'; load` that fails
  on "No #baseline pragma found" or any load error, so the baseline
  stays cold-loadable by external consumers and this class of gap
  cannot silently regress.

- **`pass` keyring backend** (`LinuxPassToolBackend`): `PharoKeyring`
  resolves API keys from the `pass`(1) password store on Linux,
  preferred over `secret-tool` when both are installed (selected once
  at backend detection).

- **Two-tier API-key resolution** in `ClaudeSDKExampleSupport
  resolveClient`: an override ladder — a Pharo-specific slot
  (`ANTHROPIC_PHARO_API_KEY` env / keyring `anthropic/pharo-api-key`)
  then the general key (`ANTHROPIC_API_KEY` env / keyring
  `anthropic/api-key`) — env-var before keyring within each tier. The
  keyring identity (`service=anthropic`) renders per backend (`pass`,
  `secret-tool`, Keychain). Replaces the prior single
  `anthropic-api/default` lookup, and treats a present-but-empty env
  var as absent instead of building a client with an empty key.

- `ClaudeMessagingBatchesExample` example class demonstrating the
  full create -> poll -> stream loop with polymorphic outcome
  dispatch via `isSucceeded`/`isErrored`/`isCanceled`/`isExpired`
  predicates. Mirrors the Skills/MCP example shape with a pure
  doctestable `buildSampleCreateParams` and a `runOn:` entry that
  drives the full Batches lifecycle. Five structural tests in
  `ClaudeMessagingBatchesExampleTest` cover the build helper shape,
  Haiku/maxTokens choice, JSON wire round-trip, and selector
  presence.
- **Batches API** (`Claude-Messaging-Batches`): the Anthropic Message
  Batches surface for async submission and JSONL results retrieval.
  - `ClaudeClient` extension methods (per ADR-42, in
    `*Claude-Messaging-Batches`): `createBatch:`, `getBatch:`,
    `listBatches`, `listBatches:`, `cancelBatch:`, `deleteBatch:`,
    `streamBatchResults:do:`, `pollBatch:untilEndedEvery:`. Private
    `newBatchHttpClient` injects the
    `message-batches-2024-09-24` beta header on every request.
  - 13 new production types: `ClaudeBatch`, `ClaudeBatchPage`,
    `ClaudeBatchRequest`, `ClaudeBatchCreateParams`,
    `ClaudeBatchListParams`, `ClaudeBatchRequestCounts`,
    `ClaudeDeletedBatch`, `ClaudeBatchResult` (polymorphic dispatch
    via `fromJson:`), four outcome subclasses
    (`ClaudeBatchSucceededResult`, `ClaudeBatchErroredResult`,
    `ClaudeBatchCanceledResult`, `ClaudeBatchExpiredResult`), and
    `ClaudeBatchErrorPayload`.
  - New error: `ClaudeBatchNotEndedError` (subclass of
    `ClaudeApiError`) raised by `streamBatchResults:do:` when the
    batch has not yet reached `processingStatus = 'ended'`.
  - `ClaudeBetaHeader >> messageBatches` catalog entry returning
    `'message-batches-2024-09-24'`. `allKnown` now lists 10 betas.
  - `ManifestClaudeMessagingBatches` declares `ClaudeBatch` a false
    positive for `ReExcessiveVariablesRule` — its 10 instance
    variables are wire-mandated by the Anthropic resource shape.

### Changed

- **BREAKING — `PharoKeyring` is now read-only.** It *resolves*
  (looks up) API keys the user has provisioned through the OS tools
  (`pass`/`secret-tool`/Keychain) and no longer stores or deletes
  them. Removed: `PharoKeyring>>store:account:secret:[label:]` and
  `delete:account:`, the backend `storeService:…`/`deleteService:…`
  protocol, and the now-orphaned `KeyringCommandError` and
  `PharoKeyringError` classes. Provisioning is the password tools'
  job, not this SDK's. This also removes the only path where a secret
  entered a shell command or error object (previously a cleartext-key
  leak vector via `KeyringCommandError`).

- `ClaudeMockServer >> validateRequest:forPath:` now matches the
  synchronous Messages endpoint via `endsWith: '/messages'` (and
  `endsWith: '/messages/count_tokens'`) instead of the prior
  `includesSubstring: 'messages'`. The previous predicate was
  overbroad: every Batches path (`/v1/messages/batches`,
  `/v1/messages/batches/{id}/results`, etc.) tripped the
  synchronous-Messages validator and rejected legitimate batch
  payloads with a 400.

- **BREAKING (consumer URL)**: Metacello baseline renamed from
  `ClaudeMessaging` to `ClaudeSDK`. Update consumer load expressions:

  ```smalltalk
  Metacello new
    baseline: 'ClaudeSDK';   "was: baseline: 'ClaudeMessaging'"
    repository: 'github://punt-labs/anthropic-sdk-pharo:v0.5.1/src';
    load.
  ```

  The repository URL stays at `github://punt-labs/anthropic-sdk-pharo`.
  v0.5.0 is the last release under the old name; v0.5.1 ships under the
  new name. The old name remains available via the `v0.5.0` git tag for
  backward compatibility. The on-disk class moves from
  `src/BaselineOfClaudeMessaging/` to `src/BaselineOfClaudeSDK/`.
  Rationale: the baseline now reads as the SDK (dual scope —
  Messaging + ManagedAgents), not just one of its families. See
  ADR-40/41/42 in `DESIGN.md`.

### Fixed

- **Metacello baseline load now resolves.**
  `BaselineOfClaudeSDK>>baseline:` and `>>projectClass` are now
  instance-side (they had been class-side), so a cold
  `Metacello new baseline: 'ClaudeSDK'; repository: '...'; load`
  finds the `<baseline>` pragma and loads. External consumers'
  cold loads previously failed with "No #baseline pragma found" —
  our CI loaded packages via `TonelReader` and never exercised
  `Metacello baseline:`, so the baseline path went untested.

- **`make lint` now lints class-side methods and method-level rules.**
  The Makefile gate had been calling `(ReCriticEngine critiquesOf:
  cls)` once per class, which evaluates only class-level rules on
  the instance side and silently skips every method-level rule on
  every method on either side. The fix walks `{ cls. cls class }`
  and within each side calls both `critiquesOf:` (class-level rules)
  AND `m critiques` per method (method-level rules, the actual gap).
  The bug had existed since the Makefile was extracted from
  `claude-agent-sdk-smalltalk`; the fix surfaced 104 previously-
  hidden findings, all of which are cleared in this PR. The
  spurious `Error: is the server running? (make start)` tail line
  on clean lint output was also a Makefile bug — `grep -v` exits 1
  on empty match and propagated through the pipeline; appending
  `|| true` to the second grep and removing the trailing fallback
  echo restores correct exit semantics.

### Security

- **Pharo image downloaded over HTTPS** (was plaintext HTTP) in the
  Makefile `setup` and `check-baseline` image fetches, preventing
  image substitution via a network MITM. Checksum pinning is not
  feasible — upstream serves a rolling image per version with no
  published digest — so HTTPS provides the transport authenticity.

## [0.5.0] - 2026-04-25

### Added

- **Typed beta-header catalog** (`ClaudeBetaHeader`). Replaces raw string
  beta-header manipulation with a typed enumeration covering MCP client,
  prompt tools, skills, and other beta features.
- **Skills API** — upload, list, retrieve, and delete reusable tool
  packages via `ClaudeClient`. Types in `Claude-Messaging-Skills`:
  `ClaudeSkill`, `ClaudeSkillVersion`, `ClaudeDeletedSkill`,
  `ClaudeDeletedSkillVersion`, `ClaudeSkillPage`,
  `ClaudeSkillVersionPage`, `ClaudeSkillListParams`,
  `ClaudeSkillVersionListParams`.
- **MCP connector** — request-side MCP server definitions and tool
  configurations in `Claude-Messaging-MCP`
  (`ClaudeMCPServerDefinition`, `ClaudeMCPToolConfiguration`). Response
  content blocks (`ClaudeMCPToolUseBlock`,
  `ClaudeMCPToolResultBlock`) live in `Claude-Messaging-Types`.
- **Files API** — upload, list, download, delete in
  `Claude-Messaging-Files` (`ClaudeFileMetadata`, `ClaudeFilePage`,
  `ClaudeDeletedFile`, `ClaudeFileListParams`).
- **ClaudeImageBlock URL-casing alias** — accept both `url:` and `URL:`
  selectors; byte-size validation on inline image attachment.
- **ClaudeDocumentBlock URL-casing alias** — accept both `url:` and
  `URL:`; `tokensPerPageRange` accessor for page-budgeting.
- **Typed citations toggle** on `ClaudeDocumentBlock`.
  `enableCitations`/`disableCitations` control the `citations` slot;
  `disableCitations` clears it entirely (ADR-39).
- **Live-integration CI workflow** (`.github/workflows/slow-suite.yml`).
  Label-gated nightly run of the full Messaging suite against the real
  Anthropic API.
- **ClaudeAbstractTestSuite + ClaudeMessagingTestSuite** — per-product
  test suite factory (ADR-36). `ClaudeAbstractTestSuite` holds the
  shared filter machinery; `ClaudeMessagingTestSuite` aggregates the 9
  Messaging test packages plus `PharoKeyring-Tests`. `make test` runs
  the Messaging suite only.

### Changed

- **Uniform `ClaudeMessage`** — every message is an instance of
  `ClaudeMessage`, never a raw `Dictionary`. Content blocks are typed
  (`ClaudeContentBlock` hierarchy), not dictionary payloads (ADR-32).
- **`ClaudeMessageParams` renamed to `ClaudeMessageRequest`** —
  consistent with the Messages API wire name and the Go SDK's
  `MessageRequest` type (ADR-33).
- **`ClaudeImageBlock fromForm:`** — a live Pharo `Form` can be attached
  directly as an image block; the SDK serializes it as a base64 PNG
  (ADR-34).
- **Retry budget bumped on `ClaudeClient`**; `Retry-After` clamping so
  server-suggested delays cannot exceed the configured cap.

### Fixed

- **`NetworkError` escaping `executeWithRetry:`** — TCP-level failures
  during a request body read now raise `ClaudeApiError` subclasses
  like HTTP-level failures, so a single retry path handles both.
- **Skills upload wire format** — corrected multipart boundary
  assembly for skill package uploads.
- **`ClaudeMessage>>textContent` and `toolUseBlocks` nil-guard** —
  returns empty string / empty collection for messages with no content
  blocks, instead of raising `DoesNotUnderstand`.
- **`ClaudeApiError fromSseErrorData:`** — correctly dispatches SSE
  error events to the right `ClaudeApiError` subclass based on
  `error.type`.
- **`isRetryable` nil-guard** on `ClaudeApiError` — treats absent
  `error.type` as non-retryable rather than raising.

### Documentation

- SDK specification (`docs/specifications/claude-sdk-specification.tex`)
  tracks the Skills API, MCP connector, files API, beta-header
  catalog, and streaming semantics.
- Pharo implementation notes
  (`docs/specifications/claude-sdk-specification-pharo-notes.tex`)
  cover LF/CR normalization, STONJSON conventions, and the Metacello
  baseline.
- Cascade-yourself audit of the SDK specification
  (completeness review vs the live Go SDK).

### Project

- Initial extraction from `claude-agent-sdk-smalltalk@74b77d2`. This
  repo ships the Claude SDK for Pharo as a standalone product; the
  Agent SDK, Agent Workbench, and Pharo Agent Bridge remain in the
  `claude-agent-sdk-smalltalk` repo.
- Ethos mission adoption — all delegation via ethos mission
  contracts with typed write-sets, success criteria, budgets, and
  evaluators.
