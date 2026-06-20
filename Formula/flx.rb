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

    # Credential precedence: the package-scoped explicit override wins over
    # ambient credentials. HOMEBREW_FLX_GITHUB_TOKEN exists for users whose
    # gh CLI is authenticated with an account that has no access to the
    # flexolumens repos (e.g. external collaborators holding a read-only
    # token) — ambient gh credentials must not shadow an explicit token.
    # GitHub::API.credentials covers HOMEBREW_GITHUB_API_TOKEN and gh.
    flx_token = ENV.fetch("HOMEBREW_FLX_GITHUB_TOKEN", nil)
    token = flx_token.nil? || flx_token.empty? ? GitHub::API.credentials : flx_token
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
  url "https://github.com/flexolumens/k230-platform/releases/download/v0.9.5/flx-v0.9.5.tar.gz",
      using: GitHubPrivateAssetDownloadStrategy
  sha256 "6fc8476d5dcaee12ad185eb43e30a1ec153ef213e773e57df5ab7c9381a12534"
  version "0.9.5"
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
      A credential with read access to flexolumens/k230-platform is required.
      The formula resolves it in this order:

        1. HOMEBREW_FLX_GITHUB_TOKEN — explicit override; wins over ambient
           credentials. For users without gh access to the flexolumens org:
             HOMEBREW_FLX_GITHUB_TOKEN="<token>" brew upgrade flexolumens/tap/flx

        2. Ambient credentials — the default path for flexolumens members:
             gh auth login
           (HOMEBREW_GITHUB_API_TOKEN is also honored, as everywhere in brew.)

      The CLI itself also needs a token to resolve library dependencies.
      After install, run:
        flx auth --github-token <token>
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/flx --version")
  end
end
