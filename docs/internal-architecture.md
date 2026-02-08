# Marshroom Internal Architecture

> Internal reference for contributors and AI agents working on the Marshroom codebase.

## 1. System Overview

Marshroom is a macOS developer productivity tool that uses **GitHub Issues as the Single Source of Truth (SSOT)**. It manages a cart of issues via `state.json` and orchestrates work across three pillars:

```
                          ┌──────────────────────┐
                          │      GitHub API       │
                          │   (Issues, Repos,     │
                          │    Files)              │
                          └──────────┬─────────────┘
                                     │
                    ┌────────────────┼────────────────┐
                    │                │                │
              ┌─────▼──────┐  ┌─────▼──────┐  ┌─────▼──────┐
              │  macOS App  │  │  CLI Tool  │  │Claude Code │
              │  (SwiftUI)  │  │  (marsh)   │  │  Skills    │
              └─────┬──────┘  └─────┬──────┘  └─────┬──────┘
                    │               │               │
                    └───────────────┼───────────────┘
                                    │
                          ┌─────────▼─────────┐
                          │   state.json      │
                          │ ~/.config/marshroom│
                          └───────────────────┘
```

### The Three Pillars

| Pillar | Role | Technology |
|--------|------|-----------|
| **macOS App** | GUI for browsing repos, managing cart, creating issues, monitoring status | SwiftUI + AppKit, `@Observable`, `actor`-based API clients |
| **CLI Tool (`marsh`)** | Terminal-side status updates, tmux HUD integration, IDE launching | Bash script, `jq` for JSON parsing |
| **Claude Code Skills** | AI agent integration — branch creation, PR workflow, context injection | `.claude/commands/` markdown instructions + Vercel Agent Skills package |

### The GOAT Flow (Five-Stage Pipeline)

```
Draft → Inject → Execute → Review → Ship
(soon)  (running)          (pending) (completed)
```

1. **Draft** — User picks issues in the macOS app (adds to cart via state.json)
2. **Inject** — `/start-issue` creates a branch, injects context, sets status to `running`
3. **Execute** — Developer/AI works on the issue with full context
4. **Review** — `/create-pr` creates PR with `Closes #N`, sets status to `pending`
5. **Ship** — PR merged, poller detects closure, marks `completed`, removes from cart

---

## 2. Data Flow

### 2.1 Primary Data Flow

```
GitHub API
    │
    ├──[GET issues]──→ macOS App (GitHubAPIClient)
    │                      │
    │                      ├──[user adds to cart]──→ AppStateManager.todayCart
    │                      │                              │
    │                      │                      StateFileManager.writeState()
    │                      │                              │
    │                      │                        state.json (atomic write)
    │                      │                         /          \
    │                      │                        /            \
    │                      │                  marsh CLI      Claude Code Skills
    │                      │                  (reads)         (reads)
    │                      │                       \            /
    │                      │                   [marsh start]  [/start-issue]
    │                      │                         \        /
    │                      │                      state.json (updated)
    │                      │
    ├──[POST issues]──← macOS App (IssueComposerView → AnthropicClient → GitHubAPIClient)
    │
    └──[GET issues]──→ GitHubPoller (periodic refresh)
                            │
                       [detects closure] → status=completed → remove from cart
```

### 2.2 state.json as the Bridge

`state.json` at `~/.config/marshroom/state.json` is the **sole communication channel** between all three pillars. Each pillar's relationship:

| Component | Reads | Writes |
|-----------|-------|--------|
| macOS App (`StateFileManager`) | On launch (cart restore), on poll cycle | On every cart change (`syncStateFile()`) |
| `marsh` CLI | Every command invocation | `marsh start` (status → running), `marsh pr` (status → pending, PR info) |
| Claude Code Skills | `/start-issue`, `/create-pr`, `/validate-pr` | Indirectly via `marsh` CLI calls |

### 2.3 Atomic Write Strategy

