# Marshroom v2 Architecture Design Document

## Decisions Summary (PM Clarifications)

| Area | Decision |
|------|----------|
| LLM for Smart Ingestion | Claude API (Anthropic) |
| Anthropic API Key | Separate key in Marshroom Settings, stored in Keychain |
| Status Pipeline | Track locally in state.json (v3 schema) |
| Terminal HUD | tmux status bar — standalone CLI tool (`marsh`) reads state.json |
| Mall Layout | Keep per-repo view (no unified "All Issues" tab) |
| JSON Bridge | Keep `state.json` name, upgrade to v3 schema |
| AI Plugin | Vercel Agent Skills format (`SKILL.md` + `scripts/` + `references/`) |
| CLAUDE.md Access | Fetch via GitHub API, cache locally |
| Issue Input | New inline composer panel at top of MallView issue list |
| PyCharm Launch | CLI command (`marsh open-ide`) + tmux keybinding (no Claude skill) |
| HUD Owner | Standalone CLI tool, decoupled from macOS app |

---

## 1. state.json v3 Schema

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
      "localPath": "/Users/jeffrey/projects/repo"
    }
  ]
}
```

### Status Values
- `"soon"` — In cart, not yet started (default when added to cart)
- `"running"` — Claude Code is actively working (set by `marsh start`)
- `"pending"` — PR created, awaiting review (set by `marsh pr` or `create-pr` skill)
- `"completed"` — Issue closed / PR merged (detected by poller, then removed from cart)

### Migration
- v2 → v3: Add `status` (default `"soon"`), `issueBody`, `prNumber`, `prURL` to CartEntry
- Add `claudeMdCache`, `claudeMdCachedAt`, `localPath` to RepoEntry
- `StateFileManager.readState()` handles both v2 and v3 for backward compat

---

## 2. macOS App Changes

### 2.1 Models

#### New: `IssueStatus` enum
```swift
enum IssueStatus: String, Codable, CaseIterable {
    case soon     // In cart, not started
    case running  // Claude working
    case pending  // PR created
    case completed // Done

