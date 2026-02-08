# Marshroom

Multi-Repo Execution Catalyst — a macOS developer cockpit that uses GitHub Issues.
"Think at the speed of thought, ship at the speed of agents."

## Project Structure
```
Marshroom/              — Xcode app (SwiftUI + AppKit, macOS 14.0+)
cli/                    — marsh CLI tool (shell script) + tmux config
marshroom-skills/       — Vercel Agent Skills package (npx skills add)
Skills/                 — Skill installation utilities
.claude/commands/       — Claude Code skills (start-issue, create-pr, validate-pr)
docs/                   — Architecture & user documentation
```

## Tech Stack
- SwiftUI + AppKit (MenuBarExtra for system tray, WindowGroup for main)
- `@Observable` pattern (NOT ObservableObject) with `@Environment(AppStateManager.self)`
- `actor` based API clients: `GitHubAPIClient`, `AnthropicClient`
- async/await concurrency throughout
- Keychain: GitHub PAT + Anthropic API key (separate entries)
- UserDefaults: settings via `SettingsStorage`
- `~/.config/marshroom/state.json`: bridge between macOS app, CLI, and Claude Code skills

## Build
```bash
xcodebuild -project Marshroom/Marshroom.xcodeproj -scheme Marshroom -configuration Debug build CODE_SIGN_IDENTITY="-" CODE_SIGNING_ALLOWED=YES
```

## Three Pillars

### 1. macOS App (Marshroom/)
- **Issue Mall**: per-repo issue browsing, Smart Ingestion (LLM title generation via Claude API), issue creation
- **Cart + Status Pipeline**: issues flow through `soon → running → pending → completed`
- **Menu Bar**: quick view of today's cart items
- **Settings**: General, Repos, AI (Anthropic API key)

### 2. CLI Tool (cli/marsh)
- `marsh hud` — tmux status bar output (current repo/issue/status)
- `marsh start [#N]` — set cart item status to "running"
- `marsh status` — show cart items for current repo
- `marsh open-ide` — open PyCharm for current directory
- `marsh pr` — set status to "pending", store PR number/URL
- Reads/writes `~/.config/marshroom/state.json` atomically

### 3. Claude Code Skills (.claude/commands/)
- `/start-issue` — read state.json, create branch, inject CLAUDE.md + issue body context, call `marsh start`
- `/create-pr` — push, create PR with `Closes #N`, call `marsh pr`
- `/validate-pr` — verify branch name, PR body, and status

## Core Rules
- **No single active issue** — all cart items are equal (parallel work)
- **state.json v3**: CartEntry has `status`, `issueBody`, `prNumber`, `prURL`; RepoEntry has `claudeMdCache`
- **Atomic writes**: `Data.write(options: .atomic)` in Swift, `mktemp + mv` in shell — prevents race conditions
- **Branch naming**: title contains Bug/Fix/HotFix → `HotFix/#N`, else `Feature/#N`
- **Repo matching**: skills + CLI detect repo via `git remote get-url origin`, match against state.json URLs
- **Smart Ingestion**: raw idea → Claude Haiku generates optimized title → GitHub issue created
- **CLAUDE.md cache**: fetched via GitHub Contents API, cached in state.json RepoEntry, TTL 1 hour

## Status Pipeline
| Status | Meaning | Set By |
|--------|---------|--------|
| `soon` | In cart, not started | macOS app (add to cart) |
| `running` | Claude Code working | `marsh start` / start-issue skill |
| `pending` | PR created, awaiting review | `marsh pr` / create-pr skill |
| `completed` | Issue closed / PR merged | GitHubPoller (auto-detected) |

## The GOAT Flow
1. **Draft**: Type raw idea in Issue Composer → Cmd+Enter → LLM title → Create Issue
2. **Inject**: `/start-issue #123` → branch created, context loaded, status → running
3. **Execute**: Claude codes → tmux HUD shows `🍄 #123 [Running]`
4. **Review**: `Prefix+P` in tmux → PyCharm opens → review code
5. **Ship**: `/create-pr` → PR with `Closes #N` → merge → issue auto-closes

## Key Architecture Notes
- `AppStateManager` (@Observable, @MainActor) is the central state hub
- `GitHubAPIClient` (actor): /user, /repos, /issues, /issues/create, /contents (CLAUDE.md)
- `AnthropicClient` (actor): Claude Haiku for title generation
- `GitHubPoller` (@MainActor): polls cart items, detects status transitions, refreshes CLAUDE.md cache
- `StateFileManager` (enum): reads/writes state.json, handles v2→v3 migration
- `KeychainService` (enum): stores GitHub PAT and Anthropic API key separately

## Docs
- `docs/internal-architecture.md` — full technical architecture (for contributors + AI agents)
- `docs/user-guide.md` — installation, GOAT workflow, CLI reference, troubleshooting
- `docs/architecture-v2.md` — design decisions from PRD implementation