Both the macOS app and the CLI use atomic writes to prevent corruption from concurrent access:

**macOS App (Swift):**
```swift
// StateFileManager.writeState()
try data.write(to: url, options: .atomic)
// Writes to temp file first, then atomically moves to target path
```

**CLI (Bash):**
```bash
# write_state()
tmp="$(mktemp "${STATE_FILE}.XXXXXX")"
cat > "$tmp"
mv -f "$tmp" "$STATE_FILE"
# mktemp + mv pattern ensures atomic replacement
```

### 2.4 Polling Cycle

`GitHubPoller` runs on `@MainActor` with a configurable interval (default 30s, range 10–120s):

```
pollLoop() ─[sleep interval]─→ pollRepos()
    ↑                              │
    │                              ├── For each cart item:
    │                              │   └── GET /repos/{owner}/{repo}/issues/{number}
    │                              │       ├── closed? → status=completed → remove after 3s
    │                              │       └── open? → update cached issue data
    │                              │
    │                              ├── For each highlight repo:
    │                              │   └── CLAUDE.md cache stale? → refresh via GitHub API
    │                              │
    │                              └── syncStateFile() if changes detected
    │
    └──────────────────────────────┘
```

Rate limit check: polling skips if `rateLimitRemaining < 100`, pauses entirely at 0.

---

## 3. macOS App Architecture

### 3.1 App Entry Point and Scene Hierarchy

```swift
// MarshroomApp.swift
@main struct MarshroomApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appState = AppStateManager()

    var body: some Scene {
        WindowGroup { ... }          // Main window (MallView or OnboardingView)
            .windowStyle(.titleBar)
            .defaultSize(width: 1000, height: 700)
        Settings { SettingsWindow() } // Preferences (Cmd+,)
        MenuBarExtra { MenuBarView() } // System tray (leaf icon)
            .menuBarExtraStyle(.window)
    }
}
```

Three scenes:
- **WindowGroup** — Main app window. Shows `OnboardingView` or `MallView` based on `appState.isOnboarded`.
- **Settings** — macOS preferences window (`SettingsWindow` with TabView).
- **MenuBarExtra** — System tray popup with today's cart items.

### 3.2 AppDelegate Lifecycle

```
applicationDidFinishLaunching → (waits for appState via .onAppear)
                                    │
appState didSet ──→ onAppStateReady()
                        │
                        ├── restoreHighlightRepos()
                        ├── restoreCartFromStateFile()
                        └── Task {
                              restoreCurrentUser()
                              startPolling()
                            }

applicationWillTerminate → stopPolling()
applicationShouldTerminateAfterLastWindowClosed → false (keeps running for MenuBarExtra)
```

Note: `appState` is injected from `MarshroomApp.onAppear`, not available at `applicationDidFinishLaunching`.

### 3.3 @Observable Pattern (AppStateManager)

The app uses macOS 14+ `@Observable` macro (not `ObservableObject`/`@Published`). State is injected via `@Environment`:

```swift
@MainActor
@Observable
final class AppStateManager {
    var highlightRepos: [GitHubRepo] = []    // Pinned repos
    var todayCart: [CartItem] = []            // Cart items with status
    var isLoading = false
    var errorMessage: String?
    var currentUser: GitHubUser?
    var issuesByRepo: [String: [GitHubIssue]] = [:]  // Cache

    let settings: SettingsStorage
    private(set) var apiClient: GitHubAPIClient?
    private(set) var anthropicClient: AnthropicClient?
    private var poller: GitHubPoller?
    private var claudeMdCacheStore: [String: String] = [:]
}

// In views:
@Environment(AppStateManager.self) private var appState
```

### 3.4 View Hierarchy Tree