    var displayName: String { ... }
    var iconName: String { ... }
    var color: Color { ... }
}
```

#### Updated: `MarshroomState.CartEntry`
Add fields: `status: IssueStatus`, `issueBody: String?`, `prNumber: Int?`, `prURL: String?`

#### Updated: `MarshroomState.RepoEntry`
Add fields: `claudeMdCache: String?`, `claudeMdCachedAt: String?`, `localPath: String?`

#### New: `AnthropicClient` (actor)
```swift
actor AnthropicClient {
    func generateTitle(rawInput: String, claudeMd: String?, repoContext: String) async throws -> String
}
```

### 2.2 Services

#### New: `AnthropicService`
- Reads API key from Keychain (separate from GitHub PAT)
- Calls Claude API (claude-haiku-4-5 for speed/cost) with:
  - System prompt: "Generate a concise GitHub issue title from rough input"
  - User message: raw input + CLAUDE.md context
- Returns: optimized title string

#### Updated: `GitHubAPIClient`
Add methods:
- `createIssue(repo:, title:, body:) async throws -> GitHubIssue` — POST /repos/{owner}/{repo}/issues
- `fetchFileContent(repo:, path:) async throws -> String` — GET /repos/{owner}/{repo}/contents/{path} (for CLAUDE.md)
- ~~`addLabel`~~ — removed (cart is managed locally via state.json)

#### Updated: `GitHubPoller`
- Detect PR creation for running issues → update status to `pending`
- Detect issue closure → update status to `completed`, then remove after delay
- Refresh CLAUDE.md cache if stale (> 1 hour)

### 2.3 Views

#### New: `IssueComposerView`
Location: `Features/Mall/IssueComposerView.swift`
- Inline panel at top of issue list (collapsible)
- TextEditor for raw idea input
- "Generate Title" button + Cmd+Enter shortcut
- Shows generated title with edit option
- "Create Issue" to submit to GitHub
- Uses AnthropicService + CLAUDE.md cache

#### Updated: `IssueListView`
- Add IssueComposerView at top
- Show status badge (soon/running/pending/completed) on issues that are in cart
- Filter/group by status pipeline stage (optional toggle)

#### Updated: `CartView`
- Group items by status: Soon → Running → Pending
- Color-coded status indicators
- Show PR link for pending items

#### Updated: `CartItemView`
- Add status badge with color
- Show PR number for pending items

#### New: `AnthropicSettingsView`
Location: `Features/Settings/AnthropicSettingsView.swift`
- Anthropic API key input (SecureField)
- Test connection button
- Model selection (optional, default haiku)

#### Updated: `SettingsWindow`
- Add new "AI" or "Smart Ingestion" tab for Anthropic settings

### 2.4 Core

#### Updated: `SettingsStorage`
- Add `anthropicAPIKey` (stored in Keychain via KeychainService)
- Add `claudeMdCacheTTLSeconds: Int` (default 3600)

#### Updated: `KeychainService`
- Add service/account for Anthropic API key (separate from GitHub PAT)

#### Updated: `Constants`
- Add `anthropicAPIBaseURL = "https://api.anthropic.com"`
- Add `claudeMdCacheTTLSeconds = 3600`
- Add `contextFilePath` if needed

---

## 3. CLI Tool: `marsh`

### Overview
A standalone Swift CLI (or shell script) that reads `~/.config/marshroom/state.json` and provides:
- `marsh hud` — outputs tmux status bar formatted string
- `marsh start [#N]` — updates cart entry status to `running`
- `marsh status` — shows current issue context for pwd
- `marsh open-ide` — opens PyCharm for current repo
- `marsh pr` — updates status to `pending` after PR creation

### 3.1 `marsh hud` (tmux status bar)

Reads state.json, detects current repo from `pwd` (match against repo clone/SSH URLs or localPath), outputs formatted tmux status string:

```
#[fg=green]🍄 #123 Add dark mode [Running] #[fg=default]| owner/repo
```

**tmux integration:**
```bash
# In .tmux.conf:
set -g status-right '#(marsh hud)'
set -g status-interval 5  # refresh every 5 seconds
```

**Logic:**
1. Get `pwd` from tmux pane (or current shell)
2. Run `git remote get-url origin` in that directory
3. Match against state.json repos
4. Find cart entries for that repo
5. Format and output status string

### 3.2 `marsh start [#N]`

1. Read state.json
2. Detect current repo from pwd + git remote
3. Find matching cart entry (by issue number or interactive pick)
4. Update cart entry status to `"running"` in state.json
5. Output confirmation

### 3.3 `marsh open-ide`

1. Detect current repo from pwd
2. Run `open -a "PyCharm" .` (or `pycharm .` if CLI launcher available)
3. Falls back to detecting PyCharm variants (PyCharm CE, PyCharm Professional)

### 3.4 `marsh status`

1. Read state.json
2. Match pwd to repo
3. Display: current issue(s), status, branch, PR link

### 3.5 `marsh pr`

1. Read state.json, match pwd to repo + branch to cart entry
2. Update status to `"pending"` in state.json
3. Optionally store PR number/URL if available

### Implementation Options
- **Option A: Swift CLI** — compiled binary, shares models with macOS app
- **Option B: Shell script** — simpler, uses `jq` for JSON parsing
- **Recommendation: Shell script** — easier to distribute, no compilation needed, works everywhere

---

## 4. Vercel Agent Skills Package

### Package Structure
```
marshroom-skills/
├── package.json           # npm package metadata
├── SKILL.md               # Main skill instructions
├── skills/
│   ├── start-issue/
│   │   ├── SKILL.md       # /start-issue instructions
│   │   └── scripts/
│   │       └── marsh      # CLI tool (copied or linked)
│   ├── create-pr/
│   │   ├── SKILL.md       # /create-pr instructions
│   │   └── scripts/
│   │       └── validate-pr.sh
│   └── validate-pr/
│       └── SKILL.md       # /validate-pr instructions
├── references/
│   └── state-schema.md    # state.json v3 schema reference
└── README.md
```

### Installation
```bash
npx skills add marshroom/marshroom-skills
```

This copies SKILL.md files to `.claude/commands/` (or wherever the agent skills system expects them).

### Enhanced Skills (v2)

#### `start-issue` (enhanced)
- Read state.json
- Match repo, create branch
- **NEW**: Inject CLAUDE.md context (from state.json cache or read from disk)
- **NEW**: Inject issue body as context
- **NEW**: Call `marsh start #N` to update status to "running"

#### `create-pr` (enhanced)
- Existing flow (push, create PR, verify Closes #N)
- **NEW**: Call `marsh pr` to update status to "pending"
- **NEW**: Write PR number/URL back to state.json

---

## 5. tmux Integration

### tmux.conf additions
```bash
# Marshroom HUD in status bar
set -g status-right '#(marsh hud) | %H:%M'
set -g status-interval 5

# Keybinding: Open PyCharm for current pane's repo
bind-key P run-shell "marsh open-ide"

# Keybinding: Show issue status
bind-key I run-shell "marsh status | tmux display-popup -"
```

### PyCharm Launch
```bash
marsh open-ide
# Detects: PyCharm, PyCharm CE, PyCharm Professional
# Runs: open -a "PyCharm" "$(pwd)"
# Fallback: pycharm . (if CLI launcher configured)
```

---

## 6. File Changes Summary

### New Files
| File | Type | Description |
|------|------|-------------|
| `Models/IssueStatus.swift` | Model | Status enum |
| `Services/AnthropicClient.swift` | Service | Claude API client |
| `Features/Mall/IssueComposerView.swift` | View | Smart Ingestion composer |
| `Features/Settings/AISettingsView.swift` | View | Anthropic API key settings |
| `cli/marsh` | CLI | Standalone CLI tool (shell script) |
| `marshroom-skills/` | Package | Vercel Agent Skills package |
| `docs/architecture-v2.md` | Docs | This document |
| `docs/user-guide.md` | Docs | User-facing documentation |

### Modified Files
| File | Changes |
|------|---------|
| `Models/MarshroomState.swift` | v3 schema with status, issueBody, prNumber, claudeMdCache |
| `Models/CartItem.swift` | Add status property |
| `Core/AppStateManager.swift` | Status updates, Anthropic client, CLAUDE.md cache |
| `Core/StateFileManager.swift` | v2→v3 migration, backward compat |
| `Core/SettingsStorage.swift` | Anthropic API key setting |
| `Core/Constants.swift` | Anthropic API URL, cache TTL |
| `Services/GitHubAPIClient.swift` | createIssue, fetchFileContent methods |
| `Services/GitHubPoller.swift` | Status transition detection, CLAUDE.md refresh |
| `Services/KeychainService.swift` | Anthropic key support |
| `Features/Mall/IssueListView.swift` | Composer integration, status badges |
| `Features/Mall/CartView.swift` | Status grouping |
| `Features/Mall/CartItemView.swift` | Status badge, PR link |
| `Features/Settings/SettingsWindow.swift` | New AI settings tab |
| `.claude/commands/start-issue.md` | Enhanced with context injection + marsh CLI |
| `.claude/commands/create-pr.md` | Enhanced with status update |

---

## 7. Implementation Order

1. **Models & Core** — IssueStatus, state.json v3 schema, migration
2. **GitHub API** — createIssue, fetchFileContent endpoints
3. **Anthropic Client** — API integration, Keychain storage
4. **Issue Composer** — UI for Smart Ingestion
5. **Status Pipeline** — Cart status tracking, visual updates
6. **CLI Tool (marsh)** — hud, start, status, open-ide, pr commands
7. **tmux Integration** — Status bar config, keybindings
8. **Vercel Agent Skills** — Package structure, enhanced skills
9. **Documentation** — Architecture + user guide
