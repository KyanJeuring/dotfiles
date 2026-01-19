# ==================================================
# Git safety helpers (internal)
# ==================================================

_guard_main_rewrite() {
  local branch upstream commit_hash commit_msg

  branch=$(git branch --show-current 2>/dev/null) || return 1
  upstream=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null) || true

  commit_hash=$(git rev-parse --short HEAD 2>/dev/null) || return 1
  commit_msg=$(git log -1 --pretty=%s 2>/dev/null) || return 1

  [[ "$branch" != "main" ]] && return 0

  warn "You are on MAIN and about to rewrite history"
  [[ -n "$upstream" ]] && warn "Upstream: $upstream"

  if [[ -n "$upstream" && "$upstream" != */main ]]; then
    warn "NOTE: upstream does not look like main (it is '$upstream')"
  fi

  warn "Commit to be removed: $commit_hash  $commit_msg"
  warn "This affects everyone pulling from main."
  log

  read -rp "Type 'MAIN $commit_hash' to continue: " ans
  [[ "$ans" == "MAIN $commit_hash" ]]
}

_abort_reset() {
  git rev-parse ORIG_HEAD >/dev/null 2>&1 || {
    err "No reset to abort"
    return 1
  }

  git reset --hard ORIG_HEAD &&
  ok "Operation aborted"
}

_branch_exists() {
  git show-ref --verify --quiet "refs/heads/$1" ||
  git show-ref --verify --quiet "refs/remotes/origin/$1"
}

# ==================================================
# Git helpers
# ==================================================

## Go to git repository root
groot() {
  local r
  r=$(git rev-parse --show-toplevel 2>/dev/null) || {
    err "Not inside a git repository"
    return 1
  }
  cd "$r" || return 1
}

