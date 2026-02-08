# Marshroom Claude Code Skills

Custom slash commands for Claude Code that integrate with the Marshroom app.

## Skills

### `/start-issue`
Reads the cart from `~/.config/marshroom/state.json`, matches the current repository, and creates the appropriate branch (`Feature/#N` or `HotFix/#N`). Injects project context (CLAUDE.md) and issue body for full task awareness. Updates status to `running` via `marsh` CLI.

### `/create-pr`
Creates a Pull Request for the current issue branch. Includes `Closes #N` in the PR body (mandatory) and the original issue body for reviewer context. Updates status to `pending` via `marsh` CLI.

### `/validate-pr`
Validates the current PR's branch name, body closing keywords, and status pipeline against Marshroom conventions.

## Installation

### Automatic
```bash
# From your project root:
bash /path/to/marshroom/Skills/install-skill.sh
```

### Via Vercel Agent Skills
```bash
npx skills add marshroom/marshroom-skills
```

### Manual
Copy the files from `.claude/commands/` to your project's `.claude/commands/` directory:
```bash
mkdir -p .claude/commands
cp /path/to/marshroom/.claude/commands/*.md .claude/commands/
```

## Requirements
- `gh` CLI (GitHub CLI) must be installed and authenticated
- `git` must be available
- Marshroom app must be running with issues in cart
- `marsh` CLI (optional) — for status updates and tmux HUD
