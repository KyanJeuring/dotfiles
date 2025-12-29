# ==================================================
# Output formatting (safe + portable)
# ==================================================

if [[ -t 1 ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  BLUE='\033[0;34m'
  NC='\033[0m'
else
  RED='' GREEN='' YELLOW='' BLUE='' NC=''
fi

OK="${GREEN}[OK]${NC}"
ERR="${RED}[ERROR]${NC}"
INFO="${BLUE}[INFO]${NC}"
WARN="${YELLOW}[WARN]${NC}"

# ==================================================
# Utility helpers
# ==================================================

## Show an overview of custom bash commands
bashrc() {
  echo -e "$INFO Custom bash commands"
  echo

  awk '
    # Detect real section headers (ignore separators and ## docs)
    /^# / && !/^##/ && $0 !~ /^# [=-]+$/ {
      section = substr($0, 3)
      next
    }

    /^## / {
      desc = substr($0, 4)
      getline
      if ($0 ~ /^[a-zA-Z_][a-zA-Z0-9_]*\(\)/) {
        name = $0
        sub(/\(\).*/, "", name)
        printf "[%s]\n%-22s %s\n", section, name, desc
      }
    }
  ' "${BASH_SOURCE[${#BASH_SOURCE[@]}-1]}" |
  awk '
    /^\[/ {
      if ($0 != last) {
        if (NR > 1) print ""
        print $0
        last = $0
      }
      next
    }
    { print "  " $0 }
  '
}

confirm() {
  read -rp "$1 (y/N): " ans
  [[ "$ans" =~ ^[Yy]$ ]]
}

# ==================================================
# File & search commands (cross-platform)
# ==================================================

## Find files by name (case-insensitive)
ff() {
  [[ -z "$1" ]] && {
    echo -e "$ERR Usage: ff <pattern>"
    return 1
  }

  find . -iname "*$1*" 2>/dev/null
}

## Search text in files (fallback-safe)
grepall() {
  [[ -z "$1" ]] && {
    echo -e "$ERR Usage: grepall <text>"
    return 1
  }

  if command -v rg >/dev/null; then
    rg "$1"
  else
    grep -R "$1" .
  fi
}

## Show directory sizes (top-level only)
dus() {
  {
    du -sh . 2>/dev/null | sed 's|^\(.*\)[[:space:]]\+\.$|\1\t(total)|'
    du -sh ./* ./.??* 2>/dev/null
  } | sort -h
}

## Count lines of code
loc() {
  find . -type f ! -path "./.git/*" -exec wc -l {} + | tail -n 1
}

## Backup a file or directory
bu() {
  [[ -z "$1" ]] && {
    echo -e "$ERR Usage: bu <file|dir>"
    return 1
  }

  cp -r "$1" "$1.back-up.$(date +%Y%m%d-%H%M%S)"
  echo -e "$OK Backup created"
}

## Make executable
x() {
  chmod +x "$@"
  echo -e "$OK Made executable: $*"
}

# ==================================================
# Navigation commands (cross-platform)
# ==================================================

## Go to home directory
home() {
  cd "$HOME" || return 1
}

## Go up N directories (default: 1)
up() {
  local levels="${1:-1}"
  local path="."

  [[ ! "$levels" =~ ^[0-9]+$ ]] && {
    echo -e "$ERR Argument must be a number"
    return 1
  }

  for ((i=0; i<levels; i++)); do
    path="$path/.."
  done

  cd "$path" || return 1
}

## Create directory and enter it
mkcd() {
  [[ -z "$1" ]] && {
    echo -e "$ERR No directory specified"
    return 1
  }

  mkdir -p "$1" && cd "$1" || return 1
}

## Go to previous directory
back() {
  cd - >/dev/null || return 1
}

## Jump to git repository root
root() {
  local r
  r=$(git rev-parse --show-toplevel 2>/dev/null) || {
    echo -e "$ERR Not inside a git repository"
    return 1
  }

  cd "$r" || return 1
}

# ==================================================
# Git safety helpers
# ==================================================

_guard_main_rewrite() {
  local branch upstream commit_hash commit_msg

  branch=$(git branch --show-current 2>/dev/null) || return 1
  upstream=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null) || true

  # Show the commit that will be removed
  commit_hash=$(git rev-parse --short HEAD 2>/dev/null) || return 1
  commit_msg=$(git log -1 --pretty=%s 2>/dev/null) || return 1

  # Only guard on main
  [[ "$branch" != "main" ]] && return 0

  echo -e "$WARN You are on MAIN and about to rewrite history"
  [[ -n "$upstream" ]] && echo -e "$WARN Upstream: $upstream"

  # If upstream isn't main-ish, scream louder (still allow, but make it obvious)
  if [[ -n "$upstream" && "$upstream" != */main ]]; then
    echo -e "$WARN NOTE: upstream does not look like main (it is '$upstream')"
  fi

  echo -e "$WARN Commit to be removed: $commit_hash  $commit_msg"
  echo -e "$WARN This affects everyone pulling from main."

  echo
  read -rp "Type 'MAIN $commit_hash' to continue: " ans
  [[ "$ans" == "MAIN $commit_hash" ]]
}

