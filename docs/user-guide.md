# Marshroom User Guide

## 1. What is Marshroom?

Marshroom is a macOS developer productivity tool that uses GitHub Issues for your daily workflow. It eliminates the cognitive load of context switching between GitHub, your terminal, and your IDE by unifying issue management, branch lifecycle, and AI-powered code execution into a single cockpit. Think of it as mission control: you draft ideas, queue them in a cart, execute them with Claude Code, review in your IDE, and ship PRs — all without leaving your flow. The status pipeline (`Soon → Running → Pending → Completed`) gives you a real-time HUD of what you're working on across every repo.

## 2. Prerequisites

| Requirement | Min Version | Notes |
|-------------|-------------|-------|
| macOS | 14.0+ (Sonoma) | Required for `@Observable` and MenuBarExtra |
| GitHub PAT | — | `repo` scope required. Generate at github.com/settings/tokens |
| Anthropic API Key | — | For Smart Ingestion (AI title generation). Get at console.anthropic.com |
| `gh` CLI | 2.x | `brew install gh && gh auth login` |
| `jq` | 1.6+ | `brew install jq` — required by `marsh` CLI |
| tmux | 3.x | `brew install tmux` — for terminal HUD |
| Claude Code | — | `npm install -g @anthropic-ai/claude-code` |

## 3. Installation

### Automated install (recommended)

The install script handles everything — macOS app, CLI, tmux plugin, and skills instructions:

```bash
git clone https://github.com/vkehfdl1/Marshroom.git && cd Marshroom
./install.sh
```

Install individual components with flags:

| Flag | Effect |
|------|--------|
| (none) | Install all components |
| `--app` | macOS app only (from GitHub Releases, falls back to build from source) |
| `--cli` | marsh CLI only (symlinks to `/usr/local/bin/marsh`) |
| `--tmux` | tmux plugin only (installs tpm, symlinks plugin, configures `.tmux.conf`) |
| `--skills` | Print per-project Claude Code skills install instructions |
| `--check` | Verify dependencies without making changes |
| `--help` | Print usage |

Flags are combinable: `./install.sh --cli --tmux`

The installer is idempotent — re-running it skips components that are already correctly installed.

### Manual install

#### Build from source

```bash
git clone https://github.com/marshroom/marshroom.git
cd marshroom

xcodebuild -project Marshroom/Marshroom.xcodeproj \
  -scheme Marshroom \
  -configuration Debug build \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_ALLOWED=YES
```

The built app lands in `build/Build/Products/Debug/Marshroom.app`. Move it to `/Applications` or run directly.

#### Install skills

**Vercel Agent Skills (recommended):**

```bash
npx skills add https://github.com/vkehfdl1/Marshroom/tree/main/marshroom-skills
```

Skills need to be installed in **each project** you want to use them in.

#### Install marsh CLI

Add the `cli/` directory to your PATH:

```bash
# In ~/.zshrc or ~/.bashrc
export PATH="$PATH:/path/to/marshroom/cli"
```

Verify:

```bash
marsh help
```

#### Configure tmux (tpm plugin)

