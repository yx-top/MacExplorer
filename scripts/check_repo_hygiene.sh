#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Missing required command: $1" >&2
        exit 1
    fi
}

require_command git
require_command rg

oauth_marker="oauth2"
access_token_marker="access_token"
url_credential_pattern='://[^/\s:@]+:[^/\s@]+@'
private_key_pattern='BEGIN (RSA |OPENSSH |EC |DSA )?PRIVATE KEY'
github_token_pattern='gh[pousr]_[A-Za-z0-9_]{30,}'
github_fine_grained_token_pattern='github_pat_[A-Za-z0-9_]+'
remote_secret_pattern="(${oauth_marker}|${access_token_marker}|${url_credential_pattern}|${github_token_pattern}|${github_fine_grained_token_pattern})"
file_secret_pattern="(${oauth_marker}:|${access_token_marker}=|${url_credential_pattern}|${private_key_pattern}|${github_token_pattern}|${github_fine_grained_token_pattern})"

echo "==> Checking Git repository"
git rev-parse --is-inside-work-tree >/dev/null

echo "==> Checking remotes for embedded credentials"
remote_secret_matches="$(git remote -v | rg -i "$remote_secret_pattern" || true)"
if [[ -n "$remote_secret_matches" ]]; then
    printf "%s\n" "$remote_secret_matches" >&2
    echo "A Git remote appears to contain embedded credentials. Use a clean remote URL and provide credentials at push time." >&2
    exit 1
fi

echo "==> Checking tracked build artifacts"
tracked_artifacts="$(git ls-files | rg '(^|/)(\.DS_Store$|\.build/|dist/|\.swiftpm/|DerivedData/|xcuserdata/|[^/]+\.xcuserstate$)' || true)"
if [[ -n "$tracked_artifacts" ]]; then
    printf "%s\n" "$tracked_artifacts" >&2
    echo "Build artifacts or local user files are tracked by Git. Remove them from the index before releasing." >&2
    exit 1
fi

echo "==> Checking tracked release artifacts"
app_version="$(awk -F= '$1 == "APP_VERSION" { print $2 }' VERSION)"
build_number="$(awk -F= '$1 == "BUILD_NUMBER" { print $2 }' VERSION)"
allowed_release_artifact_pattern="^release-artifacts/(README\\.md|MacExplorer-${app_version}-${build_number}-macos(-x86_64|-universal)?\\.dmg(\\.sha256)?)$"
tracked_release_artifacts="$(git ls-files release-artifacts || true)"
stale_release_artifacts="$(printf "%s\n" "$tracked_release_artifacts" | rg -v "$allowed_release_artifact_pattern" || true)"
if [[ -n "$stale_release_artifacts" ]]; then
    printf "%s\n" "$stale_release_artifacts" >&2
    echo "Only the latest DMG installers and SHA256 files should be tracked in release-artifacts/." >&2
    exit 1
fi

echo "==> Checking ignored local artifacts"
for local_artifact in .DS_Store .build .swiftpm dist DerivedData; do
    if [[ -e "$local_artifact" ]] && ! git check-ignore -q "$local_artifact"; then
        echo "$local_artifact exists but is not ignored by Git." >&2
        exit 1
    fi
done

echo "==> Scanning project files for credential-shaped strings"
secret_matches="$(rg -n -i "$file_secret_pattern" --hidden -g '!/.git/**' -g '!/.build/**' -g '!dist/**' . || true)"
if [[ -n "$secret_matches" ]]; then
    printf "%s\n" "$secret_matches" >&2
    echo "Potential credential material found in project files. Remove it before committing or releasing." >&2
    exit 1
fi

echo "Repository hygiene check passed."