_abort_reset() {
  git rev-parse ORIG_HEAD >/dev/null 2>&1 || {
    echo -e "$ERR No reset to abort"
    return 1
  }

  git reset --hard ORIG_HEAD &&
  echo -e "$OK Operation aborted"
}

# ==================================================
# Git commands
# ==================================================

## Show git status
gs() {
  git status
}

## Stage all changes
ga() {
  git add .
  echo -e "$OK All changes staged"
}

## Restore changes
gr() {
  if git diff --quiet; then
    echo -e "$INFO No unstaged changes to restore"
    return 0
  fi

  echo -e "$WARN This will discard ALL unstaged changes"
  confirm "Continue?" || return 1

  git restore .
  echo -e "$OK Changes restored"
}

## Restore staged changes
grs() {
  if git diff --cached --quiet; then
    echo -e "$INFO No staged changes to restore"
    return 0
  fi

  echo -e "$WARN This will unstage ALL staged changes"
  confirm "Continue?" || return 1

  git restore --staged .
  echo -e "$OK Staged changes restored"
}

## Pull with rebase
gpr() {
  git pull --rebase
}

## Pretty git log
gl() {
  git log --oneline --graph --all --decorate
}

## Prune deleted remote branches
gfp() {
  git fetch -p
}

## Undo last commit (soft)
gus() {
  [[ "$1" == "--abort" ]] && { _abort_reset; return $?; }

  git rev-parse HEAD >/dev/null 2>&1 || {
    echo -e "$ERR Repository has no commits"
    return 1
  }

  (( $(git rev-list --count HEAD) < 2 )) && {
    echo -e "$INFO Nothing to undo"
    return 0
  }

  git reset --soft HEAD~1 &&
  echo -e "$OK Last commit undone (soft)"
  echo -e "$INFO Use 'gus --abort' to restore previous HEAD if needed"
}

## Undo last remote commit (soft)
gurs() {
  local branch commit_count
  branch=$(git branch --show-current)

  [[ -z "$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null)" ]] && {
    echo -e "$ERR No upstream branch set"
    return 1
  }

  if ! git rev-parse HEAD >/dev/null 2>&1; then
    echo -e "$ERR Repository has no commits"
    return 1
  fi

  commit_count=$(git rev-list --count HEAD)

  # Cannot soft-reset the root commit
  if (( commit_count < 2 )); then
    echo -e "$ERR Cannot remove the initial (root) commit"
    echo -e "$INFO Git cannot reset past the first commit"
    echo -e "$INFO Use 'git commit --amend' instead"
    return 1
  fi

  _guard_main_rewrite || return 1

  echo -e "$INFO Removing latest commit on '$branch' (soft)"
  git reset --soft HEAD~1 &&
  git push --force-with-lease &&
  echo -e "$OK Latest commit removed (soft)"
}

## Undo last commit (hard)
guh() {
  [[ "$1" == "--abort" ]] && {
    echo -e "$WARN guh --abort only works immediately after guh"
    _abort_reset
    return $?
  }

  git rev-parse HEAD >/dev/null 2>&1 || {
    echo -e "$ERR Repository has no commits"
    return 1
  }

  (( $(git rev-list --count HEAD) < 2 )) && {
    echo -e "$INFO Nothing to discard"
    return 0
  }

  echo -e "$WARN This will permanently discard the last commit"
  confirm "Continue?" || return 1

  git reset --hard HEAD~1 &&
  echo -e "$OK Last commit discarded (hard)"
  echo -e "$INFO Use 'guh --abort' immediately to restore previous HEAD if needed"
}