First, install [tpm](https://github.com/tmux-plugins/tpm) if you haven't:

```bash
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
```

Then add to your `~/.tmux.conf`:

```bash
# Marshroom plugin
set -g @plugin 'vkehfdl1/Marshroom'
set -g status-right '#{marshroom_status} | %H:%M'

# Initialize tpm (keep at the very bottom)
run '~/.tmux/plugins/tpm/tpm'
```

Press **prefix + I** in tmux to install, or reload:

```bash
tmux source-file ~/.tmux.conf
```

This adds:
- **Status bar HUD** — `#{marshroom_status}` in `status-right` shows the current issue and status, refreshes every 5 seconds
- **Per-pane border HUD** — the plugin automatically sets `pane-border-status top` and `pane-border-format` so each tmux pane shows its own issue based on the pane's working directory. No manual configuration needed.
- **Prefix + Ctrl-p** — opens PyCharm for the current pane's repo
- **Prefix + Ctrl-v** — opens VSCode for the current pane's repo
- **Prefix + I** — pops up the issue status for the current repo

Optional plugin options (add before the `run` line):

```bash
set -g @marshroom_interval 5              # Status refresh interval (seconds)
set -g @marshroom_status_right_length 80  # Max width for status-right
set -g @marshroom_open_pycharm_key C-p    # Keybinding for PyCharm (Prefix+Ctrl-p)
set -g @marshroom_open_vscode_key C-v     # Keybinding for VSCode (Prefix+Ctrl-v)
set -g @marshroom_status_key I            # Keybinding for status popup
set -g @marshroom_pane_format " #{marshroom_status} | #P: #{b:pane_current_path} "
                                          # Custom pane border format (default shown)
```

## 4. Getting Started

### First launch

1. Open Marshroom.app. You'll see the onboarding screen.
2. Enter your GitHub Personal Access Token (PAT) with `repo` scope.
3. The token is stored securely in macOS Keychain.

### Adding repositories

1. In the main window, click the **+** button in the sidebar.
2. Search for repositories by name (e.g., `owner/repo`).
3. Click the **+** icon next to a repo to add it to your highlights.
4. Close the sheet — the repo appears in the sidebar.

### Configuring AI (Smart Ingestion)

1. Open **Settings** (`Cmd+,`) → **AI** tab.
2. Paste your Anthropic API key and click **Save**.
3. Click **Test Connection** to verify.

### Skill setup

For each project you work on:

```bash
cd ~/projects/my-repo
bash /path/to/marshroom/marshroom-skills/scripts/install-skill.sh
```

This copies `start-issue.md`, `create-pr.md`, and `validate-pr.md` into `.claude/commands/`.

## 5. The GOAT Workflow

Marshroom follows a five-stage execution pipeline:

```
Draft → Inject → Execute → Review → Ship
```

### Step 1: Draft (Status: `soon`)

Open Marshroom. Select a repository in the sidebar, then use the **New Issue** composer at the top of the issue list.

1. Type your raw idea in the text area (e.g., "users can't log in with SSO when MFA is enabled").
2. Press **Cmd+Enter** (or click **Generate Title**). The AI generates a clean issue title using Claude.
3. Edit the title if needed, then click **Create Issue**.

The issue is created on GitHub. To add it to your cart, click the cart icon on any issue. The cart entry is saved to `state.json` with status `soon`.

### Step 2: Inject (Status: `running`)

Switch to your terminal. Navigate to the project repo and run:

```
/start-issue 42
```

This skill:
- Checks out `main` and pulls latest
- Creates a branch (`Feature/#42` or `HotFix/#42` depending on the issue title)
- Injects the project's `CLAUDE.md` context into the conversation
- Loads the full issue body for Claude to work with
- Updates the cart status to `running`

Your tmux HUD now shows: `🍄 #42 Fix SSO login with MFA [Running]`

### Step 3: Execute

Claude Code works on the issue with full context — the project guidelines, the issue description, and the correct branch already checked out. Code as normal, or let Claude drive.

### Step 4: Review (Status: `pending`)

When the work is done:

```
/create-pr
```

This skill:
- Pushes the branch to origin
- Creates a PR titled after the issue, with `Closes #42` in the body
- Includes the original issue body in the PR description for reviewer context
- Updates the cart status to `pending`

To open your IDE for code review, press **Prefix + Ctrl-p** (PyCharm) or **Prefix + Ctrl-v** (VSCode) in tmux, or run:

```bash
marsh open-ide          # auto-detect installed IDE
marsh open-ide pycharm  # explicit PyCharm
marsh open-ide vscode   # explicit VSCode
```

Optionally validate the PR before merging:

```
/validate-pr
```

This checks branch naming conventions, closing keywords, and status pipeline consistency.

### Step 5: Ship (Status: `completed`)

Merge the PR on GitHub. The Marshroom poller detects the issue closure and automatically marks the cart entry as `completed`, then removes it from the cart.

## 6. Feature Guide

### Issue Mall

The main window is a three-column layout:

| Column | Content |
|--------|---------|
| **Sidebar** | Your highlighted repositories |
| **Content** | Issue list for the selected repo + inline composer |
| **Detail** | Issue detail (top) + Cart (bottom), 50/50 split with draggable divider |

- Select a repo in the sidebar to browse its open issues.
- Click an issue to view its full description in the detail panel.
- The **cart icon** on each issue adds or removes it from your local cart.
- Issues in your cart show a status badge (Soon / Running / Pending).

### Smart Ingestion (AI Title Generation)

The issue composer at the top of the issue list uses Claude (via the Anthropic API) to transform rough ideas into well-formed issue titles.

**How it works:**
1. Your raw text input is sent to Claude Haiku along with the repo's `CLAUDE.md` context (if cached).
2. Claude returns a concise, actionable issue title.
3. You can edit the title before creating the issue.

Requires an Anthropic API key configured in **Settings → AI**.

### Status Pipeline

Each cart item progresses through four states:

| Status | Meaning | Set By |
|--------|---------|--------|
| `Soon` | Queued in cart, not started | Default when added to cart |
| `Running` | Claude Code is actively working | `/start-issue` or `marsh start` |
| `Pending` | PR created, awaiting review | `/create-pr` or `marsh pr` |
| `Completed` | Issue closed / PR merged | Poller (auto-detected) |

The cart view groups items by status: Running first, then Pending, then Soon.

### Terminal HUD

The tmux status bar and pane borders show the current issue for whichever repo the pane is in. The HUD uses **branch-aware three-tier resolution** to determine which issue to display:

1. **Branch match** — if the current git branch matches a cart entry's `branchName` (e.g., `Feature/#42`), that issue is shown. This naturally handles multiple worktrees and clones.
2. **Single entry or lone runner** — if no branch matches, shows the single cart entry for the repo, or the sole `running` entry if exactly one exists.
3. **Summary mode** — if multiple entries exist with no clear winner, shows a task count summary.

**Display formats:**
```
🍄 #42 Fix SSO login with MFA [Running] | owner/repo        (single issue)
🍄 3 tasks (1 running, 2 soon) | owner/repo                  (summary mode)
```

- Color-coded by status (green = running, blue = pending, yellow = soon)
- Truncates titles longer than 30 characters
- Falls back to "No tasks" when no cart entries match the current repo
- Refreshes every 5 seconds
- **Per-pane display**: each tmux pane border shows the issue for that pane's directory, so split panes in different repos each show their own issue

### Quick Actions (marsh CLI)

| Command | Description |
|---------|-------------|
| `marsh hud` | Output tmux-formatted status string for current repo |
| `marsh start [#N]` | Mark a cart issue as `running` (interactive pick if multiple) |
| `marsh status` | Show all cart entries for the current repo |
| `marsh open-ide [ide]` | Open directory in IDE (pycharm, vscode; auto-detects) |
| `marsh pr` | Mark current branch's issue as `pending` |
| `marsh help` | Show help message |

### IDE Integration

Marshroom integrates with PyCharm and VSCode for code review:

- **tmux keybindings**: `Prefix + Ctrl-p` opens PyCharm, `Prefix + Ctrl-v` opens VSCode
- **Direct CLI**: `marsh open-ide pycharm`, `marsh open-ide vscode`, or just `marsh open-ide` to auto-detect
- **Environment variable**: set `MARSH_IDE=vscode` (or `pycharm`) to change the default for `marsh open-ide` without arguments
- **PyCharm detection**: PyCharm Professional → PyCharm CE → PyCharm → `pycharm` CLI
- **VSCode detection**: Visual Studio Code → Visual Studio Code - Insiders → `code` CLI

Install if not present:
- PyCharm: `brew install --cask pycharm`
- VSCode: `brew install --cask visual-studio-code`

## 7. Configuration Reference

### Settings tabs

| Tab | Contents |
|-----|----------|
| **General** | Polling interval, general preferences |
| **Repositories** | Manage highlighted repos |
| **AI** | Anthropic API key for Smart Ingestion |

### Polling interval

The Marshroom poller checks GitHub periodically for:
- Cart entry status changes (issue closure → `completed`)
- PR creation detection (running → `pending`)
- `CLAUDE.md` cache refresh (every hour)

### Anthropic API key

Stored in macOS Keychain (separate from the GitHub PAT). Used exclusively for Smart Ingestion title generation. Uses Claude Haiku for speed and cost efficiency.

### state.json

Location: `~/.config/marshroom/state.json`

This file is the bridge between the macOS app and all external tools (Claude Code skills, `marsh` CLI, tmux HUD). It is written atomically to prevent read conflicts.

**Schema (v3):**

```json
{
  "version": 3,
  "updatedAt": "2025-02-08T12:00:00Z",
  "cart": [
    {
      "repoFullName": "owner/repo",
      "repoCloneURL": "https://github.com/owner/repo.git",
      "repoSSHURL": "git@github.com:owner/repo.git",
      "issueNumber": 42,
      "issueTitle": "Fix SSO login with MFA",
      "branchName": "HotFix/#42",
      "status": "running",
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
      "localPath": "/Users/you/projects/repo"
    }
  ]
}
```

### tmux plugin options

The Marshroom tpm plugin supports these options (set before the `run` line in `.tmux.conf`):

| Option | Default | Description |
|--------|---------|-------------|
| `@marshroom_interval` | `5` | Status bar refresh interval (seconds) |
| `@marshroom_status_right_length` | `80` | Max width for status-right |
| `@marshroom_open_pycharm_key` | `C-p` | Keybinding for PyCharm (prefix + Ctrl-p) |
| `@marshroom_open_vscode_key` | `C-v` | Keybinding for VSCode (prefix + Ctrl-v) |
| `@marshroom_status_key` | `I` | Keybinding for status popup (prefix + key) |
| `@marshroom_pane_format` | `" #{marshroom_status} \| #P: #{b:pane_current_path} "` | Pane border format (auto-set by plugin) |

Use `#{marshroom_status}` in `status-right` or `status-left` to place the HUD in the global status bar. The pane border format is set automatically by the plugin — override it with `@marshroom_pane_format` if needed.

## 8. CLI Reference

### marsh hud

Output a tmux-formatted status string for the current repo.

```bash
marsh hud
# Output: #[fg=green]🍄#[fg=default] #42 Fix SSO login [Running] | owner/repo
```

Used internally by tmux `status-right`. Detects the repo from `git remote get-url origin` in the current directory.

### marsh start [#N]

Mark a cart issue as `running`.

```bash
marsh start #42         # Start specific issue
marsh start             # Interactive pick if multiple issues in cart
```

If multiple cart entries exist for the current repo and no issue number is provided, presents an interactive list.

### marsh status

Display all cart entries for the current repo. The entry matching the current git branch is marked with a `→` arrow.

```bash
marsh status
# 🍄 Marshroom — owner/repo
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# → #42 Fix SSO login with MFA
#     Status: running | Branch: HotFix/#42
#
#   #55 Add dark mode support
#     Status: soon | Branch: Feature/#55
```

### marsh open-ide [ide]

Open the current directory in an IDE. Supports `pycharm` and `vscode`.

```bash
marsh open-ide          # auto-detect (PyCharm first, then VSCode)
marsh open-ide pycharm  # 🍄 Opened PyCharm Professional
marsh open-ide vscode   # 🍄 Opened Visual Studio Code
```

Auto-detection order: PyCharm Professional → PyCharm CE → PyCharm → `pycharm` CLI → VSCode → VSCode Insiders → `code` CLI.

Set `MARSH_IDE=vscode` to change the default when no argument is given.

### marsh pr

Mark the current branch's cart issue as `pending` (PR created). Optionally captures PR number and URL via `gh pr view`.

```bash
marsh pr
# 🍄 PR for #42: Fix SSO login with MFA [Pending]
#   PR: https://github.com/owner/repo/pull/99
```

## 9. Troubleshooting

### No state.json found

**Symptom:** `marsh status` says "No state.json found. Is Marshroom running?"

**Fix:** Make sure Marshroom.app is running and you have at least one repo added. The app creates `~/.config/marshroom/state.json` on launch.

### jq not found

**Symptom:** `marsh` commands fail with "Error: jq is required but not installed."

**Fix:**
```bash
brew install jq
```

### gh CLI not authenticated

**Symptom:** `/create-pr` fails with authentication errors.

**Fix:**
```bash
gh auth login
gh auth status   # Verify
```

### Anthropic API key not configured

**Symptom:** The "Generate Title" button is disabled in the composer. The hint says "Set up AI key in Settings."

**Fix:** Open **Settings** (`Cmd+,`) → **AI** tab → paste your key → **Save**.

### Skills not found in Claude Code

**Symptom:** `/start-issue` returns "unknown command" in Claude Code.

**Fix:** Skills must be installed per-project:
```bash
cd /path/to/your-project
bash /path/to/marshroom/marshroom-skills/scripts/install-skill.sh
```

Verify `.claude/commands/start-issue.md` exists in the project root.

### tmux HUD not showing

**Symptom:** The tmux status bar doesn't show the Marshroom HUD.

**Fix:**
1. Ensure tpm is installed: `ls ~/.tmux/plugins/tpm`
2. Ensure the plugin line is in `.tmux.conf`: `set -g @plugin 'vkehfdl1/Marshroom'`
3. Ensure `#{marshroom_status}` is in your `status-right` or `status-left`
4. Install plugins: press **prefix + I** in tmux
5. Reload: `tmux source-file ~/.tmux.conf`

### Cart is empty after relaunch

**Symptom:** Issues you added to the cart are gone after relaunching Marshroom.

**Fix:** Cart state is persisted in `~/.config/marshroom/state.json`. If the file is missing or corrupted, the cart will be empty. Make sure Marshroom.app wrote the file (check with `cat ~/.config/marshroom/state.json | jq .cart`).

### Branch name format

Marshroom generates branch names automatically:
- If the issue title contains "Bug", "Fix", or "HotFix" → `HotFix/#N`
- Otherwise → `Feature/#N`

If you need a custom branch name, create the branch manually before running `/start-issue`.

### Verifying setup

Run this checklist to confirm everything is working:

```bash
# 1. CLI tools
which gh && which jq && which marsh && which tmux
# All should return paths

# 2. GitHub auth
gh auth status

# 3. state.json exists
cat ~/.config/marshroom/state.json | jq .version
# Should output: 3

# 4. Skills installed (run from your project)
ls .claude/commands/
# Should list: start-issue.md, create-pr.md, validate-pr.md

# 5. tmux HUD
marsh hud
# Should output a formatted status string
```
