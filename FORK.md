# Fork notes (xorguy/docker-remote-api-tls)

Fork of [kekru/docker-remote-api-tls](https://github.com/kekru/docker-remote-api-tls).
Fork-only changes live in separate files where possible (this file, the two
workflows below) so upstream merges stay conflict-free.

## Image

Multi-arch image (`linux/amd64`, `linux/arm64`) on Docker Hub, published with
`publish-remote.sh` (see below):

```
xorguy/docker-remote-api-tls:latest   # last published release
xorguy/docker-remote-api-tls:0.6.0    # release X.Y.Z
```

Each release is built with `--pull --no-cache` (fresh base + `apk upgrade`) and
carries SLSA provenance and SBOM attestations:

```bash
docker buildx imagetools inspect xorguy/docker-remote-api-tls:latest --format '{{ json .SBOM }}'
```

Docker picks the matching architecture automatically on the remote host:

```yml
services:
  remote-api:
    image: xorguy/docker-remote-api-tls:latest
    ports:
     - 2376:443
    volumes:
     - <local cert dir>:/data/certs:ro
     - /var/run/docker.sock:/var/run/docker.sock:ro
```

## Release from local network host (Docker Hub)

`publish-remote.sh` builds on `pi@172.26.30.167` (already `docker login`'d) and pushes
`xorguy/docker-remote-api-tls:<version>` + `:latest` for amd64 and arm64:

```bash
git push origin master      # remote host builds what is on the fork, not local files
./publish-remote.sh         # prompts for release number, e.g. 0.6.0
./publish-remote.sh 0.6.0   # or non-interactive version
```

On the host it clones/updates `~/docker-remote-api-tls` (hard reset to `origin/master`),
registers QEMU (`tonistiigi/binfmt`) for the non-native arch if missing, creates a
`docker-container` buildx builder `multiarch` once, then `buildx build --push`.
Override defaults via env: `REMOTE_HOST`, `IMAGE`, `BRANCH`, `PLATFORMS`, `BUILDER`,
`SSH_OPTS` (extra ssh arguments, e.g. `-p 2220 -i ~/.ssh/key`).

## Workflows

| Workflow | Trigger | Does |
|---|---|---|
| `run-tests` (`push.yml`, upstream) | push | integration tests |
| Dependabot (`.github/dependabot.yml`) | weekly | PRs for nginx stable / test images, actions, maven test deps |
| `docker-publish.yml` | **disabled** (`gh workflow disable docker-publish.yml`) | buildx + QEMU build for amd64/arm64, push to GHCR |
| `sync-upstream.yml` | daily 04:17 UTC, manual | merge `upstream/master`, mirror new `v*` tags (no image build) |

Images are published from the local host with `publish-remote.sh`.
Re-enable GHCR builds with `gh workflow enable docker-publish.yml`.

## One-time GitHub setup

1. **Enable Actions** on the fork: Actions tab → "I understand my workflows, go ahead and enable them".
   Scheduled workflows on forks also need enabling once (sync-upstream → Enable workflow).
2. **Workflow permissions**: Settings → Actions → General → Workflow permissions →
   "Read and write permissions".
3. **Package visibility**: after the first publish, GHCR package is private.
   Profile → Packages → docker-remote-api-tls → Package settings → Change visibility → Public
   (or `docker login ghcr.io` on the remote host with a PAT having `read:packages`).
4. *(Optional)* **SYNC_TOKEN** secret: fine-grained PAT, this repo only,
   Contents + Workflows read/write. Needed only when upstream changes `.github/workflows/*`
   (GITHUB_TOKEN may not push workflow files).

## Manual sync (local)

```bash
git fetch upstream --tags
git merge upstream/master        # resolve conflicts if any (e.g. Dockerfile nginx version)
git push origin master --tags
```

Remotes: `origin` = this fork, `upstream` = kekru (push disabled).

## Fork changes

- nginx base `1.26.2-alpine` → `1.30.6-alpine` (current stable), `apk upgrade` at build time
- TLS hardening: TLSv1.2/1.3 only, ECDHE AEAD ciphers, no session tickets, 10s handshake timeout;
  `proxy_timeout 1h` so idle `docker logs -f` / `attach` are not cut after 10m
- cert generation: CA password passed via env (not argv, not in `DEBUG` trace), quoted paths;
  CA `basicConstraints`/`keyUsage`, server `serverAuth` and client `clientAuth` key usages
- client key stays `0444` (upstream behavior) — protect the certs dir on the host
- actions pinned to commit SHAs, Dependabot, test image on Java 21 / docker 29 CLI
- multi-arch Docker Hub publishing (`publish-remote.sh`) with provenance + SBOM, upstream auto-sync
