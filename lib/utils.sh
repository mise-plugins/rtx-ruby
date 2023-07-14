#!/usr/bin/env bash

curl_opts=(-fsSL)

if [ -n "${GITHUB_API_TOKEN:-}" ]; then
	curl_opts=("${curl_opts[@]}" -H "Authorization: token $GITHUB_API_TOKEN")
fi

RUBY_BUILD_VERSION="${RTX_RUBY_BUILD_VERSION:-}"
if [ "$RUBY_BUILD_VERSION" = "" ]; then
  RUBY_BUILD_VERSION="$(
    curl "${curl_opts[@]}" "https://api.github.com/repos/rbenv/ruby-build/releases/latest" |
    grep '"tag_name":' |
    sed -E 's/.*"([^"]+)".*/\1/'
  )"
fi
RUBY_BUILD_TAG="$RUBY_BUILD_VERSION"

echoerr() {
  echo >&2 -e "\033[0;31m$1\033[0m"
}

errorexit() {
  echoerr "$1"
  exit 1
}

ensure_ruby_build_setup() {
  ensure_ruby_build_installed
}

ensure_ruby_build_installed() {
  local current_ruby_build_version

  if [ ! -f "$(ruby_build_path)" ]; then
    download_ruby_build
  else
    current_ruby_build_version="$("$(ruby_build_path)" --version | cut -d ' ' -f2)"
    # If ruby-build version does not start with 'v',
    # add 'v' to beginning of version
    # shellcheck disable=SC2086
    if [ "${current_ruby_build_version:0:1}" != "v" ]; then
      current_ruby_build_version="v$current_ruby_build_version"
    fi
    if [ "$current_ruby_build_version" != "$RUBY_BUILD_VERSION" ]; then
      # If the ruby-build directory already exists and the version does not
      # match, remove it and download the correct version
      rm -rf "$(ruby_build_dir)"
      download_ruby_build
    fi
  fi
}

download_ruby_build() {
  # Print to stderr so rtx doesn't assume this string is a list of versions
  echoerr "Downloading ruby-build..."
  # shellcheck disable=SC2155
  local build_dir="$(ruby_build_source_dir)"

  # Remove directory in case it still exists from last download
  rm -rf "$build_dir"

  # Clone down and checkout the correct ruby-build version
  git clone "${RTX_RUBY_BUILD_REPOSITORY:-https://github.com/rbenv/ruby-build.git}" "$build_dir" >/dev/null 2>&1
  (
    cd "$build_dir" || exit
    git checkout "$RUBY_BUILD_TAG" >/dev/null 2>&1
  )

  # Install in the ruby-build dir
  PREFIX="$(ruby_build_dir)" "$build_dir/install.sh"

  # Remove ruby-build source dir
  rm -rf "$build_dir"
}

rtx_ruby_plugin_path() {
  # shellcheck disable=SC2005
  echo "$(dirname "$(dirname "$0")")"
}
ruby_build_dir() {
  echo "$(rtx_ruby_plugin_path)/ruby-build"
}

ruby_build_source_dir() {
  echo "$(rtx_ruby_plugin_path)/ruby-build-source"
}

ruby_build_path() {
  echo "$(ruby_build_dir)/bin/ruby-build"
}
