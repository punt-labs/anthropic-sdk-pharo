# Roadmap

The Claude SDK for Pharo follows semantic versioning with deliberate
small increments. Each minor release (v0.X.0) ships a major piece of
Anthropic API surface. v1.0.0 marks feature parity with the official
[anthropic-sdk-python](https://github.com/anthropics/anthropic-sdk-python).

## Released

### v0.5.0 / v0.5.1

Messages API plus Messages-adjacent resources. About half the surface
of `anthropic-sdk-python`. v0.5.1 renamed the Metacello baseline from
`ClaudeMessaging` to `ClaudeSDK` (see ADR-40/41/42).

- **Messages API**: `sendMessage:`, `streamMessage:do:`, `countTokens:`,
  multi-turn conversations, prompt caching, citations, extended
  thinking, interleaved thinking
- **Files API**: upload, list, get-metadata, download, delete
  (`files-api-2025-04-14` beta)
- **Skills API**: CRUD on reusable tool packages
  (`skills-2025-10-02` beta)
- **Server tools** (Anthropic-hosted): web search, bash, code
  execution, text editor, memory, computer use
- **MCP connectors** via the `mcp_servers` field on Messages requests
  (`mcp-client-2025-04-04` beta)
- **Typed model catalog**: opus47, opus46, opus45, sonnet46, sonnet45,
  haiku45, haiku35
- **Typed beta-header catalog** (`ClaudeBetaHeader`)
- **Typed response metadata** (rate-limit and service-tier)
- **Streaming**: SSE decoder plus raw TLS socket variants

### v0.6.0 / v0.6.1 — Batches API

Async Messages submission. Submit a batch of message requests, poll
for completion, retrieve results. Same request shape as Messages on a
different endpoint family.

- Package `Claude-Messaging-Batches` (`ClaudeBatch*` types plus
  `ClaudeClient` extension methods: `createBatch:`, `getBatch:`,
  `listBatches`, `cancelBatch:`, `deleteBatch:`,
  `streamBatchResults:do:`, `pollBatch:untilEndedEvery:`)
  (`message-batches-2024-09-24` beta)
- Polymorphic batch outcomes (`ClaudeBatchSucceededResult`,
  `ClaudeBatchErroredResult`, `ClaudeBatchCanceledResult`,
  `ClaudeBatchExpiredResult`)

### v0.7.0 — current — Keyring backends & baseline hardening

Keyring resolution and Metacello baseline consolidation. No new API
surface; hardens key handling and cold-load correctness.

- **`pass` keyring backend** (`LinuxPassToolBackend`): `PharoKeyring`
  resolves keys from the `pass`(1) password store on Linux, preferred
  over `secret-tool` when both are installed
- **Read-only `PharoKeyring`**: resolves keys the user provisioned via
  the OS tools; no longer stores or deletes them (removes the only
  cleartext-key leak vector)
- **Two-tier API-key resolution** in `ClaudeSDKExampleSupport
  resolveClient` (Pharo override then general key; env before keyring)
- **`ClaudeSDK` baseline** with a `make check-baseline` cold-load guard
  and CI `baseline` job
- 916 tests total (866 fast plus 50 live-API integration tests)

## Planned increments

Each minor release adds one major API surface. Order reflects
dependency: shared primitives before consumers.

### v0.7.1 — Sessions (beta)

Server-side stateful conversation primitive. Used standalone for
long-running chats and as a building block for Managed Agents.

Packages: `Claude-ManagedAgents-Sessions`,
`Claude-ManagedAgents-Sessions-Tests`. Adds extension methods on
`ClaudeClient` for `createSession:`, `getSession:`,
`listSessions:`, `deleteSession:`.

### v0.8.0 — Memory Stores (beta)

Persistent memory resource. Standalone for retrieval-augmented
workflows; consumed by Managed Agents.

Packages: `Claude-ManagedAgents-MemoryStores`,
`Claude-ManagedAgents-MemoryStores-Tests`. Adds extension methods
on `ClaudeClient` for `createMemoryStore:`, `getMemoryStore:`,
`listMemoryStores:`, `deleteMemoryStore:`.

### v0.9.0 — Agents (beta)

Managed Agents — the agentic runtime hosted by Anthropic.
Composes sessions, memory stores, skills, and tools. Depends on v0.7.1
and v0.8.0 having shipped.

Packages: `Claude-ManagedAgents-Agents`,
`Claude-ManagedAgents-Agents-Tests`. Adds extension methods on
`ClaudeClient` for `createAgent:`, `getAgent:`, `listAgents:`,
`updateAgent:`, `deleteAgent:`, plus the agent-run lifecycle
methods.

### v0.10.0 — Environments (beta)

Execution environments for Managed Agents: sandbox configuration,
container settings, network policy.

Packages: `Claude-ManagedAgents-Environments`,
`Claude-ManagedAgents-Environments-Tests`. Adds extension methods
on `ClaudeClient` for `createEnvironment:`, `getEnvironment:`,
`listEnvironments:`, `deleteEnvironment:`.

### v0.11.0 — User Profiles + Vaults (beta)

`user_profiles` (per-user identity for agents) and `vaults` (secret
storage). Smaller resources paired into one release.

Packages: `Claude-ManagedAgents-UserProfiles`,
`Claude-ManagedAgents-UserProfiles-Tests`,
`Claude-ManagedAgents-Vaults`,
`Claude-ManagedAgents-Vaults-Tests`. Adds extension methods on
`ClaudeClient` for the `userProfile` and `vault` CRUD selectors.

## v1.0.0

Feature parity with `anthropic-sdk-python`. All beta resources above
shipped. Stability promise: no breaking changes within v1.x unless
Anthropic deprecates the underlying endpoint.

## Out-of-line work (no minor bump)

Patch releases (v0.X.Y) cover:

- Bug fixes
- Performance and throughput
- Pharo-native ergonomics (typed accessors, content-block hierarchy
  refinements)
- Documentation
- Test coverage
- CI tooling

Major non-API additions — for example, a Workbench split-off or
high-level agentic conveniences not in `anthropic-sdk-python` — are
considered for inclusion via separate ADRs.
