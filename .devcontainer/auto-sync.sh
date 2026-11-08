#!/usr/bin/env bash
set -u

if [[ "${1:-}" != "--watch" ]]; then
  script_path="$(readlink -f "$0")"
  nohup bash "$script_path" --watch >>/tmp/eagler-auto-sync.log 2>&1 </dev/null &
  exit 0
fi

exec 9>/tmp/eagler-auto-sync.lock
flock -n 9 || exit 0

branch="$(git branch --show-current)"
if [[ -z "$branch" ]]; then
  printf '%s No current branch; auto-sync stopped.\n' "$(date -Is)"
  exit 1
fi

push_pending=0
if git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
  ahead="$(git rev-list --count "origin/$branch..HEAD" 2>/dev/null || printf '0')"
  if [[ "$ahead" -gt 0 ]]; then
    push_pending=1
  fi
fi

last_hash=""
changed_at="$(date +%s)"

while true; do
  if git add -A; then
    staged_hash="$(git diff --cached --binary HEAD | sha256sum | awk '{print $1}')"
    now="$(date +%s)"

    if [[ "$staged_hash" != "$last_hash" ]]; then
      last_hash="$staged_hash"
      changed_at="$now"
    elif ! git diff --cached --quiet HEAD && (( now - changed_at >= 1 )); then
      if git commit -m "Auto-sync: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"; then
        printf '%s Changes committed on %s.\n' "$(date -Is)" "$branch"
        push_pending=1
      else
        printf '%s Commit failed; will retry.\n' "$(date -Is)"
      fi
      last_hash=""
      changed_at="$now"
    fi
  else
    printf '%s git add failed; will retry.\n' "$(date -Is)"
  fi

  if [[ "$push_pending" -eq 1 ]]; then
    if git push origin "$branch"; then
      printf '%s Pushed %s to origin.\n' "$(date -Is)" "$branch"
      push_pending=0
    else
      printf '%s Push failed; will retry.\n' "$(date -Is)"
    fi
  fi

  sleep 1
done