```
MarshroomApp
├── WindowGroup
│   ├── OnboardingView (if !isOnboarded)
│   │   ├── PATInputView (step 0)
│   │   ├── RepoSearchView (step 1)
│   │   │   └── RepoSearchRow (shared)
│   │   └── SkillSetupView (step 2)
│   │
│   └── MallView (if isOnboarded)
│       └── NavigationSplitView (.balanced)
│           ├── sidebar: RepoListView
│           │   └── [+ button] → AddRepoSheet → RepoSearchRow (shared)
│           ├── content: IssueListView
│           │   ├── IssueComposerView (collapsible, toolbar toggle)
│           │   └── ForEach → IssueRowView
│           └── detail: VStack
│               ├── IssueDetailView (top, scrollable)
│               │   └── FlowLayout (labels)
│               └── CartView (bottom, fixed 250pt)
│                   └── Sections: Running → Pending → Soon
│                       └── CartItemView
│
├── Settings
│   └── SettingsWindow (TabView)
│       ├── GeneralSettingsView (auth, polling interval)
│       ├── RepoSettingsView (manage pinned repos)
│       └── AISettingsView (Anthropic API key)
│
└── MenuBarExtra (.window style)
    └── MenuBarView
        └── ForEach → MenuBarIssueRow
```

### 3.5 Service Layer

#### GitHubAPIClient (`actor`)

Thread-safe GitHub API client with rate limit tracking.

```swift
actor GitHubAPIClient {
    private let session: URLSession
    private var pat: String
    private(set) var rateLimitRemaining: Int = 5000
    private(set) var rateLimitReset: Date = .distantFuture
}
```

**Endpoints:**

| Method | Endpoint | Purpose |
|--------|----------|---------|
| `validateToken()` | `GET /user` | Validate PAT, return user info |
| `searchRepos(query:)` | `GET /search/repositories` | Search repos during onboarding/add |
| `fetchIssues(repo:state:page:)` | `GET /repos/{owner}/{repo}/issues` | List issues (paginated, 30/page) |
| `getIssue(repo:number:)` | `GET /repos/{owner}/{repo}/issues/{number}` | Single issue (for polling) |
| `createIssue(repo:title:body:)` | `POST /repos/{owner}/{repo}/issues` | Create issue from composer |
| `fetchFileContent(repo:path:)` | `GET /repos/{owner}/{repo}/contents/{path}` | Fetch CLAUDE.md (base64 decoded) |
All requests include:
- `Authorization: Bearer {pat}`
- `Accept: application/vnd.github+json`
- `X-GitHub-Api-Version: 2022-11-28`

#### AnthropicClient (`actor`)

Thread-safe Anthropic API client for Smart Ingestion.

```swift
actor AnthropicClient {
    func generateTitle(rawInput:, claudeMd:, repoName:) async throws -> String
    func testConnection() async throws -> Bool
}
```

- Model: `claude-haiku-4-5-20251001` (fast, low-cost)
- System prompt: "You are a GitHub issue title generator..."
- User message: raw input + repo name + optional CLAUDE.md context
- Max tokens: 100 (title only)
- Headers: `x-api-key`, `anthropic-version: 2023-06-01`

#### GitHubPoller (`@MainActor`)

Periodic poller that refreshes cart item data and CLAUDE.md caches.

```swift
@MainActor
final class GitHubPoller {
    private weak var stateManager: AppStateManager?
    private var pollingTask: Task<Void, Never>?
}
```

- Holds a **weak** reference to `AppStateManager` to prevent retain cycles.
- Cancellable via `pollingTask.cancel()`.
- Polls each cart item individually with `getIssue()`.
- Detects closed issues → marks completed → removes after 3-second delay.

#### KeychainService (`enum`, static methods)

Two separate Keychain entries:

| Purpose | Service ID | Account ID |
|---------|-----------|------------|
| GitHub PAT | `com.marshroom.github-pat` | `github-personal-access-token` |
| Anthropic API Key | `com.marshroom.anthropic-key` | `anthropic-api-key` |

Uses `kSecAttrAccessibleWhenUnlocked` for both. Operations: save, load, delete.