## Undo last remote commit (hard)
gurh() {
  local branch commit_count
  branch=$(git branch --show-current)

  [[ -z "$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null)" ]] && {
    echo -e "$ERR No upstream branch set"
    return 1
  }

  # Ensure repo has commits
  if ! git rev-parse HEAD >/dev/null 2>&1; then
    echo -e "$ERR Repository has no commits"
    return 1
  fi

  commit_count=$(git rev-list --count HEAD)

  # Cannot hard-reset the initial commit
  if (( commit_count < 2 )); then
    echo -e "$ERR Cannot remove the initial (root) commit"
    echo -e "$INFO Git cannot hard-reset past the first commit"
    echo -e "$INFO Use 'git commit --amend' or recreate the branch instead"
    return 1
  fi

  _guard_main_rewrite || return 1

  if [[ "$branch" != "main" ]]; then
    echo -e "$WARN This will permanently remove the latest commit on '$branch'"
    confirm "Continue?" || return 1
  fi

  git reset --hard HEAD~1 &&
  git push --force-with-lease &&
  echo -e "$OK Latest commit permanently removed"
}

## Sync dev with main
gsync() {
  git switch dev && git pull origin main --rebase
}

## Abort current merge
gabort() {
  git merge --abort
}

## Show commits pending promotion
gdiffpromote() {
  git log main..dev --oneline --decorate
}

## Switch to branch, pull latest, show status
workon() {
  [[ -z "$1" ]] && {
    echo -e "$ERR Usage: workon <branch>"
    return 1
  }

  if ! git diff --quiet || ! git diff --cached --quiet; then
    echo -e "$ERR Working tree is dirty"
    echo -e "$INFO Commit or stash your changes before switching branches"
    return 1
  fi

  echo -e "$INFO Switching to branch '$1'"
  git switch "$1" || return 1

  echo -e "$INFO Pulling latest changes"
  git pull || return 1

  git status
}

## Force dev to match origin/main (destructive)
syncdev() {
  if [[ "$1" == "--abort" ]]; then
    local tag
    tag=$(git tag --list 'backup-dev-*' --sort=-creatordate | head -n1)

    if [[ -z "$tag" ]]; then
      echo -e "$ERR No backup tag found to abort syncdev"
      return 1
    fi

    echo -e "$INFO Aborting syncdev"
    echo -e "$INFO Restoring dev from backup tag: $tag"

    git switch dev >/dev/null 2>&1 || return 1
    git reset --hard "$tag" || return 1

    echo -e "$OK syncdev aborted successfully"
    return 0
  fi

  local current
  current=$(git branch --show-current)

  if ! git diff --quiet || ! git diff --cached --quiet; then
    echo -e "$ERR Working tree is dirty"
    echo -e "$INFO Commit or stash your changes first"
    return 1
  fi

  echo -e "$WARN This will RESET 'dev' to match 'origin/main'"
  echo -e "$WARN ALL local commits on dev will be LOST"

  if [[ -n "$(git log origin/main..dev --oneline 2>/dev/null)" ]]; then
    echo
    echo -e "$INFO Commits that will be removed:"
    git log origin/main..dev --oneline --decorate
    echo
  else
    echo -e "$INFO No local-only commits on dev"
  fi

  confirm "Continue?" || return 1

  echo -e "$INFO Fetching origin"
  git fetch origin || return 1

  echo -e "$INFO Switching to dev"
  git switch dev || return 1

  backup_tag="backup-dev-$(date +%Y%m%d-%H%M%S)"
  echo -e "$INFO Creating backup tag: $backup_tag"
  git tag "$backup_tag" || return 1

  echo -e "$INFO Resetting dev → origin/main"
  git reset --hard origin/main || return 1

  if [[ "$current" != "dev" ]]; then
    git switch "$current" >/dev/null 2>&1 || \
      echo -e "$WARN Manual switch back to '$current' required"
  fi

  echo -e "$OK dev is now in sync with origin/main"
  echo -e "$INFO Backup tag created: $backup_tag"
  echo -e "$INFO Use 'syncdev --abort' to restore this state"
}

