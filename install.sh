#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─── Colors & formatting ────────────────────────────────────────────

if [[ -t 1 ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  BLUE='\033[0;34m'
  BOLD='\033[1m'
  DIM='\033[2m'
  RESET='\033[0m'
else
  RED='' GREEN='' YELLOW='' BLUE='' BOLD='' DIM='' RESET=''
fi

info()    { echo -e "${GREEN}[✓]${RESET} $*"; }
warn()    { echo -e "${YELLOW}[!]${RESET} $*"; }
error()   { echo -e "${RED}[✗]${RESET} $*" >&2; }
step()    { echo -e "\n${BOLD}${BLUE}$*${RESET}"; }
confirm() {
  local prompt="$1"
  local reply
  echo -ne "${YELLOW}[?]${RESET} ${prompt} [y/N] "
  read -r reply
  [[ "$reply" =~ ^[Yy]$ ]]
}

# ─── Banner ─────────────────────────────────────────────────────────

banner() {
  echo ""
  echo -e "${BOLD}  🍄 Marshroom Installer${RESET}"
  echo -e "${DIM}  Multi-Repo Execution Catalyst${RESET}"
  echo ""
}

# ─── Usage ──────────────────────────────────────────────────────────

usage() {
  cat <<EOF
Usage: ./install.sh [OPTIONS]

Options:
  --app       Install macOS app only (from GitHub Releases)
  --cli       Install marsh CLI only (symlink to /usr/local/bin)
  --tmux      Install tmux plugin only (tpm + config)
  --skills    Show Claude Code skills install instructions
  --check     Verify dependencies without making changes
  --help      Show this help message

When no options are given, all components are installed.
Options are combinable: ./install.sh --cli --tmux
EOF
}

# ─── Argument parsing ───────────────────────────────────────────────

DO_APP=false
DO_CLI=false
DO_TMUX=false
DO_SKILLS=false
DO_CHECK=false
DO_ALL=true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app)    DO_APP=true;    DO_ALL=false ;;
    --cli)    DO_CLI=true;    DO_ALL=false ;;
    --tmux)   DO_TMUX=true;   DO_ALL=false ;;
    --skills) DO_SKILLS=true; DO_ALL=false ;;
    --check)  DO_CHECK=true;  DO_ALL=false ;;
    --help|-h) usage; exit 0 ;;
    *)
      error "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
  shift
done

if $DO_ALL; then
  DO_APP=true
  DO_CLI=true
  DO_TMUX=true
  DO_SKILLS=true
fi

# ─── Dependency checking ────────────────────────────────────────────

check_deps() {
  step "[1/2] Checking dependencies"

  local missing=()
  local all_ok=true

  # Always-required
  for cmd in git curl; do
    if command -v "$cmd" &>/dev/null; then
      info "$cmd found"
    else
      error "$cmd not found"
      missing+=("$cmd")
      all_ok=false
    fi
  done

  # CLI requires jq
  if $DO_CLI || $DO_ALL; then
    if command -v jq &>/dev/null; then
      info "jq found"
    else
      warn "jq not found (required by marsh CLI)"
      missing+=("jq")
      all_ok=false
    fi
  fi

  # tmux component
  if $DO_TMUX || $DO_ALL; then
    if command -v tmux &>/dev/null; then
      info "tmux found"
    else
      warn "tmux not found (required for tmux plugin)"
      missing+=("tmux")
      all_ok=false
    fi
  fi

  # gh is optional but useful for --app and --cli workflows
  if command -v gh &>/dev/null; then
    info "gh CLI found"
  else
    warn "gh CLI not found (optional, used for GitHub Releases download)"
  fi

  # Homebrew check for installing missing deps
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo ""
    if command -v brew &>/dev/null; then
      local brew_cmd="brew install ${missing[*]}"
      if confirm "Install missing dependencies with: ${brew_cmd}"; then
        brew install "${missing[@]}"
        info "Dependencies installed"
        all_ok=true
      else
        error "Missing dependencies: ${missing[*]}"
        echo "  Install manually or run: ${brew_cmd}"
        return 1
      fi
    else
      error "Missing dependencies: ${missing[*]}"
      echo "  Install Homebrew first: https://brew.sh"
      echo "  Then run: brew install ${missing[*]}"
      return 1
    fi
  fi

  if $all_ok; then
    info "All dependencies satisfied"
  fi
}

