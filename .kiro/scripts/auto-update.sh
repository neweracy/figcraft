#!/usr/bin/env bash
# Auto-update d:/code/figcraft from the `upstream` remote (storytold/figcraft).
#
#   auto-update.sh            quick checks, then runs detached in the background (safe for SessionStart)
#   auto-update.sh --dry-run  foreground: fetch only, print what it would do
#
# Never pushes, never resolves conflicts, never forces. A conflicting merge is aborted.
# Log: .kiro/logs/auto-update.log (the folder carries its own .gitignore, so it is never committed).

REPO_WIN="d:/code/figcraft"
MODE="start"
case "${1:-}" in
  --dry-run) MODE="dry" ;;
  --run) MODE="run" ;; # internal: the detached child
esac

# Git Bash path for the repo (/d/code/figcraft); fall back if cygpath is missing.
if command -v cygpath >/dev/null 2>&1; then REPO="$(cygpath -u "$REPO_WIN")"; else REPO="/d/code/figcraft"; fi
SELF="$REPO/.kiro/scripts/auto-update.sh"
LOGDIR="$REPO/.kiro/logs"
LOG="$LOGDIR/auto-update.log"
LOCK="$LOGDIR/auto-update.lock"

# Runs from any session's cwd (the MCP server is registered globally); all git work happens in $REPO.
cd "$REPO" 2>/dev/null || exit 0

command -v git >/dev/null 2>&1 || exit 0
git remote get-url upstream >/dev/null 2>&1 || exit 0

mkdir -p "$LOGDIR" 2>/dev/null || exit 0
[ -f "$LOGDIR/.gitignore" ] || printf '*\n' >"$LOGDIR/.gitignore"

log() { printf '%s [%s] %s\n' "$(date '+%F %T')" "$MODE" "$*" >>"$LOG"; }
say() { printf '%s\n' "$*"; }

# Default mode: hand off to a detached child and return immediately.
if [ "$MODE" = "start" ]; then
  nohup bash "$SELF" --run </dev/null >/dev/null 2>&1 &
  disown 2>/dev/null || true
  say "figcraft auto-update running in background (log: .kiro/logs/auto-update.log)"
  exit 0
fi

export GIT_TERMINAL_PROMPT=0
export PATH="${CARGO_HOME:-$HOME/.cargo}/bin:$HOME/.cargo/bin:$PATH"
# A default release build runs this machine out of Windows commit memory (os error 1455): LTO off + 2 jobs works.
export CARGO_PROFILE_RELEASE_LTO=off CARGO_PROFILE_RELEASE_DEBUG=0

if [ "$MODE" = "run" ]; then
  # Lock: mkdir is atomic. A lock older than 3 hours is treated as stale.
  if ! mkdir "$LOCK" 2>/dev/null; then
    if [ -n "$(find "$LOCK" -maxdepth 0 -mmin +180 2>/dev/null)" ]; then
      rmdir "$LOCK" 2>/dev/null && mkdir "$LOCK" 2>/dev/null || { log "lock busy, skipping"; exit 0; }
      log "removed stale lock"
    else
      log "another run holds the lock, skipping"
      exit 0
    fi
  fi
  trap 'rmdir "$LOCK" 2>/dev/null' EXIT
fi

log "start"
if ! timeout 120 git fetch --quiet upstream >>"$LOG" 2>&1; then
  log "git fetch upstream failed or timed out"
  [ "$MODE" = "dry" ] && say "dry-run: fetch failed (see log)"
  exit 0
fi

BEHIND="$(git rev-list --count HEAD..upstream/main 2>/dev/null || echo 0)"
if [ "${BEHIND:-0}" -eq 0 ]; then
  log "up to date with upstream/main"
  [ "$MODE" = "dry" ] && say "dry-run: already up to date with upstream/main"
  exit 0
fi

# Refusal checks.
REFUSE=""
BRANCH="$(git symbolic-ref --short -q HEAD || true)"
if [ "$BRANCH" != "main" ]; then
  REFUSE="HEAD is not on main (on '${BRANCH:-detached}')"
elif [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  REFUSE="working tree is dirty"
else
  for p in MERGE_HEAD rebase-merge rebase-apply CHERRY_PICK_HEAD REVERT_HEAD; do
    if [ -e "$(git rev-parse --git-path "$p")" ]; then REFUSE="a merge/rebase/cherry-pick is in progress ($p)"; break; fi
  done
fi

if [ -n "$REFUSE" ]; then
  log "refused: $REFUSE ($BEHIND new upstream commit(s) not merged)"
  if [ "$MODE" = "dry" ]; then say "dry-run: $BEHIND new upstream commit(s); would refuse: $REFUSE"; else say "figcraft auto-update skipped: $REFUSE"; fi
  exit 0
fi

if git merge-base --is-ancestor HEAD upstream/main; then HOW="fast-forward"; else HOW="merge commit"; fi
if [ "$MODE" = "dry" ]; then
  say "dry-run: $BEHIND new upstream commit(s); would $HOW upstream/main, then cargo build --release -p figcraft-cli --locked -j 2"
  exit 0
fi

log "merging $BEHIND commit(s) via $HOW"
if [ "$HOW" = "fast-forward" ]; then
  git merge --ff-only upstream/main >>"$LOG" 2>&1
else
  git merge --no-edit upstream/main >>"$LOG" 2>&1
fi
if [ $? -ne 0 ]; then
  git merge --abort >>"$LOG" 2>&1
  log "merge failed (conflict or error); aborted, tree restored; resolve manually"
  say "figcraft auto-update: merge conflict, aborted (see log)"
  exit 0
fi
log "merged OK, HEAD now $(git rev-parse --short HEAD)"

if timeout 3600 cargo build --release -p figcraft-cli --locked -j 2 >>"$LOG" 2>&1; then
  log "cargo build OK"
  say "figcraft updated ($BEHIND commits) and rebuilt"
else
  log "cargo build FAILED (merge is kept; see output above)"
  say "figcraft merged but rebuild failed (see log)"
fi
log "done (not pushed; push to the fork manually)"
exit 0
