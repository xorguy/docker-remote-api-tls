#!/usr/bin/env bash
# Build the image for linux/amd64 + linux/arm64 on a remote Docker host and
# push it to Docker Hub as <IMAGE>:<version> and <IMAGE>:latest.
#
# The remote host pulls the latest commit of BRANCH from the fork itself, so
# push your changes to the fork before running this.
#
# Usage: ./publish-remote.sh [version]      e.g. ./publish-remote.sh 0.6.0
# Overrides via env: REMOTE_HOST IMAGE REPO_URL BRANCH REMOTE_DIR PLATFORMS BUILDER
set -euo pipefail

REMOTE_HOST="${REMOTE_HOST:-pi@172.26.30.167}"
IMAGE="${IMAGE:-xorguy/docker-remote-api-tls}"
REPO_URL="${REPO_URL:-https://github.com/xorguy/docker-remote-api-tls.git}"
BRANCH="${BRANCH:-master}"
REMOTE_DIR="${REMOTE_DIR:-docker-remote-api-tls}"   # build checkout, relative to remote $HOME
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"
BUILDER="${BUILDER:-multiarch}"

# Warn about local commits the remote build would not see
if git rev-parse --git-dir >/dev/null 2>&1; then
  git fetch -q origin "$BRANCH" 2>/dev/null || true
  ahead=$(git rev-list --count "origin/$BRANCH..HEAD" 2>/dev/null || echo 0)
  if [ "$ahead" -gt 0 ]; then
    echo "WARNING: $ahead local commit(s) not pushed to origin/$BRANCH; they will NOT be in the image."
  fi
fi

last_published=$(curl -fsS "https://hub.docker.com/v2/repositories/$IMAGE/tags?page_size=100" 2>/dev/null \
  | grep -oE '"name":"v?[0-9]+\.[0-9]+\.[0-9]+"' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | sort -V | tail -n1 || true)

version="${1:-}"
if [ -z "$version" ]; then
  read -rp "Release number to publish (last published: ${last_published:-none}): " version
fi
version="${version#v}"
if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Invalid version '$version' (expected X.Y.Z)" >&2
  exit 1
fi

if curl -fsS -o /dev/null "https://hub.docker.com/v2/repositories/$IMAGE/tags/$version" 2>/dev/null; then
  read -rp "$IMAGE:$version already exists on Docker Hub. Overwrite? [y/N] " ok
  [[ "$ok" =~ ^[Yy]$ ]] || exit 1
fi

echo
echo "  host:      $REMOTE_HOST"
echo "  source:    $REPO_URL ($BRANCH)"
echo "  platforms: $PLATFORMS"
echo "  tags:      $IMAGE:$version, $IMAGE:latest"
read -rp "Publish? [y/N] " ok
[[ "$ok" =~ ^[Yy]$ ]] || exit 1

args=$(printf '%q ' "$REPO_URL" "$BRANCH" "$REMOTE_DIR" "$IMAGE" "$version" "$PLATFORMS" "$BUILDER")

ssh -T "$REMOTE_HOST" "bash -s -- $args" <<'REMOTE'
set -euo pipefail
REPO_URL=$1 BRANCH=$2 REMOTE_DIR=$3 IMAGE=$4 VERSION=$5 PLATFORMS=$6 BUILDER=$7

cd "$HOME"
if [ -d "$REMOTE_DIR/.git" ]; then
  echo "==> Updating $REMOTE_DIR"
  git -C "$REMOTE_DIR" remote set-url origin "$REPO_URL"
  git -C "$REMOTE_DIR" fetch --prune --tags origin
  git -C "$REMOTE_DIR" checkout -q "$BRANCH"
  git -C "$REMOTE_DIR" reset -q --hard "origin/$BRANCH"
else
  echo "==> Cloning $REPO_URL"
  git clone -q --branch "$BRANCH" "$REPO_URL" "$REMOTE_DIR"
fi
cd "$REMOTE_DIR"
REVISION=$(git rev-parse HEAD)
echo "    at $(git log -1 --format='%h %s')"

# QEMU emulation for the non-native platform (registration is lost on reboot)
native=$(uname -m)
need=""
case "$PLATFORMS" in *linux/amd64*) [ "$native" = x86_64 ]  || [ -e /proc/sys/fs/binfmt_misc/qemu-x86_64 ]  || need="$need amd64";; esac
case "$PLATFORMS" in *linux/arm64*) [ "$native" = aarch64 ] || [ -e /proc/sys/fs/binfmt_misc/qemu-aarch64 ] || need="$need arm64";; esac
if [ -n "$need" ]; then
  echo "==> Installing QEMU emulators:$need"
  docker run --privileged --rm tonistiigi/binfmt --install $(echo $need | tr ' ' ',')
fi

# Multi-platform push needs a docker-container buildx builder
if ! docker buildx inspect "$BUILDER" >/dev/null 2>&1; then
  echo "==> Creating buildx builder $BUILDER"
  docker buildx create --name "$BUILDER" --driver docker-container >/dev/null
fi
docker buildx inspect --bootstrap "$BUILDER" >/dev/null

echo "==> Building $PLATFORMS and pushing $IMAGE:$VERSION, $IMAGE:latest"
docker buildx build \
  --builder "$BUILDER" \
  --platform "$PLATFORMS" \
  --tag "$IMAGE:$VERSION" \
  --tag "$IMAGE:latest" \
  --label "org.opencontainers.image.version=$VERSION" \
  --label "org.opencontainers.image.revision=$REVISION" \
  --label "org.opencontainers.image.source=${REPO_URL%.git}" \
  --push \
  .

echo "==> Published manifest"
docker buildx imagetools inspect "$IMAGE:$VERSION" | grep -E '^(Name|Digest):|Platform:'
REMOTE

echo
echo "Done: $IMAGE:$version and $IMAGE:latest ($PLATFORMS)"
