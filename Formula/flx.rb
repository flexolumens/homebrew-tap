# typed: false
# frozen_string_literal: true

require "utils/github/api"

# Download strategy for private GitHub release assets.
# Resolves the numeric asset ID from the release metadata, then fetches
# the asset binary using the GitHub API (Accept: application/octet-stream).
class GitHubPrivateAssetDownloadStrategy < CurlDownloadStrategy
  def initialize(url, name, version, **meta)
    super
    # Parse owner/repo/tag/filename from the release asset URL:
    #   https://github.com/<owner>/<repo>/releases/download/<tag>/<filename>
    @url = url
    @owner, @repo, @tag, @filename = url.match(
      %r{github\.com/([^/]+)/([^/]+)/releases/download/([^/]+)/(.+)$}
    )&.captures
  end

  def _fetch(url:, resolved_url:, timeout:)
    # Resolve the asset ID from the release metadata.
    release = GitHub::API.open_rest(
      "https://api.github.com/repos/#{@owner}/#{@repo}/releases/tags/#{@tag}",
    )
    asset = release.fetch("assets", []).find { |a| a["name"] == @filename }
    raise CurlDownloadStrategyError, "Asset #{@filename} not found in release #{@tag}" unless asset

    asset_id = asset["id"]
    asset_url = "https://api.github.com/repos/#{@owner}/#{@repo}/releases/assets/#{asset_id}"

    token = GitHub::API.credentials
    extra_args = [
      "--header", "Accept: application/octet-stream",
      "--header", "X-GitHub-Api-Version: 2022-11-28",
    ]
    extra_args += ["--header", "Authorization: token #{token}"] if token

    curl_download asset_url, *extra_args, to: temporary_path, timeout: timeout
  end
end

class Flx < Formula
  desc "CLI for the Kendryte K230 edge-AI development platform"
  homepage "https://github.com/flexolumens/k230-platform"
  url "https://github.com/flexolumens/k230-platform/releases/download/v0.4.0/flx-v0.4.0.tar.gz",
      using: GitHubPrivateAssetDownloadStrategy
  sha256 "504062220dee8155d140fc1e8b9a7cbfa63ac4ca242292f892e1400746ef0b4c"
  version "0.4.0"
  license "Nonstandard"

  depends_on "oven-sh/bun/bun"

  def install
    # Stage everything into libexec so the bun source tree lives under a stable path.
    libexec.install Dir["*"]

    # Install node_modules (includes native serialport — cannot be bundled).
    (libexec/"cli").cd do
      system "bun", "install", "--frozen-lockfile"
    end

    # The cli/flx bash wrapper resolves its own symlinks, so a bin symlink works.
    bin.install_symlink libexec/"cli/flx"
  end

  def caveats
    <<~EOS
      flx reads a private GitHub release asset during install and upgrade.
      A GitHub token with at least read access to flexolumens/k230-platform
      is required. Provide it in one of the following ways:

        • Set HOMEBREW_GITHUB_API_TOKEN before running brew install / upgrade:
            HOMEBREW_GITHUB_API_TOKEN="$(gh auth token)" brew install flexolumens/tap/flx

        • Or authenticate via the GitHub CLI (gh):
            gh auth login

      The CLI itself also needs a token to resolve library dependencies.
      After install, run:
        flx auth --github-token <token>
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/flx --version")
  end
end
