#!/bin/bash
GIT_HASH=$(git rev-parse --short HEAD || echo "unknown")
BUILD_TIME=$(date -u "+%Y-%m-%d %H:%M:%S UTC")

# When using GENERATE_INFOPLIST_FILE=YES, we can't easily modify the compiled Info.plist
# during the build phase reliably because Xcode processes it afterward.
# A much safer and standard way in Swift is to write to a generated Swift file.

cat << SWIFT_EOF > "$SRCROOT/MacMonitor/BuildInfo.swift"
// Generated file, do not edit
import Foundation

struct BuildInfo {
    static let gitHash = "$GIT_HASH"
    static let buildTime = "$BUILD_TIME"
}
SWIFT_EOF