# ─── install_app() ──────────────────────────────────────────────────

install_app() {
  step "[App] Installing Marshroom.app"

  local app_dest="/Applications/Marshroom.app"

  # Check if already installed
  if [[ -d "$app_dest" ]]; then
    warn "Marshroom.app already exists in /Applications"
    if ! confirm "Overwrite existing installation?"; then
      info "Skipping app install"
      return 0
    fi
  fi

  # Try downloading from GitHub Releases
  local dmg_path=""
  local tmp_dmg
  tmp_dmg="$(mktemp /tmp/Marshroom-XXXXXX.dmg)"

  if command -v gh &>/dev/null; then
    echo "  Downloading latest release via gh CLI..."
    if gh release download --repo vkehfdl1/Marshroom --pattern '*.dmg' --output "$tmp_dmg" --clobber 2>/dev/null; then
      dmg_path="$tmp_dmg"
    fi
  fi

  if [[ -z "$dmg_path" ]]; then
    echo "  Trying curl download from GitHub Releases..."
    local download_url
    download_url=$(curl -sL "https://api.github.com/repos/vkehfdl1/Marshroom/releases/latest" \
      | grep -o '"browser_download_url":[[:space:]]*"[^"]*\.dmg"' \
      | head -1 \
      | sed 's/"browser_download_url":[[:space:]]*"//;s/"$//') || true

    if [[ -n "$download_url" ]]; then
      if curl -sL "$download_url" -o "$tmp_dmg"; then
        dmg_path="$tmp_dmg"
      fi
    fi
  fi

  if [[ -n "$dmg_path" ]]; then
    echo "  Mounting DMG..."
    local mount_point
    mount_point=$(hdiutil attach "$dmg_path" -nobrowse -quiet 2>/dev/null \
      | grep '/Volumes/' | sed 's/.*\(\/Volumes\/.*\)/\1/' | head -1) || true

    if [[ -n "$mount_point" ]] && [[ -d "${mount_point}/Marshroom.app" ]]; then
      echo "  Copying to /Applications..."
      rm -rf "$app_dest" 2>/dev/null || true
      cp -R "${mount_point}/Marshroom.app" "$app_dest"
      hdiutil detach "$mount_point" -quiet 2>/dev/null || true
      rm -f "$tmp_dmg"
      info "Marshroom.app installed to /Applications"
      return 0
    fi

    # Clean up failed mount
    hdiutil detach "$mount_point" -quiet 2>/dev/null || true
    rm -f "$tmp_dmg"
  fi

  # Fallback: build from source
  rm -f "$tmp_dmg"
  warn "No release DMG found. Attempting to build from source..."

  if [[ -d "$SCRIPT_DIR/Marshroom/Marshroom.xcodeproj" ]]; then
    if command -v xcodebuild &>/dev/null; then
      echo "  Building (this may take a minute)..."
      local build_dir="$SCRIPT_DIR/build"
      if xcodebuild -project "$SCRIPT_DIR/Marshroom/Marshroom.xcodeproj" \
        -scheme Marshroom \
        -configuration Debug build \
        CODE_SIGN_IDENTITY="-" \
        CODE_SIGNING_ALLOWED=YES \
        SYMROOT="$build_dir" \
        -quiet 2>/dev/null; then

        local built_app="$build_dir/Build/Products/Debug/Marshroom.app"
        if [[ -d "$built_app" ]]; then
          rm -rf "$app_dest" 2>/dev/null || true
          cp -R "$built_app" "$app_dest"
          info "Marshroom.app built and installed to /Applications"
          return 0
        fi
      fi
    fi
  fi

  warn "Could not install Marshroom.app automatically"
  echo "  Build manually with:"
  echo "    xcodebuild -project Marshroom/Marshroom.xcodeproj \\"
  echo "      -scheme Marshroom -configuration Debug build \\"
  echo "      CODE_SIGN_IDENTITY=\"-\" CODE_SIGNING_ALLOWED=YES"
  echo "  Then copy build/Build/Products/Debug/Marshroom.app to /Applications"
}

# ─── install_cli() ──────────────────────────────────────────────────