### 3.6 State Persistence

| Storage | Mechanism | Data |
|---------|-----------|------|
| **Keychain** | `KeychainService` (Security framework) | GitHub PAT, Anthropic API key |
| **UserDefaults** | `SettingsStorage` (`@Observable`) | Polling interval, pinned repo names, onboarding flag, selected repo, highlight repos (JSON-encoded) |
| **state.json** | `StateFileManager` (file system) | Cart entries, repo entries, CLAUDE.md cache |

---

## 4. State Management

### 4.1 state.json v3 Schema

```json
{
  "version": 3,
  "updatedAt": "2025-02-08T12:00:00Z",
  "cart": [
    {
      "repoFullName": "owner/repo",
      "repoCloneURL": "https://github.com/owner/repo.git",
      "repoSSHURL": "git@github.com:owner/repo.git",
      "issueNumber": 123,
      "issueTitle": "Add dark mode",
      "branchName": "Feature/#123",
      "status": "soon",
      "issueBody": "Full issue description...",
      "prNumber": null,
      "prURL": null
    }
  ],
  "repos": [
    {
      "fullName": "owner/repo",
      "cloneURL": "https://github.com/owner/repo.git",
      "sshURL": "git@github.com:owner/repo.git",
      "claudeMdCache": "# Project\n...",
      "claudeMdCachedAt": "2025-02-08T12:00:00Z",
      "localPath": "/Users/dev/projects/repo"
    }
  ]
}
```

#### CartEntry Fields

| Field | Type | Description |
|-------|------|-------------|
| `repoFullName` | `string` | `owner/repo` format |
| `repoCloneURL` | `string` | HTTPS clone URL |
| `repoSSHURL` | `string` | SSH clone URL |
| `issueNumber` | `int` | GitHub issue number |
| `issueTitle` | `string` | Issue title text |
| `branchName` | `string` | `Feature/#N` or `HotFix/#N` |
| `status` | `string` | `soon` \| `running` \| `pending` \| `completed` |
| `issueBody` | `string?` | Full issue body (nullable) |
| `prNumber` | `int?` | PR number after creation (nullable) |
| `prURL` | `string?` | PR URL after creation (nullable) |

#### RepoEntry Fields

| Field | Type | Description |
|-------|------|-------------|
| `fullName` | `string` | `owner/repo` format |
| `cloneURL` | `string` | HTTPS clone URL |
| `sshURL` | `string` | SSH clone URL |
| `claudeMdCache` | `string?` | Cached CLAUDE.md content (nullable) |
| `claudeMdCachedAt` | `string?` | ISO 8601 cache timestamp (nullable) |
| `localPath` | `string?` | Local filesystem path (nullable) |

### 4.2 Status State Machine

```
                ┌────────────────────────────────────────────┐
                │                                            │
  [Add to cart] │                                            │
       │        │                                            │
       ▼        │                                            │
    ┌──────┐   │   ┌─────────┐       ┌─────────┐       ┌──────────┐
    │ soon │───┼──→│ running │──────→│ pending │──────→│completed │
    └──────┘   │   └─────────┘       └─────────┘       └──────────┘
               │        │                 │                  │
               │   set by:           set by:            set by:
               │   - marsh start     - marsh pr         - GitHubPoller
               │   - /start-issue    - /create-pr         (detects closure)
               │                                            │
               │                                     [removed from cart
               │                                      after 3s delay]
               └────────────────────────────────────────────┘
```

Only **forward transitions** are expected. Backward transitions (e.g., PR rejected) require manual intervention.

### 4.3 Branch Name Convention

Derived from `GitHubIssue.branchName` computed property:

```swift
var branchName: String {
    let lowered = title.lowercased()
    let hotfixKeywords = ["bug", "fix", "hotfix"]
    let isHotfix = hotfixKeywords.contains { lowered.contains($0) }
    return isHotfix ? "HotFix/#\(number)" : "Feature/#\(number)"
}
```

