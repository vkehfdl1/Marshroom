# Marshroom PRD Gap Analysis

## Current State Summary

### Architecture
- **App**: macOS SwiftUI + AppKit, MenuBarExtra for system tray
- **Pattern**: `@Observable` (not ObservableObject), `@Environment(AppStateManager.self)`
- **API**: `actor GitHubAPIClient` with async/await
- **Bridge**: `~/.config/marshroom/state.json` (v2, atomic writes)
- **Scenes**: WindowGroup (main), Settings, MenuBarExtra

### Current Models
| Model | Purpose |
|-------|---------|
| `GitHubIssue` | GitHub issue with branchName computed property |
| `GitHubRepo` | Repository with clone/SSH URLs |
| `CartItem` | Pairs repo + issue, ID = `"repo#number"` |
| `MarshroomState` | Bridge state (v2): cart entries + repo entries |
| `GitHubLabel` | Label model |
| `GitHubUser` | User model (login, name, avatarURL) |

### Current Views
| View | Location | Purpose |
|------|----------|---------|
| `MarshroomApp` | App/ | Entry point, WindowGroup + Settings + MenuBarExtra |
| `AppDelegate` | App/ | Lifecycle, polling start, cart restore |
| `MallView` | Features/Mall/ | 3-column NavigationSplitView (repos → issues → detail+cart) |
| `RepoListView` | Features/Mall/ | Sidebar: list of pinned repos |
| `IssueListView` | Features/Mall/ | Middle column: issues for selected repo |
| `IssueRowView` | Features/Mall/ | Single issue row |
| `IssueDetailView` | Features/Mall/ | Issue detail panel |
| `CartView` | Features/Mall/ | Cart panel (bottom of detail column) |
| `CartItemView` | Features/Mall/ | Single cart item row |
| `MenuBarView` | Features/Pilot/ | Menu bar popup: today's issues |
| `OnboardingView` | Features/Onboarding/ | Onboarding flow |
| `PATInputView` | Features/Onboarding/ | PAT entry |
| `RepoSearchView` | Features/Onboarding/ | Repo search during onboarding |
| `SkillSetupView` | Features/Onboarding/ | Skill installation guide |
| `SettingsWindow` | Features/Settings/ | Settings TabView |
| `GeneralSettingsView` | Features/Settings/ | General settings |
| `RepoSettingsView` | Features/Settings/ | Repo management settings |

### Current Claude Code Skills
| Skill | Function |
|-------|----------|
| `start-issue.md` | Read state.json, match repo, create branch |
| `create-pr.md` | Create PR with `Closes #N`, verify |
| `validate-pr.md` | Validate PR conventions |

### Current GitHub API Endpoints
- `GET /user` — validate token
- `GET /search/repositories` — search repos
- `GET /repos/{owner}/{repo}/issues` — list issues (paginated)
- `GET /repos/{owner}/{repo}/issues/{number}` — get single issue

---

## PRD Requirements vs. Current State

### 3.1 Issue Mall (Multi-Repo View)

| Requirement | Current State | Gap |
|-------------|---------------|-----|
| Multi-repo view (all repos in one screen) | Repos viewed one at a time via sidebar selection | **MAJOR**: Need unified multi-repo issue view |
| Smart Ingestion (LLM title generation) | Not present | **NEW**: Need LLM integration for title optimization from raw input |
| CLAUDE.md context for title generation | Not present | **NEW**: Need to read project CLAUDE.md files |
| Issue creation from app | Not present | **NEW**: Need `POST /repos/{owner}/{repo}/issues` API |
| Status Pipeline: Soon→Running→Pending→Completed | Only "cart" (≈ Soon) | **MAJOR**: Need issue status state machine, status tracking |
| Cmd+Enter to submit issue | Not present | **NEW**: Need keyboard shortcut for quick issue creation |

### 3.2 Terminal HUD

| Requirement | Current State | Gap |
|-------------|---------------|-----|
| Floating overlay window | Not present | **NEW**: Need NSPanel/NSWindow overlay |
| Terminal pwd detection | Not present | **NEW**: Need tmux session detection via AppleScript or CLI |
| Repo↔terminal context sync | Not present | **NEW**: Need pwd→repo matching logic |
| Focus Indicator (current stage) | Not present | **NEW**: Need stage display in HUD |
| Quick Actions (PyCharm, PR, Stop) | Not present | **NEW**: Need action buttons in HUD |

### 3.3 Claude Code Protocol

| Requirement | Current State | Gap |
|-------------|---------------|-----|
| `marsh start #123` with context injection | `start-issue.md` creates branch only | **ENHANCE**: Need CLAUDE.md + issue body injection |
| `context.json` update | Uses `state.json` | **CLARIFY**: Is context.json a new file or rename of state.json? |
| Pre-flight `Closes #N` check | `create-pr.md` already does this | **DONE** (minor enhancement possible) |
| AI plugin packaging (npx add) | Not present | **NEW**: Need npm package structure |

### 3.4 Review Bridge (PyCharm)

| Requirement | Current State | Gap |
|-------------|---------------|-----|
| Open PyCharm from HUD | Not present | **NEW**: Need PyCharm detection + launch |
| Focus on Diff/Local Changes | Not present | **NEW**: Need PyCharm CLI args for diff view |

---

## New Components Needed

### Models
- `IssueStatus` enum: `.soon`, `.running`, `.pending`, `.completed`
- `IssuePipelineItem`: wraps GitHubIssue with status tracking
- Enhanced `MarshroomState` v3: add status per cart entry, context fields

### Views
- `UnifiedIssueView`: multi-repo issue display with status pipeline
- `IssueComposerView`: smart ingestion — raw input + LLM title generation
- `HUDWindow`: floating overlay (NSPanel subclass)
- `HUDContentView`: SwiftUI content for HUD
- `PipelineFilterView`: filter by status stage

### Services
- `TerminalSessionDetector`: tmux pwd detection
- `LLMService`: title generation (which LLM? local or API?)
- `PyCharmLauncher`: detect and launch PyCharm
- `IssueCreationService`: GitHub issue creation API

### Claude Code
- Enhanced `start-issue.md` → `marsh-start` with CLAUDE.md injection
- AI plugin package structure (package.json, etc.)
- `context.json` management

### Infrastructure
- `MarshroomState` v3 schema migration
- HUD window lifecycle management
- Terminal session polling

---

## Open Questions for PM

1. **LLM for Smart Ingestion**: Which LLM API? (Claude API, OpenAI, local model?) User's API key or built-in?
2. **HUD Implementation**: NSPanel (floating, non-activating) vs. regular NSWindow? Always visible or toggle?
3. **Status Pipeline source of truth**: Derive status from GitHub (labels? PR state?) or track locally?
4. **context.json vs state.json**: Is `context.json` in the PRD a new file or a rename of `state.json`?
5. **Terminal Detection**: tmux-only? What about iTerm2, Terminal.app, Warp?
6. **Multi-Repo unified view**: Replace current 3-column layout or add a new view mode?
7. **AI Plugin format**: npm package? What's the `npx add` target? MCP server?
8. **PyCharm detection**: CLI launcher (`charm` or `pycharm`) detection method?
9. **Issue creation scope**: Create issues in any registered repo or only the selected one?
10. **CLAUDE.md reading**: Read from repo clone path on disk? Or fetch from GitHub API?
