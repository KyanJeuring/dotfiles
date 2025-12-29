# --------------------------------------------------
# Output formatting (safe + portable)
# --------------------------------------------------

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


# --------------------------------------------------
# Utility helpers
# --------------------------------------------------

confirm() {
  read -rp "$1 (y/N): " ans
  [[ "$ans" == "y" ]]
}

envcheck() {
  for cmd in git docker docker-compose node npm; do
    if command -v "$cmd" >/dev/null; then
      echo -e "$OK $cmd installed"
    else
      echo -e "$ERR $cmd missing"
    fi
  done
}

# --------------------------------------------------
# Git aliases (abbreviations only)
# --------------------------------------------------

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

# --------------------------------------------------
# Promote function (Promotes dev to main)
# --------------------------------------------------

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

# --------------------------------------------------
# Git workflow helpers
# --------------------------------------------------

workon() {
  echo -e "$INFO Switching to branch '$1'"
  git switch "$1" || return 1
  git pull || return 1
  git status
}

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

cleanupbranches() {
  local current
  current=$(git branch --show-current)

  echo -e "$INFO Cleaning up branches merged into '$current' and branched from it"

  git branch --merged | while read -r branch; do
    # Skip current branch, main, dev
    [[ "$branch" == "*"* ]] && continue
    [[ "$branch" == "$current" ]] && continue
    [[ "$branch" == "main" || "$branch" == "dev" ]] && continue

    # Check if branch was created from current branch
    base=$(git merge-base "$current" "$branch")

    if [[ "$base" == "$(git rev-parse "$current")" ]]; then
      echo -e "$INFO Deleting branch '$branch'"
      git branch -d "$branch"
    fi
  done

  echo -e "$OK Branch cleanup complete"
}


whatwilldeploy() {
  echo -e "$INFO Commits that will be deployed:"
  git log main..dev --oneline --decorate
}

# --------------------------------------------------
# Docker / infrastructure workflows
# --------------------------------------------------

rebootstack() {
  echo -e "$INFO Restarting docker stack"
  docker compose down || return 1
  docker compose up -d || return 1
  echo -e "$OK Stack restarted"
}

resetstack() {
  echo -e "$WARN This will remove containers, networks, and volumes"
  confirm "Continue?" || return 1

  docker compose down -v || return 1
  docker system prune -f
  echo -e "$OK Docker stack fully reset"
}

# --------------------------------------------------
# Docker aliases (abbreviations)
# --------------------------------------------------

alias dstart='docker compose start'
alias dstop='docker compose stop'
alias dcompose='docker compose up -d --build --remove-orphans'
alias ddown='docker compose down -v'
alias drestart='docker compose down && docker compose up -d'
alias dstopall='docker ps -aq | xargs -r docker stop'
alias drecompose='docker compose down -v && docker compose up -d'
