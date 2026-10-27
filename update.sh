#!/usr/bin/env bash
# Point the bucket manifests at the newest releases of disberd/herdr and disberd/ferry.
set -euo pipefail

update_herdr() {
  local repo=disberd/herdr asset=herdr-windows-x86_64.zip tag published hash version
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
  echo "herdr: $tag -> $version"
}

update_ferry() {
  local repo=disberd/ferry asset=ferry-windows-x86_64.exe tag hash
  if ! tag="$(gh release view -R "$repo" --json tagName --jq .tagName 2>/dev/null)"; then
    echo "ferry: no release"
    return
  fi
  hash="$(gh release download "$tag" -R "$repo" -p SHA256SUMS -O - | awk -v a="$asset" '$2 == a { print $1 }')"
  [ -n "$hash" ] || { echo "ferry: $tag has no $asset in SHA256SUMS" >&2; exit 1; }

  jq -n --arg v "${tag#v}" --arg hash "$hash" \
    --arg url "https://github.com/$repo/releases/download/$tag/$asset#/ferry.exe" \
    --arg home "https://github.com/$repo" '{
      version: $v,
      description: "Screenshots and files between a Windows Workstation and a Linux Remote over SSH",
      homepage: $home,
      license: "Apache-2.0",
      architecture: { "64bit": { url: $url, hash: $hash } },
      bin: "ferry.exe"
    }' > bucket/ferry.json
  echo "ferry: $tag"
}

update_herdr
update_ferry