- Title contains `bug`, `fix`, or `hotfix` (case-insensitive) → `HotFix/#N`
- Otherwise → `Feature/#N`

### 4.4 StateFileManager

`StateFileManager` is an `enum` with static methods (no instances):

```swift
enum StateFileManager {
    static func readState() -> MarshroomState?       // Decode from disk
    static func writeState(_ state: MarshroomState)  // Atomic write, sets version=3 + updatedAt
    static func buildState(cart:repos:existingState:) // Build from in-memory objects
}
```

**`buildState` preserves existing repo-level cache data** (CLAUDE.md cache, timestamps, localPath) when rebuilding state from `AppStateManager`.

**Backward compatibility**: Custom `init(from:)` on `CartEntry` and `RepoEntry` uses `decodeIfPresent` for v3 fields, defaulting `status` to `.soon` and nullable fields to `nil`.

---

## 5. Smart Ingestion Pipeline

The Smart Ingestion pipeline converts raw developer thoughts into well-titled GitHub issues.

```
┌────────────────────┐
│ IssueComposerView  │  User types raw idea: "dark mode pls"
│ (TextEditor)       │
└────────┬───────────┘
         │
         ▼
┌────────────────────┐
│ AppStateManager    │  .generateIssueTitle(rawInput:, repo:)
│                    │
│ claudeMdCache(for:)│  Lookup cached CLAUDE.md for project context
└────────┬───────────┘
         │
         ▼
┌────────────────────┐
│ AnthropicClient    │  POST /v1/messages
│ (actor)            │  model: claude-haiku-4-5-20251001
│                    │  system: "You are a GitHub issue title generator..."
│                    │  user: raw input + repo name + CLAUDE.md context
│                    │  max_tokens: 100
└────────┬───────────┘
         │
         ▼
┌────────────────────┐
│ Generated Title    │  "Add dark mode support with system preference detection"
│ (editable)         │  User can edit before creating
└────────┬───────────┘
         │ [Create Issue]
         ▼
┌────────────────────┐
│ GitHubAPIClient    │  POST /repos/{owner}/{repo}/issues
│ (actor)            │  title: generated/edited title
│                    │  body: original raw input
└────────┬───────────┘
         │
         ▼
┌────────────────────┐
│ Issue Created      │  Refresh issue list for the repo
└────────────────────┘
```

### CLAUDE.md Cache Lifecycle

1. **Fetch**: `GitHubAPIClient.fetchFileContent(repo:, path: "CLAUDE.md")` — fetches from GitHub Contents API, base64-decodes.
2. **Store**: Cached in `AppStateManager.claudeMdCacheStore` (in-memory `[String: String]`) and persisted to `state.json` via `RepoEntry.claudeMdCache`.
3. **Restore**: On app launch, `restoreCartFromStateFile()` populates the in-memory cache from `state.json`.
4. **Refresh**: `GitHubPoller` checks staleness against `Constants.claudeMdCacheTTLSeconds` (3600s = 1 hour). If stale, re-fetches from GitHub API.
5. **Consume**: `IssueComposerView` and `/start-issue` skill read the cached content for context injection.

---

## 6. CLI Tool Architecture (`marsh`)

### 6.1 Overview

`marsh` is a standalone Bash script at `cli/marsh`. It requires `jq` for JSON parsing and reads/writes `~/.config/marshroom/state.json`.

### 6.2 Command Dispatch

```bash
case "${1:-help}" in
  hud)      cmd_hud ;;
  start)    shift; cmd_start "${1:-}" ;;
  status)   cmd_status ;;
  open-ide) cmd_open_ide ;;
  pr)       cmd_pr ;;
  help|--help|-h) cmd_help ;;
  *)        echo "Unknown command: $1" >&2; exit 1 ;;
esac
```

### 6.3 Repo Detection Logic

All commands that need repo context follow this pattern:

