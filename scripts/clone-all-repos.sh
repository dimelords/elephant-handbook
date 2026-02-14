#!/bin/bash

# Elephant Handbook - Clone All Repositories Script
# Clones all Dimelords fork repositories and sets up upstream remotes

set -e

# Configuration
ORG="dimelords"
UPSTREAM_ORG="ttab"
BASE_DIR="${1:-$(pwd)/elephant-repos}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Repository lists
BACKEND_REPOS=(
    "elephant-repository"
    "elephant-index"
    "elephant-user"
)

FRONTEND_REPOS=(
    "elephant-chrome"
    "elephant-ui"
    "textbit"
    "textbit-plugins"
)

API_REPOS=(
    "elephant-api"
    "elephant-api-npm"
    "elephantine"
    "newsdoc"
    "revisor"
    "revisorschemas"
    "media-client"
)

OPTIONAL_REPOS=(
    "clitools"
    "eleconf"
    "elephant-spell"
    "eslint-config-elephant"
    "typescript-api-client"
)

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to clone and setup repository
clone_and_setup() {
    local repo=$1
    local repo_dir="$BASE_DIR/$repo"

    if [ -d "$repo_dir" ]; then
        print_warn "Repository $repo already exists, skipping clone"
        cd "$repo_dir"
    else
        print_info "Cloning $repo..."
        gh repo clone "$ORG/$repo" "$repo_dir"
        cd "$repo_dir"
    fi

    # Check if upstream remote exists
    if git remote get-url upstream &>/dev/null; then
        print_info "Upstream remote already configured for $repo"
    else
        print_info "Adding upstream remote for $repo..."
        git remote add upstream "https://github.com/$UPSTREAM_ORG/$repo.git"
    fi

    # Fetch upstream
    print_info "Fetching upstream for $repo..."
    git fetch upstream --quiet

    cd "$BASE_DIR"
}

# Check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."

    if ! command -v gh &> /dev/null; then
        print_error "GitHub CLI (gh) is not installed. Install it from https://cli.github.com/"
        exit 1
    fi

    if ! command -v git &> /dev/null; then
        print_error "Git is not installed."
        exit 1
    fi

    # Check if gh is authenticated
    if ! gh auth status &>/dev/null; then
        print_error "GitHub CLI is not authenticated. Run: gh auth login"
        exit 1
    fi

    print_info "All prerequisites satisfied"
}

# Main script
main() {
    echo "========================================"
    echo "Elephant Repository Cloning Script"
    echo "Organization: $ORG"
    echo "Base Directory: $BASE_DIR"
    echo "========================================"
    echo

    check_prerequisites

    # Create base directory
    mkdir -p "$BASE_DIR"
    cd "$BASE_DIR"

    # Clone backend repositories
    echo
    print_info "Cloning backend services..."
    for repo in "${BACKEND_REPOS[@]}"; do
        clone_and_setup "$repo"
    done

    # Clone frontend repositories
    echo
    print_info "Cloning frontend repositories..."
    for repo in "${FRONTEND_REPOS[@]}"; do
        clone_and_setup "$repo"
    done

    # Clone API and library repositories
    echo
    print_info "Cloning API and library repositories..."
    for repo in "${API_REPOS[@]}"; do
        clone_and_setup "$repo"
    done

    # Ask about optional repositories
    echo
    read -p "Do you want to clone optional repositories? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Cloning optional repositories..."
        for repo in "${OPTIONAL_REPOS[@]}"; do
            clone_and_setup "$repo"
        done
    fi

    # Summary
    echo
    echo "========================================"
    print_info "Cloning complete!"
    echo "========================================"
    echo
    echo "Repositories cloned to: $BASE_DIR"
    echo
    echo "Next steps:"
    echo "  1. cd $BASE_DIR"
    echo "  2. Review the elephant-handbook for setup instructions"
    echo "  3. Run setup scripts for each service as needed"
    echo
    echo "To sync all forks with upstream:"
    echo "  $(dirname "$0")/sync-forks.sh $BASE_DIR"
    echo
}

# Run main script
main
