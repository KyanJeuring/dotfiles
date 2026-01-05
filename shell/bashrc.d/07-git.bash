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

# ==================================================
# Git helpers
# ==================================================

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
  root || return 1

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
  root || return 1

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
git-host-status() {
  local url host repo

  root || return 1

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

# ==================================================
# Git staging, committing & restore
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
    git commit && ok "Changes committed"
  else
    git commit -m "$*" && ok "Changes committed"
  fi
}

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
# Git undo — local commits
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

# ==================================================
# Git undo — remote commits (DANGEROUS)
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
    info "Commit or stash your changes before switching branches"
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

  info "Resetting dev → origin/main"
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

## Promote dev → main and create a release tag
promote() {
  set -uo pipefail

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
  trap cleanup EXIT
  trap 'err "Promote interrupted"; return 1' INT TERM

  if [[ "$original" != "dev" ]]; then
    err "Promote must be run from dev (current: $original)"
    return 1
  fi

  if ! git diff --quiet || ! git diff --cached --quiet; then
    err "Working tree is dirty — commit or stash first"
    return 1
  fi

  info "Fetching latest refs"
  git fetch origin || return 1

  if [[ -z "$(git log origin/main..dev --oneline)" ]]; then
    info "Nothing to promote (dev == main)"
    return 0
  fi

  info "Rebasing dev onto origin/dev"
  if ! git rebase origin/dev; then
    err "Rebase failed — resolve conflicts on dev"
    info "After resolving:"
    info "  git rebase --continue"
    info "  git push origin dev or promote"
    return 1
  fi

  info "Pushing dev"
  git push origin dev || return 1

  info "Switching to main"
  git switch main || return 1

  info "Pulling latest main"
  git pull origin main || return 1

  info "Fast-forwarding main → dev"
  git merge --ff-only dev || return 1

  info "Pushing main"
  if ! git push origin main; then
    err "Push failed, rolling back local main"
    git reset --hard origin/main
    return 1
  fi

  info "Tagging promote"
  tag="promote-$(date +%Y%m%d-%H%M%S)"
  git tag -a "$tag" -m "Production promote" || return 1
  git push origin "$tag" || return 1

  ok "Promote successful ($tag)"
}
