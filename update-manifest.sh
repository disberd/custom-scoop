#!/usr/bin/env bash
# Point bucket/herdr.json at the newest win-* release of disberd/herdr.
set -euo pipefail

repo=disberd/herdr
asset=herdr-windows-x86_64.zip

read -r tag published < <(gh release list -R "$repo" --limit 100 \
  --json tagName,publishedAt \
  --jq '[.[] | select(.tagName | startswith("win-"))] | sort_by(.publishedAt) | last | "\(.tagName) \(.publishedAt)"')
hash="$(gh release download "$tag" -R "$repo" -p "$asset.sha256" -O - | cut -d' ' -f1)"
# Scoop updates when the version string changes; the publish time keeps it monotonic.
version="$(date -u -d "$published" +%Y.%m.%d.%H%M%S)"

jq -n --arg v "$version" --arg tag "$tag" --arg hash "$hash" \
  --arg url "https://github.com/$repo/releases/download/$tag/$asset" \
  --arg home "https://github.com/$repo" '{
    version: $v,
    description: ("herdr fork build " + $tag),
    homepage: $home,
    license: "Apache-2.0",
    architecture: { "64bit": { url: $url, hash: $hash } },
    bin: "herdr.exe"
  }' > bucket/herdr.json
echo "$tag -> $version"