install_cli() {
  step "[CLI] Installing marsh CLI"

  local marsh_src="$SCRIPT_DIR/cli/marsh"
  local marsh_dest="/usr/local/bin/marsh"

  if [[ ! -f "$marsh_src" ]]; then
    error "cli/marsh not found at $marsh_src"
    return 1
  fi

  # Ensure it's executable
  chmod +x "$marsh_src"

  # Check existing symlink
  if [[ -L "$marsh_dest" ]]; then
    local current_target
    current_target=$(readlink "$marsh_dest")
    if [[ "$current_target" == "$marsh_src" ]]; then
      info "marsh CLI already linked correctly"
      return 0
    else
      warn "Existing symlink points to: $current_target"
    fi
  fi

  # Create symlink
  if [[ -w "$(dirname "$marsh_dest")" ]]; then
    ln -sf "$marsh_src" "$marsh_dest"
  else
    echo "  Creating symlink requires elevated permissions."
    if confirm "Run sudo to create /usr/local/bin/marsh symlink?"; then
      sudo ln -sf "$marsh_src" "$marsh_dest"
    else
      warn "Skipping symlink. Add the CLI to your PATH manually:"
      echo "  # Add to ~/.zshrc or ~/.bashrc"
      echo "  export PATH=\"\$PATH:${SCRIPT_DIR}/cli\""
      return 0
    fi
  fi

  info "marsh CLI linked: $marsh_dest → $marsh_src"
}

# ─── install_tmux() ─────────────────────────────────────────────────

install_tmux() {
  step "[tmux] Installing tmux plugin"

  local tpm_dir="$HOME/.tmux/plugins/tpm"
  local plugin_dir="$HOME/.tmux/plugins/Marshroom"
  local tmux_conf="$HOME/.tmux.conf"

  # 1. Install tpm if missing
  if [[ -d "$tpm_dir" ]]; then
    info "tpm already installed"
  else
    echo "  Cloning tpm..."
    git clone https://github.com/tmux-plugins/tpm "$tpm_dir" --quiet
    info "tpm installed at $tpm_dir"
  fi

  # 2. Symlink Marshroom plugin
  if [[ -L "$plugin_dir" ]]; then
    local current_target
    current_target=$(readlink "$plugin_dir")
    if [[ "$current_target" == "$SCRIPT_DIR" ]]; then
      info "Marshroom plugin symlink already correct"
    else
      warn "Updating symlink: $plugin_dir"
      ln -sf "$SCRIPT_DIR" "$plugin_dir"
      info "Marshroom plugin symlink updated"
    fi
  elif [[ -d "$plugin_dir" ]]; then
    warn "$plugin_dir exists but is not a symlink (may be a tpm-managed copy)"
    if confirm "Replace with symlink to local repo?"; then
      rm -rf "$plugin_dir"
      ln -sf "$SCRIPT_DIR" "$plugin_dir"
      info "Marshroom plugin symlink created"
    fi
  else
    mkdir -p "$(dirname "$plugin_dir")"
    ln -sf "$SCRIPT_DIR" "$plugin_dir"
    info "Marshroom plugin symlink created: $plugin_dir → $SCRIPT_DIR"
  fi

  # 3. Configure .tmux.conf
  local plugin_line="set -g @plugin 'vkehfdl1/Marshroom'"
  local tpm_run_line="run '~/.tmux/plugins/tpm/tpm'"
  local status_right_line="set -g status-right '#{marshroom_status} | %H:%M'"

  if [[ ! -f "$tmux_conf" ]]; then
    echo "  Creating $tmux_conf..."
    cat > "$tmux_conf" <<'TMUXCONF'
# Marshroom plugin
set -g @plugin 'vkehfdl1/Marshroom'
set -g status-right '#{marshroom_status} | %H:%M'

# Initialize tpm (keep at the very bottom)
run '~/.tmux/plugins/tpm/tpm'
TMUXCONF
    info "Created $tmux_conf with Marshroom config"
  else
    local changes_made=false

    # Add plugin line if missing
    if ! grep -qF "@plugin 'vkehfdl1/Marshroom'" "$tmux_conf"; then
      # Insert before tpm run line if it exists, otherwise append
      if grep -qF "tpm/tpm" "$tmux_conf"; then
        # Use a temp file for safe insertion
        local tmp_conf
        tmp_conf="$(mktemp "${tmux_conf}.XXXXXX")"
        while IFS= read -r line; do
          if [[ "$line" == *"tpm/tpm"* ]]; then
            echo "$plugin_line"
          fi
          echo "$line"
        done < "$tmux_conf" > "$tmp_conf"
        mv -f "$tmp_conf" "$tmux_conf"
      else
        echo "" >> "$tmux_conf"
        echo "$plugin_line" >> "$tmux_conf"
      fi
      info "Added Marshroom plugin line to .tmux.conf"
      changes_made=true
    else
      info "Marshroom plugin line already in .tmux.conf"
    fi

    # Check status-right for marshroom_status
    if grep -q 'marshroom_status' "$tmux_conf"; then
      info "#{marshroom_status} already in .tmux.conf"
    elif grep -q 'status-right' "$tmux_conf"; then
      warn "status-right is configured but doesn't include #{marshroom_status}"
      echo "  Add #{marshroom_status} to your status-right manually, e.g.:"
      echo "  set -g status-right '#{marshroom_status} | %H:%M'"
    else
      echo "$status_right_line" >> "$tmux_conf"
      info "Added status-right with #{marshroom_status} to .tmux.conf"
      changes_made=true
    fi

    # Add tpm run line if missing
    if ! grep -qF "tpm/tpm" "$tmux_conf"; then
      echo "" >> "$tmux_conf"
      echo "# Initialize tpm (keep at the very bottom)" >> "$tmux_conf"
      echo "$tpm_run_line" >> "$tmux_conf"
      info "Added tpm run line to .tmux.conf"
      changes_made=true
    else
      info "tpm run line already in .tmux.conf"
    fi

    if ! $changes_made; then
      info ".tmux.conf already fully configured"
    fi
  fi

  # 4. Offer to reload tmux
  if command -v tmux &>/dev/null && tmux list-sessions &>/dev/null 2>&1; then
    if confirm "Reload tmux config now?"; then
      tmux source-file "$tmux_conf"
      info "tmux config reloaded"
    fi
  fi
}