```
pwd → git remote get-url origin → extract_owner_repo() → match against state.json
```

```bash
extract_owner_repo() {
  echo "$url" | sed -E 's#(https?://github\.com/|git@github\.com:)##; s#\.git$##'
}
```

Handles both HTTPS (`https://github.com/owner/repo.git`) and SSH (`git@github.com:owner/repo.git`) formats.

Cart entry matching uses a triple-OR jq filter against `repoFullName`, `repoCloneURL`, and `repoSSHURL`:

```jq
select(
  (.repoFullName // "") == $repo or
  ((.repoCloneURL // "") | gsub("https://github.com/"; "") | gsub("\\.git$"; "")) == $repo or
  ((.repoSSHURL // "")   | gsub("git@github.com:"; "")    | gsub("\\.git$"; "")) == $repo
)
```

### 6.4 Commands

| Command | Reads state | Writes state | Description |
|---------|-------------|--------------|-------------|
| `hud` | Yes | No | Output tmux-formatted status string. Prioritizes: running > soon > pending. Truncates title to 30 chars. |
| `start [#N]` | Yes | Yes (status→running) | Interactive pick if multiple entries. Strips leading `#` from argument. |
| `status` | Yes | No | Pretty-prints all cart entries for current repo. |
| `open-ide` | No | No | Tries PyCharm Professional → CE → PyCharm → `pycharm` CLI. |
| `pr` | Yes | Yes (status→pending, prNumber, prURL) | Matches by branch name. Uses `gh pr view` to capture PR info. |

### 6.5 Atomic Write Pattern

```bash
write_state() {
  local tmp
  tmp="$(mktemp "${STATE_FILE}.XXXXXX")"
  cat > "$tmp"
  mv -f "$tmp" "$STATE_FILE"
}

# Usage: pipe JSON through write_state
echo "$updated" | write_state
```

### 6.6 tmux Integration

Configuration file at `cli/tmux-marshroom.conf`:

```bash
# Status bar (refreshes every 5 seconds)
set -g status-right '#(marsh hud) | %H:%M '
set -g status-right-length 80
set -g status-interval 5

# Keybindings
bind-key P run-shell "marsh open-ide"       # prefix + P → open PyCharm
bind-key I display-popup -E "marsh status"  # prefix + I → status popup
```

HUD output format:
```
#[fg=green]🍄#[fg=default] #123 Add dark mode [Running] | owner/repo
```

Color mapping: soon=yellow, running=green, pending=blue, completed=colour244.

---

## 7. Claude Code Skills

### 7.1 Skill Locations

Skills exist in two identical forms:

| Location | Purpose |
|----------|---------|
| `.claude/commands/*.md` | Project-local skills (used by Claude Code in this repo) |
| `marshroom-skills/skills/*/SKILL.md` | Distributable Vercel Agent Skills package |

The content is identical; the package form allows installation via `npx skills add`.

### 7.2 Skill Lifecycle

Every skill follows the same initial pattern:

```
1. Read ~/.config/marshroom/state.json
2. Parse cart array
3. Detect current repo (git remote get-url origin)
4. Match cart entries by repo URL
5. Identify the target issue
6. Perform skill-specific actions
7. Optionally call marsh CLI for status updates
```

### 7.3 Skills Reference

#### `/start-issue [#N]`

**Purpose**: Begin work on a cart issue.

**Flow**:
1. Read state.json → filter cart by current repo
2. Select issue (by argument, or interactive pick)
3. `git checkout main && git pull origin main`
4. `git checkout -b {branchName}`
5. `marsh start #{issueNumber}` (status → running)
6. Inject CLAUDE.md context (from `repos[].claudeMdCache` or project root)
7. Inject issue body (from `cart[].issueBody`)
8. Output confirmation: issue, branch, repo, status

#### `/create-pr`

**Purpose**: Create a PR for the current branch's issue.

