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
# Git aliases
# ==================================================

alias gs='git status'
alias ga='git add .'
alias gr='git restore .'
alias gpr='git pull --rebase'
alias gl='git log --oneline --graph --all --decorate'
alias gfp='git fetch -p'
alias gus='git reset --soft HEAD~1'
alias guh='git reset --hard HEAD~1'
alias gsync='git switch dev && git pull origin main --rebase'
alias gabort='git merge --abort'
alias gdiffdeploy='git log main..dev --oneline --decorate'

# ==================================================
# Docker aliases
# ==================================================

alias dstart='docker compose start'
alias dstop='docker compose stop'
alias dcompose='docker compose up -d --build --remove-orphans'
alias ddown='docker compose down -v'
alias drestart='docker compose down && docker compose up -d'
alias dstopall='docker ps -aq | xargs -r docker stop'
alias drecompose='docker compose down -v && docker compose up -d'

# ==================================================
# Utility helpers
# ==================================================

## Show an overview of aliases and functions
bashrc() {
  echo -e "$INFO Aliases"
  echo

  awk '
    # Detect real section headers (ignore separators and ## docs)
    /^# / && !/^##/ && $0 !~ /^# [=-]+$/ {
      section = substr($0, 3)
      next
    }

    /^alias / && section != "" {
      sub(/^alias /, "", $0)
      printf "[%s]\n%s\n", section, $0
    }
  ' "${BASH_SOURCE[0]}" |
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

  echo
  echo -e "$INFO Functions"
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
  ' "${BASH_SOURCE[0]}" |
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

## Ask for y/N confirmation
confirm() {
  read -rp "$1 (y/N): " ans
  [[ "$ans" == "y" ]]
}

## Check availability of common dev tools
envcheck() {
  for cmd in git docker docker-compose node npm; do
    if command -v "$cmd" >/dev/null; then
      echo -e "$OK $cmd installed"
    else
      echo -e "$ERR $cmd missing"
    fi
  done
}

# ==================================================
# Git workflow helpers
# ==================================================

## Switch to branch, pull latest, show status
workon() {
  echo -e "$INFO Switching to branch '$1'"
  git switch "$1" || return 1
  git pull || return 1
  git status
}

## Force dev to match origin/main (destructive)
syncdev() {
  local current
  current=$(git branch --show-current)

  echo -e "$INFO Syncing dev with origin/main"
  git switch dev || return 1
  git fetch origin || return 1
  git reset --hard origin/main || return 1

  [[ "$current" != "dev" ]] && git switch "$current"
  echo -e "$OK dev is now in sync with main"
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
    echo -e "$ERR Another promotion is already running"
    return 1
  fi

  original=$(git branch --show-current)

  cleanup() {
    git merge --abort >/dev/null 2>&1 || true
    git switch "$original" >/dev/null 2>&1 || \
      echo -e "$WARN Manual switch to $original required"
    rmdir "$LOCKDIR" >/dev/null 2>&1 || true
  }

  trap cleanup EXIT

  if [[ "$original" != "dev" ]]; then
    echo -e "$ERR Must be run from dev (current: $original)"
    return 1
  fi

  if ! git diff --quiet || ! git diff --cached --quiet; then
    echo -e "$ERR Working tree is dirty — commit or stash first"
    return 1
  fi

  if [[ -z "$(git log main..dev --oneline)" ]]; then
    echo -e "$INFO Nothing to promote (dev == main)"
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
  git push origin main || {
    echo -e "$ERR Push failed, rolling back local main"
    git reset --hard origin/main
    return 1
  }

  tag="release-$(date +%Y%m%d-%H%M%S)"
  echo -e "$INFO Tagging release ($tag)"
  git tag -a "$tag" -m "Release" || return 1
  git push origin "$tag" || return 1

  echo -e "$OK Promotion successful ($tag)"
}

# ==================================================
# Docker workflows
# ==================================================

## Restart docker compose stack
rebootstack() {
  echo -e "$INFO Restarting docker stack"
  docker compose down || return 1
  docker compose up -d || return 1
  echo -e "$OK Stack restarted"
}

## Fully reset docker stack (destructive)
resetstack() {
  echo -e "$WARN This will remove containers, networks, and volumes"
  confirm "Continue?" || return 1

  docker compose down -v || return 1
  docker system prune -f
  echo -e "$OK Docker stack fully reset"
}