## Delete merged child branches of current branch
cleanupbranches() {
  local current
  current=$(git branch --show-current)

  echo -e "$INFO Cleaning up merged branches of '$current'"

  git branch --merged | while read -r branch; do
    [[ "$branch" == "*"* ]] && continue
    [[ "$branch" == "$current" ]] && continue
    [[ "$branch" == "main" || "$branch" == "dev" ]] && continue

    base=$(git merge-base "$current" "$branch")
    if [[ "$base" == "$(git rev-parse "$current")" ]]; then
      echo -e "$INFO Deleting branch '$branch'"
      git branch -d "$branch"
    fi
  done

  echo -e "$OK Branch cleanup complete"
}

## Show commits that would be promoted
whatwilldeploy() {
  echo -e "$INFO Commits that would be promoted:"
  git log main..dev --oneline --decorate
}

## Promote dev → main and create a release tag
promote() {
  set -uo pipefail

  LOCKDIR="/tmp/git-promote.lock"
  if ! mkdir "$LOCKDIR" 2>/dev/null; then
    echo -e "$ERR Another promote is already running"
    return 1
  fi

  original=$(git branch --show-current)

  cleanup() {
    git merge --abort >/dev/null 2>&1 || true
    git switch "$original" >/dev/null 2>&1 || \
      echo -e "$WARN Manual switch to $original required"
    rmdir "$LOCKDIR" >/dev/null 2>&1 || true
  }

  trap cleanup RETURN
  trap cleanup EXIT
  trap 'echo -e "$ERR Deploy interrupted"; return 1' INT TERM

  if [[ "$original" != "dev" ]]; then
    echo -e "$ERR Deploy must be run from dev (current: $original)"
    return 1
  fi

  if ! git diff --quiet || ! git diff --cached --quiet; then
    echo -e "$ERR Working tree is dirty — commit or stash first"
    return 1
  fi

  if [[ -z "$(git log main..dev --oneline)" ]]; then
    echo -e "$INFO Nothing to deploy (dev == main)"
    return 0
  fi

  echo -e "$INFO Pushing dev"
  git push origin dev || return 1

  echo -e "$INFO Switching to main"
  git switch main || return 1

  echo -e "$INFO Pulling latest main"
  git pull origin main || return 1

  echo -e "$INFO Merging dev → main"
  git merge --no-ff dev || return 1

  echo -e "$INFO Pushing main"
  if ! git push origin main; then
    echo -e "$ERR Push failed, rolling back local main"
    git reset --hard origin/main
    return 1
  fi

  echo -e "$INFO Tagging deploy"
  tag="deploy-$(date +%Y%m%d-%H%M%S)"
  git tag -a "$tag" -m "Production deploy" || return 1
  git push origin "$tag" || return 1

  echo -e "$OK Deploy successful ($tag)"
}

# ==================================================
# Docker commands
# ==================================================

## List running containers with status and ports
dps() {
  docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
}

## Start docker compose services
dstart() {
  docker compose start
}

## Stop docker compose services
dstop() {
  docker compose stop
}

## Build and start docker stack
dcompose() {
  docker compose up -d --build --remove-orphans
}

## Stop and remove containers + volumes
ddown() {
  docker compose down -v
}

## Restart docker stack
drestart() {
  docker compose down && docker compose up -d
}

## Stop all running containers
dstopall() {
  docker ps -aq | xargs -r docker stop
}

## Recreate docker stack with volume removal
drecompose() {
  docker compose down -v && docker compose up -d
}

## Restart docker compose stack
drebootstack() {
  echo -e "$INFO Restarting docker stack"
  docker compose down || return 1
  docker compose up -d || return 1
  echo -e "$OK Stack restarted"
}

## Fully reset docker stack (destructive)
dresetstack() {
  echo -e "$WARN This will remove containers, networks, and volumes"
  confirm "Continue?" || return 1

  docker compose down -v || return 1
  docker system prune -f
  echo -e "$OK Docker stack fully reset"
}