# ─── install_skills() ───────────────────────────────────────────────

install_skills() {
  step "[Skills] Claude Code skills setup"

  echo ""
  echo "  Skills are installed per-project, not system-wide."
  echo "  In each project where you want Marshroom skills, run one of:"
  echo ""
  echo -e "  ${BOLD}Option A — Vercel Agent Skills:${RESET}"
  echo "    npx skills add https://github.com/vkehfdl1/Marshroom/tree/main/marshroom-skills"
  echo ""
  echo -e "  ${BOLD}Option B — Local install script:${RESET}"
  echo "    bash ${SCRIPT_DIR}/marshroom-skills/scripts/install-skill.sh"
  echo ""

  # If the user is in a git repo that isn't Marshroom itself, offer to install
  local repo_root
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || true
  if [[ -n "$repo_root" ]] && [[ "$repo_root" != "$SCRIPT_DIR" ]]; then
    local repo_name
    repo_name=$(basename "$repo_root")
    if confirm "Install skills in the current repo ($repo_name)?"; then
      bash "$SCRIPT_DIR/marshroom-skills/scripts/install-skill.sh"
      info "Skills installed in $repo_name"
    fi
  fi
}

# ─── Post-install summary ───────────────────────────────────────────

summary() {
  echo ""
  echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "${BOLD}  🍄 Installation complete!${RESET}"
  echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo ""
  echo "  Next steps:"
  echo "  1. Open Marshroom.app and enter your GitHub PAT"
  echo "  2. Add repos and issues to your cart"
  echo "  3. In a project: /start-issue #N  →  code  →  /create-pr"
  echo ""
  echo "  Docs: https://github.com/vkehfdl1/Marshroom/blob/main/docs/user-guide.md"
  echo ""
}

# ─── Main ───────────────────────────────────────────────────────────

banner

if $DO_CHECK; then
  check_deps
  echo ""
  info "Dependency check complete. No changes were made."
  exit 0
fi

check_deps

total=0
current=0
$DO_APP    && ((total++)) || true
$DO_CLI    && ((total++)) || true
$DO_TMUX   && ((total++)) || true
$DO_SKILLS && ((total++)) || true

$DO_APP    && { ((current++)); install_app; }    || true
$DO_CLI    && { ((current++)); install_cli; }    || true
$DO_TMUX   && { ((current++)); install_tmux; }   || true
$DO_SKILLS && { ((current++)); install_skills; } || true

summary