**Flow**:
1. Read state.json → match cart by current `git branch`
2. `git push -u origin HEAD`
3. Build PR body (description + original issue body + `Closes #N`)
4. `gh pr create --title "{issueTitle}" --body "{body}"`
5. Verify `Closes #N` in PR body (fix if missing)
6. Capture PR number/URL via `gh pr view`
7. `marsh pr` (status → pending)
8. Output: PR URL, PR number, issue, status

#### `/validate-pr`

**Purpose**: Validate PR against Marshroom conventions.

**Checks**:
1. **Branch name**: Must match `branchName` field (`Feature/#N` or `HotFix/#N`)
2. **PR body**: Must contain `Closes #{issueNumber}`
3. **Status**: Should be `pending` after PR creation

### 7.4 GOAT Flow Mapping to Skills

```
Draft (soon)     → [Marshroom App — add to cart]
Inject (running) → /start-issue
Execute          → [Developer/AI work]
Review (pending) → /create-pr
Ship (completed) → /validate-pr → [merge] → [poller detects → remove]
```

### 7.5 Vercel Agent Skills Package

```
marshroom-skills/
├── package.json                    # npm metadata, skill entry points
├── SKILL.md                        # Top-level skill description + GOAT flow
├── skills/
│   ├── start-issue/SKILL.md        # /start-issue instructions
│   ├── create-pr/SKILL.md          # /create-pr instructions
│   └── validate-pr/SKILL.md        # /validate-pr instructions
├── scripts/
│   └── install-skill.sh            # Installer script for project setup
├── references/
│   └── state-schema.md             # state.json v3 schema documentation
└── README.md                       # Installation + usage guide
```

`package.json` maps skill names to SKILL.md files:
```json
{
  "skills": {
    "start-issue": "skills/start-issue/SKILL.md",
    "create-pr": "skills/create-pr/SKILL.md",
    "validate-pr": "skills/validate-pr/SKILL.md"
  }
}
```

---

## 8. Component Dependency Map

### 8.1 macOS App Internal Dependencies

```
MarshroomApp
    └──→ AppStateManager (owns all state)
            ├──→ SettingsStorage (UserDefaults wrapper)
            ├──→ GitHubAPIClient (actor, GitHub REST API)
            ├──→ AnthropicClient (actor, Claude API)
            ├──→ GitHubPoller (periodic refresh, weak ref back to AppStateManager)
            ├──→ StateFileManager (static, reads/writes state.json)
            └──→ KeychainService (static, macOS Keychain)

AppDelegate
    └──→ AppStateManager (set via .onAppear from MarshroomApp)
```

### 8.2 Model Dependencies

```
CartItem
    ├── repo: GitHubRepo
    ├── issue: GitHubIssue
    └── status: IssueStatus

MarshroomState
    ├── CartEntry (serialized form of CartItem)
    └── RepoEntry (serialized repo + cache data)

GitHubIssue
    ├── labels: [GitHubLabel]
    ├── user: User
    ├── assignees: [User]
    └── pullRequest: PullRequestRef?
```

### 8.3 Cross-Pillar Dependencies

```
┌────────────────────────────────────────────────────────────────┐
│                    Shared Interfaces                            │
│                                                                │
│  state.json v3 schema ←── StateFileManager (Swift)             │
│       ↑        ↑          read_state/write_state (Bash)        │
│       │        │          SKILL.md instructions (read only)    │
│       │        │                                               │
│  Keychain  ←── KeychainService (Swift only)                    │
│  (PAT, Anthropic key)                                          │
│                                                                │
│  GitHub API ←── GitHubAPIClient (Swift)                        │
│       ↑         gh CLI (used by skills)                        │
│       │         marsh pr uses gh pr view                       │
│       │                                                        │
│  Git CLI  ←── Skills (git checkout, push)                      │
│       ↑        marsh (git remote, git branch)                  │
│       │                                                        │
│  marsh CLI ←── Skills call marsh start/pr                      │
│                (optional, graceful skip if not in PATH)         │
└────────────────────────────────────────────────────────────────┘
```

