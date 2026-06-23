#!/usr/bin/env bash
set -euo pipefail

REPO="yanahauruk/yana-g-portfolio"
SITE_URL="https://yanahauruk.github.io/yana-g-portfolio/"
INTERVAL="${DEPLOY_POLL_INTERVAL:-10}"
MAX_ATTEMPTS="${DEPLOY_MAX_ATTEMPTS:-60}"
PUSH=true
MONITOR_ONLY=false

usage() {
  cat <<'EOF'
Deploy to GitHub Pages and wait until the site is live.

Usage:
  ./scripts/deploy.sh [options]

Options:
  --monitor-only   Skip git push; only poll Pages build status
  --no-push        Alias for --monitor-only
  --interval SEC   Poll interval in seconds (default: 10)
  --max-attempts N Stop after N polls (default: 60)
  -h, --help       Show this help

Examples:
  ./scripts/deploy.sh
  ./scripts/deploy.sh --monitor-only
  DEPLOY_POLL_INTERVAL=5 ./scripts/deploy.sh
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --monitor-only|--no-push)
      PUSH=false
      MONITOR_ONLY=true
      shift
      ;;
    --interval)
      INTERVAL="$2"
      shift 2
      ;;
    --max-attempts)
      MAX_ATTEMPTS="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if ! command -v gh >/dev/null 2>&1; then
  echo "Error: gh CLI is required. Install: https://cli.github.com/" >&2
  exit 1
fi

if ! gh auth status -h github.com >/dev/null 2>&1; then
  echo "Error: not logged in to GitHub. Run: gh auth login" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ "$PUSH" == true ]]; then
  if [[ -n "$(git status --porcelain)" ]]; then
    echo "Error: uncommitted changes. Commit first, then run this script." >&2
    git status --short >&2
    exit 1
  fi

  echo "Pushing main to origin..."
  git push origin main
  echo
fi

poll_pages_status() {
  gh api "repos/${REPO}/pages" --jq '.status // "unknown"' 2>/dev/null || echo "unknown"
}

echo "Monitoring GitHub Pages deployment for ${REPO}"
echo "Site: ${SITE_URL}"
echo "Polling every ${INTERVAL}s (max ${MAX_ATTEMPTS} attempts)"
echo

attempt=0
final_status=""

while (( attempt < MAX_ATTEMPTS )); do
  attempt=$((attempt + 1))
  page_status="$(poll_pages_status)"
  timestamp="$(date '+%H:%M:%S')"

  printf '%s  status=%s\n' "$timestamp" "$page_status"

  case "$page_status" in
    built)
      final_status="built"
      break
      ;;
    errored)
      echo
      echo "Deployment failed (status=errored)." >&2
      exit 1
      ;;
    building|"null"|unknown)
      sleep "$INTERVAL"
      ;;
    *)
      if [[ "$page_status" != "building" ]]; then
        final_status="$page_status"
        break
      fi
      sleep "$INTERVAL"
      ;;
  esac
done

if [[ "$final_status" != "built" ]]; then
  echo
  echo "Timed out waiting for deployment to finish." >&2
  exit 1
fi

if command -v curl >/dev/null 2>&1; then
  http_code="$(curl -s -o /dev/null -w '%{http_code}' -L "$SITE_URL")"
  if [[ "$http_code" == "200" ]]; then
    echo
    echo "Deployment complete at $(date '+%H:%M:%S')"
    echo "Live: ${SITE_URL} (HTTP ${http_code})"
  else
    echo
    echo "Pages status is built, but site returned HTTP ${http_code}." >&2
    echo "URL: ${SITE_URL}" >&2
    exit 1
  fi
else
  echo
  echo "Deployment complete at $(date '+%H:%M:%S')"
  echo "Live: ${SITE_URL}"
fi
