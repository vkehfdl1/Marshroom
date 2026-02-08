# Marshroom

My own workflow to use multiple Claude Code sessions & projects. 

If you juggle issues across multiple repos and use Claude Code to do the actual coding, Marshroom is the glue that makes them talk to each other. You pick issues in an app, Claude Code picks them up with full context, and a shared state file keeps everything in sync — from branch creation to PR merge.

## What it is

The problem: you have GitHub issues scattered across repos, you're using Claude Code as your coding agent, and the ceremony of "find issue, create branch, load context, push, make PR, close issue" is death by a thousand clicks. Multiple repos and multiple agent sessions drove me crazy due to the context switching.

Marshroom is three things that share one JSON file (`~/.config/marshroom/state.json`):

1. **A macOS menu bar app** — browse issues across repos, add them to a queue, create new issues with AI-generated titles
2. **A CLI tool (`marsh`)** — tmux HUD integration, status management, IDE launcher (tmux shortcut)
3. **Claude Code skills** — `/start-issue` & `/create-pr` automate the branch and PR lifecycle

The state file is the bridge. The app writes to it, the CLI reads and writes to it, the skills read from it. Everyone stays in sync through atomic file operations.

## The GOAT🐐 Flow

The whole workflow is five steps: **Draft, Inject, Execute, Review, Ship.**

**1. Draft** — Open Marshroom. Type a rough idea like "users can't log in with SSO when MFA is enabled" into the issue composer. Hit Cmd+Enter — Claude Haiku turns it into a clean title. Create the issue, add it to your queue. Status: `soon`.

**2. Inject** — In your terminal, inside the project repo:

```
/start-issue 42
```

This checks out main, pulls, creates `HotFix/#42` (or `Feature/#42` depending on the title), injects the full issue body into context, and sets status to `running`. Your tmux HUD updates to show `🍄 #42 Fix SSO login [Running]`.

**3. Execute** — Claude Code works on the issue with full context. You code alongside it or let it drive.

**4. Review** — When the work is done:

```
/create-pr
```

This pushes the branch, creates a PR with `Closes #42` in the body, includes the original issue description for reviewer context, and sets status to `pending`. Pop open your IDE with `Prefix+Ctrl-p` (PyCharm) or `Prefix+Ctrl-v` (VSCode) in tmux to review.

**5. Ship** — Merge the PR on GitHub. The Marshroom poller detects the issue closure and automatically marks it `completed`, then cleans it out of your queue.

## Quick Start

### Prerequisites

| Requirement | Notes |
|-------------|-------|
| macOS 14.0+ (Sonoma) | Needed for `@Observable` and `MenuBarExtra` |
| GitHub PAT | `repo` scope. Generate at github.com/settings/tokens |
| Anthropic API key | For Smart Ingestion. Get at console.anthropic.com |
| `gh` CLI | `brew install gh && gh auth login` |
| `jq` | `brew install jq` |
| tmux | `brew install tmux` |
| Claude Code | `npm install -g @anthropic-ai/claude-code` |

### Build the app

```bash
git clone https://github.com/vkehfdl1/Marshroom.git
cd Marshroom

xcodebuild -project Marshroom/Marshroom.xcodeproj \
  -scheme Marshroom \
  -configuration Debug build \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_ALLOWED=YES
```

The built app ends up in `build/Build/Products/Debug/Marshroom.app`.

### Install the CLI

Add the `cli/` directory to your PATH:

```bash
# In ~/.zshrc or ~/.bashrc
export PATH="$PATH:/path/to/Marshroom/cli"
```

Verify with `marsh help`.

### Set up tmux

Install [tpm](https://github.com/tmux-plugins/tpm) if you haven't, then add to `~/.tmux.conf`:

```bash
set -g @plugin 'vkehfdl1/Marshroom'
set -g status-right '#{marshroom_status} | %H:%M' # Optional

# Keep at the very bottom
run '~/.tmux/plugins/tpm/tpm'
```

Press `prefix + I` to install the plugin. This gives you the status bar HUD, per-pane borders, and IDE keybindings (`Prefix+Ctrl-p` for PyCharm, `Prefix+Ctrl-v` for VSCode).

### Install skills

In each project you want to use with Marshroom:

```bash
npx skills add https://github.com/vkehfdl1/Marshroom/tree/main/marshroom-skills
```

### First run

1. Open Marshroom.app — enter your GitHub PAT on the onboarding screen
2. Add your repos (search by `owner/repo`)
3. Optionally configure your **Anthropic API key** in Settings → AI for Smart Ingestion
4. Add issues to your cart and start working

## More docs

- [User Guide](docs/user-guide.md) — full installation walkthrough, GOAT workflow details, CLI reference, troubleshooting
- [Internal Architecture](docs/internal-architecture.md) — technical deep dive for contributors and AI agents

## License

MIT

## Acknowledgements

The project name `Marshroom` is inspired by amazing and talented singer Olivia & Danielle Marsh sisters🌻