### 8.4 External Dependencies

| Dependency | Used By | Purpose |
|------------|---------|---------|
| GitHub REST API v3 | macOS App, Skills (via `gh`) | Issue CRUD, repo search, file content |
| Anthropic Messages API | macOS App (`AnthropicClient`) | Issue title generation (Claude Haiku) |
| `gh` CLI | Skills (`/create-pr`, `/validate-pr`) | PR creation, PR view/edit |
| `git` CLI | Skills, `marsh` CLI | Branch operations, remote detection |
| `jq` | `marsh` CLI | JSON parsing/manipulation |
| macOS Keychain | `KeychainService` | Secure credential storage |
| macOS UserDefaults | `SettingsStorage` | App preferences |
| tmux | `marsh hud` | Terminal status bar integration |

### 8.5 File System Layout

```
~/.config/marshroom/
└── state.json                  # Bridge file (v3 schema)

Marshroom/Marshroom/
├── App/
│   ├── MarshroomApp.swift      # @main entry point, 3 scenes
│   └── AppDelegate.swift       # Lifecycle, polling start
├── Core/
│   ├── AppStateManager.swift   # Central @Observable state
│   ├── Constants.swift         # URLs, intervals, formatters
│   ├── SettingsStorage.swift   # UserDefaults wrapper
│   └── StateFileManager.swift  # state.json read/write
├── Models/
│   ├── CartItem.swift          # Repo + Issue + Status
│   ├── GitHubIssue.swift       # Issue model + branchName
│   ├── GitHubLabel.swift       # Label model
│   ├── GitHubRepo.swift        # Repo model + search result
│   ├── IssueStatus.swift       # soon/running/pending/completed
│   └── MarshroomState.swift    # v3 state.json schema (Codable)
├── Services/
│   ├── AnthropicClient.swift   # Claude API (actor)
│   ├── GitHubAPIClient.swift   # GitHub API (actor) + error types
│   ├── GitHubPoller.swift      # Periodic refresh
│   └── KeychainService.swift   # Keychain CRUD
└── Features/
    ├── Mall/
    │   ├── MallView.swift          # 3-column NavigationSplitView
    │   ├── RepoListView.swift      # Sidebar: pinned repos
    │   ├── IssueListView.swift     # Middle: issue list + composer toggle
    │   ├── IssueRowView.swift      # Single issue row + cart button
    │   ├── IssueDetailView.swift   # Issue detail + FlowLayout
    │   ├── IssueComposerView.swift # Smart Ingestion UI
    │   ├── CartView.swift          # Cart panel (grouped by status)
    │   └── CartItemView.swift      # Single cart item with status badge
    ├── Pilot/
    │   └── MenuBarView.swift       # System tray popup
    ├── Onboarding/
    │   ├── OnboardingView.swift    # 3-step wizard
    │   ├── PATInputView.swift      # Step 0: PAT entry
    │   ├── RepoSearchView.swift    # Step 1: Repo selection
    │   └── SkillSetupView.swift    # Step 2: Skill installation
    └── Settings/
        ├── SettingsWindow.swift     # TabView container
        ├── GeneralSettingsView.swift # Auth + polling
        ├── RepoSettingsView.swift   # Repo management
        └── AISettingsView.swift     # Anthropic API key

cli/
├── marsh                       # CLI tool (Bash)
└── tmux-marshroom.conf         # tmux integration config

.claude/commands/
├── start-issue.md              # /start-issue skill
├── create-pr.md                # /create-pr skill
└── validate-pr.md              # /validate-pr skill

marshroom-skills/               # Vercel Agent Skills package
├── package.json
├── SKILL.md
├── skills/{start-issue,create-pr,validate-pr}/SKILL.md
├── references/state-schema.md
└── README.md
```
