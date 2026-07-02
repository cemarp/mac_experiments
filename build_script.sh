#!/bin/bash
GIT_HASH=$(git rev-parse --short HEAD || echo "unknown")
BUILD_TIME=$(date -u "+%Y-%m-%d %H:%M:%S UTC")

# Use PlistBuddy to set values
/usr/libexec/PlistBuddy -c "Add :GitCommitHash string $GIT_HASH" "${TARGET_BUILD_DIR}/${INFOPLIST_PATH}" || /usr/libexec/PlistBuddy -c "Set :GitCommitHash $GIT_HASH" "${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"
/usr/libexec/PlistBuddy -c "Add :BuildTime string '$BUILD_TIME'" "${TARGET_BUILD_DIR}/${INFOPLIST_PATH}" || /usr/libexec/PlistBuddy -c "Set :BuildTime '$BUILD_TIME'" "${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"