## Clone a GitHub repository
gclone() {
  local repo user host url target

  case "$#" in
    1)
      repo="$1"
      user="kyanjeuring"
      host="github.com"
      ;;
    2)
      repo="$1"
      user="$2"
      host="github.com"
      ;;
    3)
      repo="$1"
      user="$2"
      host="$3"
      ;;
    *)
      err "Usage: gclone <repo> [username] [ssh-host]"
      return 1
      ;;
  esac

  target="$repo"

  if [[ ! "$repo" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    err "Invalid repository name: '$repo'"
    return 1
  fi

  if [[ ! "$user" =~ ^[a-zA-Z0-9-]+$ ]]; then
    err "Invalid username: '$user'"
    return 1
  fi

  if [[ ! "$host" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    err "Invalid SSH host: '$host'"
    return 1
  fi

  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    err "Cannot clone inside an existing Git repository"
    return 1
  fi

  if [[ -e "$target" ]]; then
    warn "Repository already exists: $target"
    return 1
  fi

  case "$user" in
    kyanjeuring|kj|kyan|kyanj|me|myself)
      user="kyanjeuring"
      ;;
  esac

  url="git@$host:$user/$repo.git"

  info "Checking repository access"
  if ! git ls-remote "$url" >/dev/null 2>&1; then
    err "Repository not found or access denied"
    err "Used SSH host: $host"
    log
    warn "This command clones repositories over SSH."
    warn "Access is determined by the SSH key used and the GitHub account it belongs to."
    warn
    warn "Possible causes:"
    warn "  - The SSH key used maps to a GitHub account that does not have access"
    warn "  - No SSH key is configured for GitHub on this machine"
    warn
    warn "If needed, generate an SSH key and add it to the GitHub account"
    warn "that has access to this repository."
    warn
    warn "Try the gclone command and specify the user and SSH host:"
    warn "  gclone $repo <user> <ssh-host>"
    return 1
  fi

  info "Cloning $user/$repo via SSH ($host)"
  if git clone "$url"; then
    ok "Clone complete"
  else
    err "Clone failed"
    return 1
  fi
}

# ==================================================
# Git repo templating
# ==================================================

## Add .gitignore from dotfiles template
create-gitignore() {
  groot || return 1

  if [[ -f .gitignore ]]; then
    warn ".gitignore already exists in repo root"
    return 1
  fi

  local template="$HOME/dotfiles/git/templates/.gitignore"

  [[ ! -f "$template" ]] && {
    err "Template not found: $template"
    return 1
  }

  cp "$template" .gitignore
  ok ".gitignore added to repository"
}

## Add .gitattributes from dotfiles template
create-gitattributes() {
  groot || return 1

  if [[ -f .gitattributes ]]; then
    warn ".gitattributes already exists in repo root"
    return 1
  fi

  local template="$HOME/dotfiles/git/templates/.gitattributes"

  [[ ! -f "$template" ]] && {
    err "Template not found: $template"
    return 1
  }

  cp "$template" .gitattributes
  ok ".gitattributes added to repository"
}

## Apply all git templates from dotfiles to current repo
gtemplate() {
  local template_dir="$HOME/dotfiles/git/templates"
  local applied=0 skipped=0 overwritten=0 failed=0
  local reply name target template
  local old_nullglob repo_root

  [[ -d "$template_dir" ]] || {
    err "Template directory not found: $template_dir"
    return 1
  }

  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || {
      err "Failed to resolve repository root"
      return 1
    }
    cd "$repo_root" || return 1
  else
    info "Not a Git repository, initializing one"
    git init >/dev/null 2>&1 || {
      err "git init failed"
      return 1
    }
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || {
      err "git init succeeded but repo root could not be resolved"
      return 1
    }
    cd "$repo_root" || return 1
  fi

  info "Applying git templates from: $template_dir"

  old_nullglob=$(shopt -p nullglob)
  shopt -s nullglob

  for template in "$template_dir"/* "$template_dir"/.*; do
    name="$(basename "$template")"
    [[ "$name" == "." || "$name" == ".." ]] && continue

    target="$PWD/$name"

    if [[ -e "$target" ]]; then
      warn "$name already exists"
      printf "Overwrite %s? [y/N]: " "$name"
      read -r reply

      case "$reply" in
        y|Y|yes|YES)
          [[ -n "$target" && "$target" != "/" ]] || {
            err "Refusing to remove unsafe path: $target"
            failed=$((failed + 1))
            continue
          }

          rm -rf "$target" || {
            err "Failed to remove existing: $name"
            failed=$((failed + 1))
            continue
          }

          if cp -r "$template" "$target"; then
            ok "$name overwritten"
            overwritten=$((overwritten + 1))
          else
            err "Failed to copy: $name"
            failed=$((failed + 1))
          fi
          ;;
        *)
          warn "Skipped $name"
          skipped=$((skipped + 1))
          ;;
      esac
      continue
    fi

    if cp -r "$template" "$target"; then
      ok "$name added"
      applied=$((applied + 1))
    else
      err "Failed to add template: $name"
      failed=$((failed + 1))
    fi
  done

  eval "$old_nullglob"

  info "Templates added: $applied"
  info "Templates overwritten: $overwritten"
  info "Templates skipped: $skipped"

  [[ "$failed" -gt 0 ]] && {
    err "Templates failed: $failed"
    return 1
  }

  return 0
}

# ==================================================
# Git status & inspection
# ==================================================

## Show git status
gs() {
  git status
}

## Pretty git log
gl() {
  git log --oneline --graph --all --decorate
}

## Show recent HEAD positions (default: 20 reflog entries)
ghead() {
  local limit="${1:-20}"

  [[ "$limit" =~ ^[0-9]+$ ]] || {
    err "Usage: ghead [number-of-lines]"
    return 1
  }

  (( limit < 1 )) && {
    err "Line count must be >= 1"
    return 1
  }

  info "Recent HEAD positions (newest first)"
  log

  git reflog --date=relative | head -n "$limit" | awk '
  BEGIN {
    blue   = "\033[0;34m"
    green  = "\033[0;32m"
    yellow = "\033[0;33m"
    reset  = "\033[0m"

    msg_width = 45
  }

  function trunc(s, w) {
    return (length(s) > w) ? substr(s, 1, w - 1) "…" : s
  }

  {
    idx  = NR - 1
    hash = $1

    time = ""
    if (match($0, /HEAD@\{([^}]+)\}/, m)) {
      time = "(" m[1] ")"
    }

    line = $0
    sub(/^[a-f0-9]+ HEAD@\{[^}]+\}: /, "", line)

    if (line ~ /^commit:/) {
      sub(/^commit: /, "", line)
      msg = trunc(line, msg_width)

      printf "%sHEAD@{%d}%s  %s[COMMIT]%s  %-*s %s%s%s  %s\n",
        blue, idx, reset,
        green, reset,
        msg_width, msg,
        blue, time, reset,
        hash
    }
    else if (line ~ /^reset:/) {
      sub(/^reset: moving to /, "", line)
      msg = trunc("reset -> " line, msg_width)

      printf "%sHEAD@{%d}%s  %s[MOVE]%s  %-*s %s%s%s  %s\n",
        blue, idx, reset,
        yellow, reset,
        msg_width, msg,
        blue, time, reset,
        hash
    }
  }'

  log
  info "Tip: HEAD@{1} is usually the state before your last action"
  info "Restore with:"
  info "  grestorehead HEAD@{N}"
}

## Show git diff for file(s)
gdiff() {
  if ! groot; then
    return 1
  fi

  if [ $# -lt 1 ]; then
    err "Usage: gdiff <file>"
    return 1
  fi

  git diff HEAD -- "$@"
}

## Show staged git diff for file(s)
gdiffs() {
  if ! groot; then
    return 1
  fi

  if [ $# -lt 1 ]; then
    err "Usage: gdiffs <file>"
    return 1
  fi

  git diff --cached -- "$@"
}

## Show git diff between two commits for file(s)
gdiffc() {
  if ! groot; then
    return 1
  fi

  if [ $# -lt 2 ]; then
    err "Usage: gdiffc <commit1> <commit2> [file]"
    return 1
  fi

  local ref1="$1"
  local ref2="$2"
  shift 2

  git diff "$ref1" "$ref2" -- "$@"
}

## Show git diff between two branches for file(s)
gdiffb() {
  if ! groot; then
    return 1
  fi

  if [ $# -lt 2 ]; then
    err "Usage: gdiffb <branch1> <branch2> [file]"
    return 1
  fi

  local branch1="$1"
  local branch2="$2"
  shift 2

  git diff "$branch1" "$branch2" -- "$@"
}

## Show git diff against remote branch for file(s)
gdiffp() {
  if ! groot; then
    return 1
  fi

  if [ $# -lt 1 ]; then
    err "Usage: gdiffp <file>"
    return 1
  fi

  local branch
  branch=$(git branch --show-current 2>/dev/null)

  if [ -z "$branch" ]; then
    err "Detached HEAD — cannot diff against origin"
    return 1
  fi

  if ! git rev-parse --verify "origin/$branch" >/dev/null 2>&1; then
    err "Remote branch origin/$branch does not exist"
    return 1
  fi

  git fetch origin >/dev/null 2>&1 || {
    err "Failed to fetch origin"
    return 1
  }

  git diff "origin/$branch" -- "$@"
}

## Show commits pending promotion
gdiffpromote() {
  git log main..dev --oneline --decorate
}

## Show commits that would be promoted
whatwillpromote() {
  info "Commits that would be promoted:"
  git log main..dev --oneline --decorate
}

## Show active git SSH host for current repository
ghost() {
  local url host repo

  groot || return 1

  url=$(git remote get-url origin 2>/dev/null) || {
    err "No origin remote found"
    return 1
  }

  if [[ "$url" =~ ^git@([^:]+):(.+)\.git$ ]]; then
    host="${BASH_REMATCH[1]}"
    repo="${BASH_REMATCH[2]}"

    info "Git SSH host status"
    printf "  Host: %s\n" "$host"
    printf "  Repo: %s\n" "$repo"
    printf "  URL:  %s\n" "$url"
  else
    warn "Origin remote is not using SSH"
    printf "  URL: %s\n" "$url"
  fi
}

## Show git context (branch, upstream, ahead, behind)
gwhere() {
  local b upstream ahead behind
  b=$(git branch --show-current 2>/dev/null) || return 1
  upstream=$(git rev-parse --abbrev-ref @{u} 2>/dev/null || echo "-")
  ahead=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo 0)
  behind=$(git rev-list --count HEAD..@{u} 2>/dev/null || echo 0)

  info "Git context"
  printf "  Branch:   %s\n" "$b"
  printf "  Upstream: %s\n" "$upstream"
  printf "  Ahead:    %s\n" "$ahead"
  printf "  Behind:   %s\n" "$behind"
}

# ==================================================
# Git staging, committing
# ==================================================

## Stage all changes
ga() {
  git add .
  ok "All changes staged"
}

## Commit staged changes
gc() {
  if git diff --quiet && git diff --cached --quiet; then
    info "Nothing to commit"
    return 0
  fi

  ga || return 1

  if [[ $# -eq 0 ]]; then
    err "Commit message required"
    err "Usage:"
    err "  gc 'Subjects'"
    err "  gc 'Subject' 'Next paragraph' 'Another paragraph'"
    return 1
  fi

  local args=()
  args+=("-m" "$1")
  shift

  for arg in "$@"; do
    args+=("-m" "$arg")
  done

  git commit "${args[@]}" && ok "Changes committed"
}

## Amend last commit (message and/or content)
gca() {
  if [[ $# -eq 0 ]]; then
    err "Commit message required"
    err "Usage:"
    err "  gca 'New subject'"
    err "  gca 'New subject' 'Next paragraph' 'Another paragraph'"
    return 1
  fi

  local upstream
  upstream=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || true)

  if [[ -n "$upstream" ]] && git merge-base --is-ancestor HEAD "$upstream"; then
    warn "Last commit is already pushed to $upstream"
    warn "You will need to run:"
    warn "  git push --force-with-lease"
    warn "If this is a shared branch, consider making a new commit instead."
    log
  fi

  local args=()
  for arg in "$@"; do
    args+=("-m" "$arg")
  done

  git commit --amend "${args[@]}" && ok "Last commit amended"
}

gsquashlast() {
  if [[ -z "$1" ]]; then
    err "Usage: gsquashlast <number>"
    return 1
  fi

  local n="$1"
  if ! [[ "$n" =~ ^[0-9]+$ ]]; then
    err "Usage: gsquashlast <number>"
    return 1
  fi

  warn "Squashing last $n commits"
  git reset --soft "HEAD~$n" &&
  info "Commits squashed (soft)"
  info "Run gc to create the final commit"
}

# ==================================================
# Git working tree control
# ==================================================

## Restore unstaged changes
gr() {
  if git diff --quiet; then
    info "No unstaged changes to restore"
    return 0
  fi

  warn "This will discard ALL unstaged changes"
  confirm "Continue?" || return 1

  git restore .
  ok "Changes restored"
}

## Restore staged changes
grs() {
  if git diff --cached --quiet; then
    info "No staged changes to restore"
    return 0
  fi

  warn "This will unstage ALL staged changes"
  confirm "Continue?" || return 1

  git restore --staged .
  ok "Staged changes restored"
}

## Clean working tree (discard all uncommitted changes)
gcleanworktree() {
  warn "This will discard ALL uncommitted changes"
  confirm "Continue?" || return 1
  git reset --hard &&
  git clean -fd &&
  ok "Working tree cleaned"
}

## Stash all changes (including untracked)
gstash() {
  if [[ -z "$1" ]]; then
    warn "No stash message provided, using 'wip'"
  fi

  git stash push -u -m "${1:-wip}" &&
  ok "Changes stashed"
}

## Pop latest stash
gpop() {
  git stash pop &&
  ok "Stash applied"
}

## List stashes
gstashlist() {
  git stash list
}

# ==================================================
# Git sync & fetch
# ==================================================

## Pull with rebase
gpr() {
  git pull --rebase
}

## Prune deleted remote branches
gfp() {
  git fetch -p
}

## Abort current merge
gabort() {
  git merge --abort
}

# ==================================================
# Git recovery & repair - local
# ==================================================

## Undo last commit (soft)
gus() {
  [[ "${1:-}" == "--abort" ]] && { _abort_reset; return $?; }

  git rev-parse HEAD >/dev/null 2>&1 || {
    err "Repository has no commits"
    return 1
  }

  (( $(git rev-list --count HEAD) < 2 )) && {
    info "Nothing to undo"
    return 0
  }

  git reset --soft HEAD~1 &&
  ok "Last commit undone (soft)"
  info "Use 'gus --abort' to restore previous HEAD if needed"
}

## Undo last N commits (soft)
gusn() {
  local n="$1"

  [[ "$n" =~ ^[0-9]+$ ]] || {
    err "Usage: gusn <number>"
    return 1
  }

  (( n < 1 )) && {
    err "Number must be >= 1"
    return 1
  }

  git rev-parse HEAD >/dev/null 2>&1 || {
    err "Repository has no commits"
    return 1
  }

  local count
  count=$(git rev-list --count HEAD)

  (( count <= n )) && {
    err "Cannot undo $n commits (repository has $count)"
    return 1
  }

  git reset --soft "HEAD~$n" || return 1

  ok "Last $n commit(s) undone (soft)"
  info "Current state: all changes are staged"
  info "Next steps:"
  info "  - Run 'gc' to squash everything into one commit"
  info "  - Run 'grs' to unstage everything and re-commit selectively"
  info "Recovery:"
  info "  - Run 'ghead' to inspect previous HEAD positions"
  info "  - Run 'grestorehead HEAD@{N}' to restore a previous state"
}

## Undo last commit (hard)
guh() {
  [[ "${1:-}" == "--abort" ]] && {
    warn "guh --abort only works immediately after guh"
    _abort_reset
    return $?
  }

  git rev-parse HEAD >/dev/null 2>&1 || {
    err "Repository has no commits"
    return 1
  }

  (( $(git rev-list --count HEAD) < 2 )) && {
    info "Nothing to discard"
    return 0
  }

  warn "This will permanently discard the last commit"
  confirm "Continue?" || return 1

  git reset --hard HEAD~1 &&
  ok "Last commit discarded (hard)"
  info "Use 'guh --abort' immediately to restore previous HEAD if needed"
}

## Undo last N commits (hard)
guhn() {
  local n="$1"

  [[ "$n" =~ ^[0-9]+$ ]] || {
    err "Usage: guhn <number>"
    return 1
  }

  (( n < 1 )) && {
    err "Number must be >= 1"
    return 1
  }

  git rev-parse HEAD >/dev/null 2>&1 || {
    err "Repository has no commits"
    return 1
  }

  local count
  count=$(git rev-list --count HEAD)

  (( count <= n )) && {
    err "Cannot discard $n commits (repository has $count)"
    return 1
  }

  warn "This will permanently discard the last $n commit(s)"
  confirm "Continue?" || return 1

  git reset --hard "HEAD~$n" || return 1

  ok "Last $n commit(s) discarded (hard)"
  warn "Recovery is only possible via reflog"
  info "Recovery:"
  info "  - Run 'ghead' to inspect previous HEAD positions"
  info "  - Run 'grestorehead HEAD@{N}' to restore a previous state"
}

## Move latest local commit to another branch
gmove() {
  local target="$1"
  local current orig ahead

  current="$(git branch --show-current 2>/dev/null)" || {
    err "Not inside a git repository"
    return 1
  }

  if [[ -z "$target" ]]; then
    err "Usage: gmove <target-branch>"
    return 1
  fi

  if [[ "$current" == "$target" ]]; then
    err "Target branch is the current branch"
    return 1
  fi

  if ! git diff --quiet || ! git diff --cached --quiet; then
    err "Working tree is dirty"
    err "Commit or stash your changes before moving commits"
    return 1
  fi

  if ! git rev-parse HEAD~1 >/dev/null 2>&1; then
    err "No commit to move"
    return 1
  fi

  if git rev-parse @{u} >/dev/null 2>&1; then
    ahead=$(git rev-list --count @{u}..HEAD)
    if [[ "$ahead" -eq 0 ]]; then
      err "Latest commit is already pushed to upstream"
      return 1
    fi
  fi

  if [[ "$current" == "main" ]]; then
    warn "You are moving a commit off MAIN"
    warn "This is usually correct, but double-check intent"
    confirm "Continue?" || return 1
  fi

  info "Moving latest commit from '$current' -> '$target'"

  orig="$current"

  git switch "$target" || return 1

  if ! git cherry-pick "$orig@{0}"; then
    err "Cherry-pick failed — aborting"
    git cherry-pick --abort >/dev/null 2>&1 || true
    git switch "$orig" >/dev/null 2>&1 || true
    return 1
  fi

  git switch "$orig" || return 1
  git reset --hard HEAD~1 || return 1

  ok "Commit successfully moved to '$target'"
}

## Restore HEAD to a previous position
grestorehead() {
  [[ -z "$1" ]] && {
    err "Usage: grestorehead <reflog-id>"
    return 1
  }

  warn "Resetting HEAD to $1"
  confirm "Continue?" || return 1

  git reset --hard "$1" &&
  ok "HEAD restored"
}

# ==================================================
# Git recovery & repair - remote
# ==================================================

## Undo last remote commit (soft)
gurs() {
  local branch commit_count
  branch=$(git branch --show-current)

  [[ -z "$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null)" ]] && {
    err "No upstream branch set"
    return 1
  }

  commit_count=$(git rev-list --count HEAD)
  (( commit_count < 2 )) && {
    err "Cannot remove the initial (root) commit"
    return 1
  }

  _guard_main_rewrite || return 1

  info "Removing latest commit on '$branch' (soft)"
  git reset --soft HEAD~1 &&
  git push --force-with-lease &&
  ok "Latest commit removed (soft)"
}

## Undo last remote commit (hard)
gurh() {
  local branch commit_count
  branch=$(git branch --show-current)

  [[ -z "$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null)" ]] && {
    err "No upstream branch set"
    return 1
  }

  commit_count=$(git rev-list --count HEAD)
  (( commit_count < 2 )) && {
    err "Cannot remove the initial (root) commit"
    return 1
  }

  _guard_main_rewrite || return 1

  if [[ "$branch" != "main" ]]; then
    warn "This will permanently remove the latest commit on '$branch'"
    confirm "Continue?" || return 1
  fi

  git reset --hard HEAD~1 &&
  git push --force-with-lease &&
  ok "Latest commit permanently removed"
}

# ==================================================
# Git branch workflows
# ==================================================

## Sync dev with main
gsync() {
  git switch dev && git pull origin main --rebase
}

## Switch to branch, pull latest, show status
workon() {
  [[ -z "$1" ]] && {
    err "Usage: workon <branch>"
    return 1
  }

  if ! git diff --quiet || ! git diff --cached --quiet; then
    err "Working tree is dirty"
    err "Commit or stash your changes before switching branches"
    return 1
  fi

  info "Switching to branch '$1'"
  git switch "$1" || return 1

  info "Pulling latest changes"
  git pull || return 1

  git status
}

## Delete merged child branches of current branch
cleanupbranches() {
  local current
  current=$(git branch --show-current)

  info "Cleaning up merged branches of '$current'"

  git branch --merged | while read -r branch; do
    [[ "$branch" == "*"* ]] && continue
    [[ "$branch" == "$current" ]] && continue
    [[ "$branch" == "main" || "$branch" == "dev" ]] && continue

    base=$(git merge-base "$current" "$branch")
    if [[ "$base" == "$(git rev-parse "$current")" ]]; then
      info "Deleting branch '$branch'"
      git branch -d "$branch"
    fi
  done

  ok "Branch cleanup complete"
}

# ==================================================
# Git destructive sync
# ==================================================

## Force dev to match origin/main (destructive)
syncdev() {
  if [[ "$1" == "--abort" ]]; then
    local tag
    tag=$(git tag --list 'backup-dev-*' --sort=-creatordate | head -n1)

    if [[ -z "$tag" ]]; then
      err "No backup tag found to abort syncdev"
      return 1
    fi

    info "Aborting syncdev"
    info "Restoring dev from backup tag: $tag"

    git switch dev >/dev/null 2>&1 || return 1
    git reset --hard "$tag" || return 1

    ok "syncdev aborted successfully"
    return 0
  fi

  local current
  current=$(git branch --show-current)

  if ! git diff --quiet || ! git diff --cached --quiet; then
    err "Working tree is dirty"
    info "Commit or stash your changes first"
    return 1
  fi

  warn "This will RESET 'dev' to match 'origin/main'"
  warn "ALL local commits on dev will be LOST"

  if [[ -n "$(git log origin/main..dev --oneline 2>/dev/null)" ]]; then
    log
    info "Commits that will be removed:"
    git log origin/main..dev --oneline --decorate
    log
  else
    info "No local-only commits on dev"
  fi

  confirm "Continue?" || return 1

  info "Fetching origin"
  git fetch origin || return 1

  info "Switching to dev"
  git switch dev || return 1

  backup_tag="backup-dev-$(date +%Y%m%d-%H%M%S)"
  info "Creating backup tag: $backup_tag"
  git tag "$backup_tag" || return 1

  info "Resetting dev -> origin/main"
  git reset --hard origin/main || return 1

  if [[ "$current" != "dev" ]]; then
    git switch "$current" >/dev/null 2>&1 || \
      warn "Manual switch back to '$current' required"
  fi

  ok "dev is now in sync with origin/main"
  info "Backup tag created: $backup_tag"
  info "Use 'syncdev --abort' to restore this state"
}

# ==================================================
# Git release / promotion
# ==================================================

## Create annotated git tag for release
gtag() {
  if ! groot; then
    return 1
  fi

  if [ $# -lt 1 ]; then
    err "Usage: gtag <version> [message]"
    return 1
  fi

  local tag="$1"
  shift
  local msg="${*:-Release $tag}"

  git tag -a "$tag" -m "$msg" || return 1
  ok "Created tag $tag"
}

## Promote source -> target and create a release tag
promote() {
  set -uo pipefail

  local SRC_BRANCH="dev"
  local TARGET_BRANCH="main"

  if [[ $# -eq 1 ]]; then
    warn "Usage:"
    warn "  promote                    # promote dev -> main"
    warn "  promote <source> <target>  # promote source -> target"
    return 1
  elif [[ $# -eq 2 ]]; then
    SRC_BRANCH="$1"
    TARGET_BRANCH="$2"
  elif [[ $# -gt 2 ]]; then
    err "Too many arguments"
    warn "Usage: promote [<source> <target>]"
    return 1
  fi

  if [[ "$SRC_BRANCH" == "$TARGET_BRANCH" ]]; then
    err "Source and target branches must be different"
    return 1
  fi

  if ! _branch_exists "$SRC_BRANCH"; then
    err "Source branch does not exist: '$SRC_BRANCH'"
    warn "Available branches:"
    git branch -a
    return 1
  fi

  if ! _branch_exists "$TARGET_BRANCH"; then
    err "Target branch does not exist: '$TARGET_BRANCH'"
    warn "Available branches:"
    git branch -a
    return 1
  fi

  LOCKDIR="/tmp/git-promote.lock"
  if ! mkdir "$LOCKDIR" 2>/dev/null; then
    err "Another promote is already running"
    return 1
  fi

  original=$(git branch --show-current)

  cleanup() {
    git rebase --abort >/dev/null 2>&1 || true
    git merge --abort >/dev/null 2>&1 || true
    git switch "$original" >/dev/null 2>&1 || \
      warn "Manual switch to $original required"
    rmdir "$LOCKDIR" >/dev/null 2>&1 || true
  }

  trap cleanup RETURN
  trap 'err "Promote interrupted"; return 1' INT TERM

  if [[ "$original" != "$SRC_BRANCH" ]]; then
    err "Promote must be run from '$SRC_BRANCH' (current: $original)"
    return 1
  fi

  if ! git diff --quiet || ! git diff --cached --quiet; then
    err "Working tree is dirty — commit or stash first"
    return 1
  fi

  info "Fetching latest refs"
  git fetch origin || return 1

  if [[ -z "$(git log origin/$TARGET_BRANCH..$SRC_BRANCH --oneline)" ]]; then
    info "Nothing to promote ($SRC_BRANCH == $TARGET_BRANCH)"
    return 0
  fi

  info "Rebasing $SRC_BRANCH onto origin/$SRC_BRANCH"
  if ! git rebase "origin/$SRC_BRANCH"; then
    err "Rebase failed — resolve conflicts on $SRC_BRANCH"
    info "After resolving:"
    info "  git rebase --continue"
    info "  git push origin $SRC_BRANCH or promote"
    return 1
  fi

  info "Pushing $SRC_BRANCH"
  git push origin "$SRC_BRANCH" || return 1

  info "Switching to $TARGET_BRANCH"
  git switch "$TARGET_BRANCH" || return 1

  info "Pulling latest $TARGET_BRANCH"
  git pull origin "$TARGET_BRANCH" || return 1

  info "Fast-forwarding $TARGET_BRANCH -> $SRC_BRANCH"
  git merge --ff-only "$SRC_BRANCH" || return 1

  info "Pushing $TARGET_BRANCH"
  if ! git push origin "$TARGET_BRANCH"; then
    err "Push failed, rolling back local $TARGET_BRANCH"
    git reset --hard "origin/$TARGET_BRANCH"
    return 1
  fi

  info "Tagging promote"
  tag="promote-$SRC_BRANCH-to-$TARGET_BRANCH-$(date +%Y%m%d-%H%M%S)"
  git tag -a "$tag" -m "Promote $SRC_BRANCH -> $TARGET_BRANCH" || return 1
  git push origin "$tag" || return 1

  ok "Promote successful ($SRC_BRANCH -> $TARGET_BRANCH, tag: $tag)"
}
