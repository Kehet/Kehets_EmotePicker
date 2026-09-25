#!/usr/bin/env bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Version Tagging Script ===${NC}"

if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}Error: Not in a git repository${NC}"
    exit 1
fi

if ! git diff-index --quiet HEAD --; then
    echo -e "${YELLOW}Warning: You have uncommitted changes${NC}"
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Exiting..."
        exit 1
    fi
fi

LATEST_TAG=$(git tag --sort=-version:refname | head -n1)

if [ -z "$LATEST_TAG" ]; then
    LATEST_TAG="0.0.0"
fi

echo -e "Current version: ${GREEN}$LATEST_TAG${NC}"

if [[ $LATEST_TAG =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    MAJOR=${BASH_REMATCH[1]}
    MINOR=${BASH_REMATCH[2]}
    PATCH=${BASH_REMATCH[3]}
else
    echo -e "${RED}Error: Invalid version format in tag '$LATEST_TAG'. Expected format: major.minor.patch${NC}"
    exit 1
fi

NEXT_MAJOR="$((MAJOR + 1)).0.0"
NEXT_MINOR="$MAJOR.$((MINOR + 1)).0"
NEXT_PATCH="$MAJOR.$MINOR.$((PATCH + 1))"

echo
echo -e "${BLUE}Select version type${NC}"
echo -e "1) ${GREEN}Major${NC}: $LATEST_TAG -> $NEXT_MAJOR"
echo -e "2) ${GREEN}Minor${NC}: $LATEST_TAG -> $NEXT_MINOR"
echo -e "3) ${GREEN}Patch${NC}: $LATEST_TAG -> $NEXT_PATCH"
echo

while true; do
    read -p "Select version type (1-3): " -n 1 -r
    echo
    case $REPLY in
        1)
            NEW_VERSION=$NEXT_MAJOR
            VERSION_TYPE="major"
            break
            ;;
        2)
            NEW_VERSION=$NEXT_MINOR
            VERSION_TYPE="minor"
            break
            ;;
        3)
            NEW_VERSION=$NEXT_PATCH
            VERSION_TYPE="patch"
            break
            ;;
        *)
            echo -e "${RED}Please select 1, 2, or 3${NC}"
            ;;
    esac
done

echo -e "Selected: ${GREEN}$VERSION_TYPE${NC} bump to version ${GREEN}$NEW_VERSION${NC}"
echo

echo -e "${BLUE}Updating .toc file with new version...${NC}"
TOC_FILE="Kehets_EmotePicker.toc"

if [ ! -f "$TOC_FILE" ]; then
    echo -e "${RED}Error: $TOC_FILE not found${NC}"
    exit 1
fi

sed -i "s/^## Version: .*/## Version: $NEW_VERSION/" "$TOC_FILE"

echo -e "${BLUE}Committing .toc file update...${NC}"
git add "$TOC_FILE"
git commit -m "Bump version to $NEW_VERSION"

echo -e "${BLUE}Creating git tag...${NC}"
git tag -a "$NEW_VERSION" -m "Release version $NEW_VERSION"
echo -e "${GREEN}Created tag: $NEW_VERSION${NC}"

echo -e "${BLUE}Pushing commits and tag to remote...${NC}"
git push origin HEAD
git push origin "$NEW_VERSION"
