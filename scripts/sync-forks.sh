#!/bin/bash

# Elephant Handbook - Sync All Forks Script
# Syncs all Dimelords fork repositories with their upstream ttab repositories

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BASE_DIR="${1:-$(pwd)}"
DRY_RUN=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --path)
            BASE_DIR="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS] [BASE_DIR]"
            echo ""
            echo "Options:"
            echo "  --dry-run           Show what would be done without doing it"
            echo "  --path PATH         Base directory containing repositories"
            echo "  --help              Show this help message"
            echo ""
            echo "Example:"
            echo "  $0 --dry-run /path/to/repos"
            exit 0
            ;;
        *)
            BASE_DIR="$1"
            shift
            ;;
    esac
done

# Repository lists
REPOS=(
    "elephant-repository"
    "elephant-index"
    "elephant-user"
    "elephant-chrome"
    "elephant-ui"
    "textbit"
    "textbit-plugins"
    "elephant-api"
    "elephant-api-npm"
    "elephantine"
    "newsdoc"
    "revisor"
    "revisorschemas"
    "media-client"
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

print_step() {
    echo
    echo -e "${BLUE}==== $1 ====${NC}"
    echo
}

# Check prerequisites
check_prerequisites() {
    if ! command -v git &> /dev/null; then
        print_error "git is not installed"
        exit 1
    fi
}

# Sync a single repository
sync_repository() {
    local repo=$1
    local repo_dir="$BASE_DIR/$repo"

    # Check if directory exists
    if [ ! -d "$repo_dir" ]; then
        print_warn "Repository $repo not found at $repo_dir, skipping"
        return 1
    fi

    cd "$repo_dir"

    # Check if it's a git repository
    if [ ! -d ".git" ]; then
        print_warn "$repo is not a git repository, skipping"
        return 1
    fi

    # Check if upstream remote exists
    if ! git remote get-url upstream &>/dev/null; then
        print_warn "$repo has no upstream remote configured, skipping"
        return 1
    fi

    # Get current branch
    local current_branch=$(git rev-parse --abbrev-ref HEAD)

    # Check for uncommitted changes
    if [ -n "$(git status --porcelain)" ]; then
        print_warn "$repo has uncommitted changes"

        if [ "$DRY_RUN" = false ]; then
            read -p "Stash changes and continue? (y/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                git stash push -m "Auto-stash before sync $(date +%Y%m%d-%H%M%S)"
                local stashed=true
            else
                print_warn "Skipping $repo due to uncommitted changes"
                return 1
            fi
        else
            print_info "[DRY-RUN] Would stash uncommitted changes"
            return 1
        fi
    fi

    # Ensure we're on main/master
    local default_branch="main"
    if git show-ref --verify --quiet refs/heads/master; then
        default_branch="master"
    fi

    if [ "$current_branch" != "$default_branch" ]; then
        print_warn "$repo is on branch '$current_branch', not '$default_branch'"

        if [ "$DRY_RUN" = false ]; then
            git checkout "$default_branch"
        else
            print_info "[DRY-RUN] Would checkout $default_branch"
        fi
    fi

    # Fetch from upstream
    print_info "Fetching upstream for $repo..."
    if [ "$DRY_RUN" = false ]; then
        git fetch upstream --quiet
    else
        print_info "[DRY-RUN] Would fetch from upstream"
    fi

    # Check commits behind
    local behind=$(git rev-list --count HEAD..upstream/$default_branch 2>/dev/null || echo "0")
    local ahead=$(git rev-list --count upstream/$default_branch..HEAD 2>/dev/null || echo "0")

    if [ "$behind" -eq 0 ]; then
        print_info "$repo is up to date with upstream"
        if [ "$ahead" -gt 0 ]; then
            print_info "  (You have $ahead local commits ahead)"
        fi
        return 0
    fi

    print_info "$repo is $behind commits behind upstream"
    if [ "$ahead" -gt 0 ]; then
        print_warn "  You also have $ahead local commits ahead"
    fi

    # Merge upstream
    if [ "$DRY_RUN" = false ]; then
        if git merge upstream/$default_branch --no-edit; then
            print_info "✓ Successfully merged upstream/$default_branch into $repo"

            # Push to origin
            print_info "Pushing to origin..."
            if git push origin "$default_branch"; then
                print_info "✓ Successfully pushed to origin/$default_branch"
            else
                print_error "✗ Failed to push to origin"
                return 1
            fi

            # Restore stashed changes if any
            if [ "$stashed" = true ]; then
                print_info "Restoring stashed changes..."
                git stash pop
            fi
        else
            print_error "✗ Merge conflict in $repo"
            print_error "  Please resolve conflicts manually:"
            print_error "  cd $repo_dir"
            print_error "  git status"
            print_error "  # resolve conflicts"
            print_error "  git merge --continue"
            git merge --abort
            return 1
        fi
    else
        print_info "[DRY-RUN] Would merge upstream/$default_branch"
        print_info "[DRY-RUN] Would push to origin/$default_branch"
    fi

    return 0
}

# Main script
main() {
    echo "========================================"
    echo "Elephant Fork Sync Script"
    echo "========================================"
    echo "Base Directory: $BASE_DIR"
    if [ "$DRY_RUN" = true ]; then
        echo "Mode: DRY RUN (no changes will be made)"
    fi
    echo "========================================"
    echo

    check_prerequisites

    # Check if base directory exists
    if [ ! -d "$BASE_DIR" ]; then
        print_error "Base directory $BASE_DIR does not exist"
        exit 1
    fi

    # Counters
    local total=0
    local synced=0
    local skipped=0
    local failed=0
    local uptodate=0

    # Sync each repository
    for repo in "${REPOS[@]}"; do
        print_step "Syncing $repo"
        total=$((total + 1))

        if sync_repository "$repo"; then
            # Check if it was actually updated or just up to date
            if [ -f "$BASE_DIR/$repo/.git/MERGE_HEAD" ]; then
                synced=$((synced + 1))
            else
                uptodate=$((uptodate + 1))
            fi
        else
            local exit_code=$?
            if [ $exit_code -eq 1 ]; then
                skipped=$((skipped + 1))
            else
                failed=$((failed + 1))
            fi
        fi
    done

    # Summary
    print_step "Summary"
    echo "Total repositories: $total"
    echo "Synced: $synced"
    echo "Already up to date: $uptodate"
    echo "Skipped: $skipped"
    echo "Failed: $failed"

    if [ "$DRY_RUN" = true ]; then
        echo
        print_info "This was a dry run. No changes were made."
        print_info "Run without --dry-run to actually sync repositories."
    fi

    if [ $failed -gt 0 ]; then
        echo
        print_error "Some repositories failed to sync. Please check the output above."
        exit 1
    fi
}

# Run main script
main
