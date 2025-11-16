#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
APPNAME="pokerchain"
BUILD_DIR="build"
RELEASE_DIR="release"

# Parse command line arguments
RELEASE_MESSAGE=""
SKIP_VERSION_CHECK=false

usage() {
    echo "Usage: $0 [-m MESSAGE] [-s]"
    echo ""
    echo "Options:"
    echo "  -m MESSAGE       Release message (optional)"
    echo "  -s               Skip version already released check"
    echo ""
    echo "The version is read from the Makefile (VERSION := vX.Y.Z)"
    echo ""
    echo "Example:"
    echo "  $0 -m 'Fixed sync node deployment'"
    exit 1
}

while getopts "m:sh" opt; do
    case $opt in
        m)
            RELEASE_MESSAGE="$OPTARG"
            ;;
        s)
            SKIP_VERSION_CHECK=true
            ;;
        h)
            usage
            ;;
        \?)
            usage
            ;;
    esac
done

# Read version from Makefile
if [ ! -f "Makefile" ]; then
    echo -e "${RED}Error: Makefile not found${NC}"
    exit 1
fi

VERSION=$(grep "^VERSION :=" Makefile | awk '{print $3}')

if [ -z "$VERSION" ]; then
    echo -e "${RED}Error: Could not read VERSION from Makefile${NC}"
    exit 1
fi

echo "Read version from Makefile: $VERSION"

# Validate version format
if [[ ! "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo -e "${RED}Error: Version must be in format vX.Y.Z (e.g., v0.1.5)${NC}"
    echo "Current value in Makefile: $VERSION"
    exit 1
fi

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}Error: Not in a git repository${NC}"
    exit 1
fi

# Check if there are uncommitted changes
if ! git diff-index --quiet HEAD --; then
    echo -e "${YELLOW}Warning: You have uncommitted changes${NC}"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check if tag already exists
if git rev-parse "$VERSION" >/dev/null 2>&1; then
    if [ "$SKIP_VERSION_CHECK" = false ]; then
        echo -e "${RED}Error: Tag $VERSION already exists${NC}"
        echo "Use -s flag to skip this check and recreate the release"
        exit 1
    else
        echo -e "${YELLOW}Warning: Tag $VERSION already exists, will recreate${NC}"
    fi
fi

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo -e "${RED}Error: GitHub CLI (gh) is not installed${NC}"
    echo "Install it with: sudo apt install gh  (or brew install gh on macOS)"
    exit 1
fi

# Check if authenticated with GitHub
if ! gh auth status &> /dev/null; then
    echo -e "${RED}Error: Not authenticated with GitHub${NC}"
    echo "Run: gh auth login"
    exit 1
fi

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}Creating Release $VERSION${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Note: We don't update the Makefile since we're reading from it
echo -e "${GREEN}Step 1: Cleaning previous builds${NC}"
rm -rf "$BUILD_DIR"
rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"
echo "Cleaned $BUILD_DIR and $RELEASE_DIR directories"
echo ""

# Build all binaries
echo -e "${GREEN}Step 2: Building binaries (Linux AMD64 and macOS ARM64)${NC}"

# Build Linux AMD64
echo "Building Linux AMD64..."
GOOS=linux GOARCH=amd64 go build -o "$BUILD_DIR/${APPNAME}d-linux-amd64" ./cmd/${APPNAME}d

# Build macOS ARM64
echo "Building macOS ARM64..."
GOOS=darwin GOARCH=arm64 go build -o "$BUILD_DIR/${APPNAME}d-darwin-arm64" ./cmd/${APPNAME}d

echo "Build complete"
echo ""

# Verify binaries were created
echo -e "${GREEN}Step 3: Verifying binaries${NC}"
BINARIES=(
    "${APPNAME}d-linux-amd64"
    "${APPNAME}d-darwin-arm64"
)

for binary in "${BINARIES[@]}"; do
    if [ ! -f "$BUILD_DIR/$binary" ]; then
        echo -e "${RED}Error: Binary $binary not found${NC}"
        exit 1
    fi
    size=$(ls -lh "$BUILD_DIR/$binary" | awk '{print $5}')
    echo "  ✓ $binary ($size)"
done
echo ""

# Compress binaries
echo -e "${GREEN}Step 4: Compressing binaries${NC}"
cd "$BUILD_DIR" || exit 1

for binary in "${BINARIES[@]}"; do
    echo "Compressing $binary..."
    tar -czf "../$RELEASE_DIR/${binary}-${VERSION}.tar.gz" "$binary"
    
    # Create checksums
    sha256sum "../$RELEASE_DIR/${binary}-${VERSION}.tar.gz" | awk '{print $1}' > "../$RELEASE_DIR/${binary}-${VERSION}.tar.gz.sha256"
    
    echo "  ✓ Created ${binary}-${VERSION}.tar.gz"
done

cd ..
echo ""

# Create checksums file
echo -e "${GREEN}Step 5: Creating checksums file${NC}"
cd "$RELEASE_DIR" || exit 1
sha256sum *.tar.gz > "checksums-${VERSION}.txt"
cd ..
echo "  ✓ Created checksums-${VERSION}.txt"
echo ""

# Commit any changes (if needed)
echo -e "${GREEN}Step 6: Checking for uncommitted changes${NC}"
if git diff --quiet && git diff --cached --quiet; then
    echo "No changes to commit"
else
    echo -e "${YELLOW}Warning: You have uncommitted changes${NC}"
    read -p "Commit all changes before creating release? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git add -A
        git commit -m "Prepare release $VERSION"
        echo "  ✓ Committed changes"
    else
        echo "Proceeding without committing changes"
    fi
fi
echo ""

# Create and push tag
echo -e "${GREEN}Step 7: Creating and pushing git tag${NC}"
git tag -a "$VERSION" -m "Release $VERSION"
git push origin "$VERSION"
git push origin main
echo "  ✓ Tagged and pushed $VERSION"
echo ""

# Create GitHub release
echo -e "${GREEN}Step 8: Creating GitHub release${NC}"
if [ -z "$RELEASE_MESSAGE" ]; then
    RELEASE_MESSAGE="Release $VERSION"
fi

gh release create "$VERSION" \
    --title "$VERSION" \
    --notes "$RELEASE_MESSAGE" \
    "$RELEASE_DIR"/*.tar.gz \
    "$RELEASE_DIR"/checksums-${VERSION}.txt

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ Release $VERSION created successfully!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "View your release at:"
echo "https://github.com/block52/pokerchain/releases/tag/$VERSION"
echo ""
echo "Release artifacts:"
for binary in "${BINARIES[@]}"; do
    echo "  • ${binary}-${VERSION}.tar.gz"
done
echo "  • checksums-${VERSION}.txt"
echo ""
