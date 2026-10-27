#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
if [[ "$(uname -s)" != Darwin ]]; then
  echo 'Apple builds require macOS and Xcode 16+.' >&2
  exit 1
fi
command -v xcodegen >/dev/null || { echo 'Install XcodeGen: brew install xcodegen' >&2; exit 1; }
swift test
xcodegen generate
xcodebuild -project LastLine.xcodeproj -scheme LastLine -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project LastLine.xcodeproj -scheme LastLine -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO build
