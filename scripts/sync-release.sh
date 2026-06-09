#!/usr/bin/env bash
# Sync exe from GeoFlux release to GeoFlux-release (GitHub + Gitee), update releases.json
# Usage: ./scripts/sync-release.sh [version]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/../.env" ]; then
  set -a; source "$SCRIPT_DIR/../.env"; set +a
fi

GH_REPO_SOURCE="${GH_REPO_SOURCE:-chainlinn/GeoFlux}"
GH_REPO_RELEASE="${GH_REPO_RELEASE:-chainlinn/GeoFlux-release}"
GITEE_REPO="${GITEE_REPO:-chainlinn/GeoFlux-release}"
TAG="${1:-$(gh release list -R "$GH_REPO_SOURCE" -L1 --json tagName -q '.[0].tagName')}"

echo "=== Syncing GeoFlux $TAG ==="

# ── download exe from GeoFlux release ──
TEMP_DIR="$(mktemp -d)"
gh release download "$TAG" -R "$GH_REPO_SOURCE" --pattern "GeoFlux*Setup*.exe" --dir "$TEMP_DIR"
EXE_FILE="$(echo "$TEMP_DIR"/GeoFlux*Setup*.exe)"
EXE_NAME="$(basename "$EXE_FILE")"
echo "  Downloaded: $EXE_NAME"

# ── metadata ──
VERSION="${TAG#v}"
SHA256="$(shasum -a 256 "$EXE_FILE" | awk '{print $1}')"
SIZE_BYTES="$(stat -f%z "$EXE_FILE" 2>/dev/null || stat -c%s "$EXE_FILE")"
SIZE_MB="$(( (SIZE_BYTES + 524288) / 1048576 ))MB"
DATE="$(date +%Y-%m-%d)"
URL_GH="https://github.com/$GH_REPO_RELEASE/releases/download/$TAG/$EXE_NAME"

# ── GitHub Release ──
if gh release view "$TAG" -R "$GH_REPO_RELEASE" > /dev/null 2>&1; then
  echo "  GitHub Release $TAG exists, uploading asset..."
  gh release upload "$TAG" "$EXE_FILE" -R "$GH_REPO_RELEASE" --clobber
else
  echo "  Creating GitHub Release $TAG..."
  gh release create "$TAG" "$EXE_FILE" -R "$GH_REPO_RELEASE" \
    --title "GeoFlux $VERSION" --notes "GeoFlux $VERSION 安装包"
fi
echo "  OK: GitHub $URL_GH"

# ── Gitee Release (optional) ──
URL_GITEE=""
if [ -n "${GITEE_TOKEN:-}" ] && [ -n "${GITEE_REPO:-}" ]; then
  echo "  --- Gitee ---"

  # Push tag to Gitee
  git -C "$SCRIPT_DIR/.." push gitee "$TAG" 2>/dev/null || {
    echo "  Warning: git push gitee failed, ensure 'gitee' remote is configured"
  }

  # Create release via API
  GITEE_API="https://gitee.com/api/v5/repos/$GITEE_REPO"
  RELEASE_JSON="$(curl -sS -X POST "$GITEE_API/releases" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $GITEE_TOKEN" \
    -d "{\"tag_name\":\"$TAG\",\"name\":\"GeoFlux $VERSION\",\"body\":\"GeoFlux $VERSION 安装包\"}")"

  RELEASE_ID="$(echo "$RELEASE_JSON" | jq -r '.id // empty')"
  if [ -z "$RELEASE_ID" ] || [ "$RELEASE_ID" = "null" ]; then
    echo "  Warning: Gitee release creation failed: $(echo "$RELEASE_JSON" | jq -r '.message // "unknown error"')"
  else
    # Upload attachment
    UPLOAD_JSON="$(curl -sS -X POST "$GITEE_API/releases/$RELEASE_ID/attach_files" \
      -H "Authorization: Bearer $GITEE_TOKEN" \
      -F "file=@$EXE_FILE")"

    URL_GITEE="$(echo "$UPLOAD_JSON" | jq -r '.browser_download_url // empty')"
    if [ -n "$URL_GITEE" ] && [ "$URL_GITEE" != "null" ]; then
      echo "  OK: Gitee $URL_GITEE"
    else
      echo "  Warning: Gitee upload failed: $(echo "$UPLOAD_JSON" | jq -r '.message // "unknown error"')"
    fi
  fi
else
  echo "  Gitee: skipped (GITEE_TOKEN or GITEE_REPO not set)"
fi

# ── update releases.json ──
RELEASES_JSON="$TEMP_DIR/releases.json"
REPO_DIR="$SCRIPT_DIR/.."

if [ -f "$REPO_DIR/releases.json" ]; then
  cp "$REPO_DIR/releases.json" "$RELEASES_JSON"
  echo "  Loaded existing releases.json"
else
  echo '[]' > "$RELEASES_JSON"
  echo "  No existing releases.json, starting fresh"
fi

if jq -e --arg v "$VERSION" '.[] | select(.version == $v)' "$RELEASES_JSON" > /dev/null 2>&1; then
  jq --arg v "$VERSION" --arg d "$DATE" --arg f "$EXE_NAME" --arg g "$URL_GH" --arg ee "$URL_GITEE" --arg s "$SIZE_MB" --arg h "$SHA256" \
    'map(if .version == $v then {version:$v, date:$d, file:$f, url_github:$g, url_gitee:$ee, size:$s, sha256:$h} else . end)' \
    "$RELEASES_JSON" > "$RELEASES_JSON.tmp"
else
  jq --arg v "$VERSION" --arg d "$DATE" --arg f "$EXE_NAME" --arg g "$URL_GH" --arg ee "$URL_GITEE" --arg s "$SIZE_MB" --arg h "$SHA256" \
    '[{version:$v, date:$d, file:$f, url_github:$g, url_gitee:$ee, size:$s, sha256:$h}] + .' \
    "$RELEASES_JSON" > "$RELEASES_JSON.tmp"
fi
mv "$RELEASES_JSON.tmp" "$RELEASES_JSON"

cp "$RELEASES_JSON" "$REPO_DIR/releases.json"
git -C "$REPO_DIR" add releases.json
git -C "$REPO_DIR" commit -m "chore: sync $TAG" || echo "  No changes to commit"
git -C "$REPO_DIR" push

echo "  OK: releases.json updated"
rm -rf "$TEMP_DIR"

echo "=== Done: GeoFlux $VERSION ==="
echo "  GitHub: $URL_GH"
[ -n "$URL_GITEE" ] && echo "  Gitee:  $URL_GITEE"
