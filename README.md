# homebrew-tap

Homebrew tap for [Flexolumens](https://github.com/flexolumens) tools.

## flx — K230 Platform CLI

`flx` is the CLI for the Kendryte K230 edge-AI development platform. It handles
project scaffolding, cross-compilation, WiFi/USB flashing, and library dependency
management.

### Prerequisites

`flx` is distributed as a private GitHub release asset. You need a GitHub token
with **Contents: read** access on `flexolumens/k230-platform` to download it.

Options:

- **GitHub CLI (recommended):** `gh auth login` — Homebrew picks up the token automatically.
- **Fine-grained PAT:** Create a fine-grained PAT scoped to the `flexolumens/k230-platform`
  repository with **Contents: read-only** permission. Pass it as `HOMEBREW_GITHUB_API_TOKEN`.

### Install

```sh
brew tap oven-sh/bun
brew tap flexolumens/tap
HOMEBREW_GITHUB_API_TOKEN="$(gh auth token)" brew install flexolumens/tap/flx
```

If you already ran `gh auth login`, Homebrew resolves the token automatically and you
can omit the `HOMEBREW_GITHUB_API_TOKEN` prefix.

### Upgrade

```sh
HOMEBREW_GITHUB_API_TOKEN="$(gh auth token)" brew upgrade flexolumens/tap/flx
```

### Verify

```sh
flx --version
brew test flx
```

### After Install — CLI Token Setup

`flx` also needs a token at runtime to clone private library dependencies during
`flx install`. Run once after install:

```sh
flx auth --github-token <your-token>
```

---

## Maintainer — bumping the formula for a new release

Edit `Formula/flx.rb` and update three lines:

```ruby
url "https://github.com/flexolumens/k230-platform/releases/download/vX.Y.Z/flx-vX.Y.Z.tar.gz", ...
sha256 "<new-sha256>"
version "X.Y.Z"
```

Compute the sha256 of the downloaded tarball:

```sh
HOMEBREW_GITHUB_API_TOKEN="$(gh auth token)" \
  curl -fLo /tmp/flx-vX.Y.Z.tar.gz \
    -H "Authorization: token $(gh auth token)" \
    -H "Accept: application/octet-stream" \
    "$(gh api repos/flexolumens/k230-platform/releases/tags/vX.Y.Z \
        --jq '.assets[] | select(.name=="flx-vX.Y.Z.tar.gz") | .url')"
shasum -a 256 /tmp/flx-vX.Y.Z.tar.gz
```

An automated GitHub Actions workflow (`bump-formula`) will handle this per release
once wired up — the above is the manual fallback.
