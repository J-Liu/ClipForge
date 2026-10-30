#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright © 2026 Jia Liu

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== ClipForge Release Script ===${NC}\n"

# Check if we're on main branch
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "main" ]; then
    echo -e "${RED}Error: Not on main branch. Current branch: $CURRENT_BRANCH${NC}"
    exit 1
fi
echo -e "${GREEN}✓ On main branch${NC}"

# Check for uncommitted changes
if ! git diff-index --quiet HEAD --; then
    echo -e "${RED}Error: There are uncommitted changes:${NC}"
    git status --short
    exit 1
fi
echo -e "${GREEN}✓ No uncommitted changes${NC}"

# Check for untracked files
UNTRACKED=$(git ls-files --others --exclude-standard)
if [ -n "$UNTRACKED" ]; then
    echo -e "${YELLOW}Warning: There are untracked files:${NC}"
    echo "$UNTRACKED"
    echo -e "${YELLOW}These files will NOT be included in the release.${NC}"
fi

# Fetch and check sync with remote
echo -e "\n${GREEN}Fetching from remote...${NC}"
git fetch origin

LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/main)

if [ "$LOCAL" != "$REMOTE" ]; then
    AHEAD=$(git rev-list --count origin/main..HEAD)
    BEHIND=$(git rev-list --count HEAD..origin/main)

    if [ "$AHEAD" -gt 0 ]; then
        echo -e "${YELLOW}Local is $AHEAD commits ahead of origin/main${NC}"
    fi
    if [ "$BEHIND" -gt 0 ]; then
        echo -e "${RED}Error: Local is $BEHIND commits behind origin/main. Pull first.${NC}"
        exit 1
    fi
    if [ "$AHEAD" -gt 0 ]; then
        echo -e "${YELLOW}Need to push $AHEAD commits first.${NC}"
        exit 1
    fi
fi
echo -e "${GREEN}✓ In sync with origin/main${NC}"

# Get latest tag
LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.1.9")
echo -e "\n${GREEN}Latest tag: ${LATEST_TAG}${NC}"

# Parse version number
VERSION=${LATEST_TAG#v}
MAJOR=$(echo $VERSION | cut -d. -f1)
MINOR=$(echo $VERSION | cut -d. -f2)
PATCH=$(echo $VERSION | cut -d. -f3)

# Increment patch version
NEW_PATCH=$((PATCH + 1))
NEW_TAG="v${MAJOR}.${MINOR}.${NEW_PATCH}"
NEW_VERSION="${MAJOR}.${MINOR}.${NEW_PATCH}"

echo -e "${GREEN}New tag: ${NEW_TAG}${NC}"

# Find Info.plist
INFO_PLIST="Resources/Info.plist"
if [ ! -f "$INFO_PLIST" ]; then
    # Try to find it
    INFO_PLIST=$(find . -name "Info.plist" -not -path "*/.*" -not -path "*/.build/*" -not -path "*/ClipForge.app/*" | head -1)
    if [ -z "$INFO_PLIST" ]; then
        echo -e "${RED}Error: Info.plist not found${NC}"
        exit 1
    fi
fi
echo -e "${GREEN}Found Info.plist: ${INFO_PLIST}${NC}"

# Get current version from Info.plist
CURRENT_BUNDLE=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$INFO_PLIST" 2>/dev/null || echo "1")
CURRENT_SHORT=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$INFO_PLIST" 2>/dev/null || echo "$VERSION")

echo -e "\n${GREEN}Current Info.plist:${NC}"
echo "  CFBundleVersion: $CURRENT_BUNDLE"
echo "  CFBundleShortVersionString: $CURRENT_SHORT"

# Calculate new build number
if [[ "$CURRENT_BUNDLE" =~ ^[0-9]+$ ]]; then
    NEW_BUNDLE=$((CURRENT_BUNDLE + 1))
else
    # If it's not just a number, use patch number
    NEW_BUNDLE=$NEW_PATCH
fi

echo -e "\n${GREEN}New Info.plist:${NC}"
echo "  CFBundleVersion: $NEW_BUNDLE"
echo "  CFBundleShortVersionString: $NEW_VERSION"

# Summary
echo -e "\n${YELLOW}=== Summary ===${NC}"
echo -e "Tag:        ${LATEST_TAG} → ${GREEN}${NEW_TAG}${NC}"
echo -e "Bundle:     ${CURRENT_BUNDLE} → ${GREEN}${NEW_BUNDLE}${NC}"
echo -e "Short Ver:  ${CURRENT_SHORT} → ${GREEN}${NEW_VERSION}${NC}"
echo -e "File:       ${INFO_PLIST}"

# Ask for confirmation
echo -e "\n${YELLOW}Proceed with commit and push? [y/N]${NC}"
read -r CONFIRM

# Only proceed if user explicitly types 'y' or 'Y'
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo -e "${RED}Cancelled.${NC}"
    exit 0
fi

echo -e "\n${GREEN}Updating Info.plist...${NC}"
/usr/libexec/PlistBuddy -c "Set CFBundleVersion $NEW_BUNDLE" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Set CFBundleShortVersionString $NEW_VERSION" "$INFO_PLIST"

echo -e "${GREEN}Committing changes...${NC}"
git add "$INFO_PLIST"
git commit -m "Bump version to $NEW_TAG" -s

echo -e "${GREEN}Creating tag ${NEW_TAG}...${NC}"
git tag -a "$NEW_TAG" -m "Release $NEW_TAG"

echo -e "${GREEN}Pushing to origin...${NC}"
git push origin main
git push origin "$NEW_TAG"

echo -e "\n${GREEN}=== Release $NEW_TAG completed! ===${NC}"
