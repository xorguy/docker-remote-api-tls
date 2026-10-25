# Fork notes (xorguy/docker-remote-api-tls)

Fork of [kekru/docker-remote-api-tls](https://github.com/kekru/docker-remote-api-tls).
Fork-only changes live in separate files where possible (this file, the two
workflows below) so upstream merges stay conflict-free.

## Image

Multi-arch image (`linux/amd64`, `linux/arm64`) on GHCR:

```
ghcr.io/xorguy/docker-remote-api-tls:latest   # highest upstream/fork release tag
ghcr.io/xorguy/docker-remote-api-tls:0.5.0    # vX.Y.Z tags -> X.Y.Z and X.Y
ghcr.io/xorguy/docker-remote-api-tls:edge     # current master
ghcr.io/xorguy/docker-remote-api-tls:sha-abc1234
```

Docker picks the matching architecture automatically on the remote host:

```yml
services:
  remote-api:
    image: ghcr.io/xorguy/docker-remote-api-tls:edge
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
Override defaults via env: `REMOTE_HOST`, `IMAGE`, `BRANCH`, `PLATFORMS`, `BUILDER`.

## Workflows

| Workflow | Trigger | Does |
|---|---|---|
| `run-tests` (`push.yml`, upstream) | push | integration tests |
| `docker-publish.yml` | push to master, tag `v*`, manual | buildx + QEMU build for amd64/arm64, push to GHCR |
| `sync-upstream.yml` | daily 04:17 UTC, manual | merge `upstream/master`, mirror new `v*` tags, trigger builds |

Build any ref manually: Actions → docker-publish → Run workflow → `ref` = `v0.5.0`.

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

- nginx base `1.26.2-alpine` → `1.30.6-alpine` (current stable)
- multi-arch GHCR publishing + upstream auto-sync workflows
