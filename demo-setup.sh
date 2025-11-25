#!/bin/bash
# Demo setup script for Beads Emacs interface
# Creates sample issues to demonstrate the interface

set -e

echo "Setting up Beads demo data..."

# Initialize beads if not already initialized
if [ ! -d ".beads" ]; then
    echo "Initializing beads..."
    bd init --quiet
fi

# Create some sample issues
echo "Creating sample issues..."

# P0 - Critical
bd create "Critical security vulnerability in auth" \
    -t bug -p 0 -a alice \
    -l "security,backend,urgent" \
    -d "SQL injection vulnerability found in login endpoint. Needs immediate patching." \
    --json > /dev/null

# P1 - High priority tasks
bd create "Implement OAuth 2.0 support" \
    -t feature -p 1 -a bob \
    -l "auth,feature,backend" \
    -d "Add OAuth 2.0 authentication flow for third-party integrations. Support Google and GitHub initially." \
    --json > /dev/null

bd create "Fix memory leak in worker pool" \
    -t bug -p 1 -a alice \
    -l "backend,performance" \
    -d "Workers are not being properly garbage collected, causing memory usage to grow over time." \
    --json > /dev/null

# P2 - Medium priority
bd create "Add user profile page" \
    -t feature -p 2 -a bob \
    -l "frontend,ui" \
    -d "Create user profile page with avatar upload, bio, and settings." \
    --json > /dev/null

bd create "Handle edge case in CSV parser" \
    -t bug -p 2 \
    -l "parser,data" \
    -d "Parser fails when CSV contains escaped quotes in the middle of fields." \
    --json > /dev/null

bd create "Refactor database connection pool" \
    -t task -p 2 -a alice \
    -l "backend,refactor" \
    -d "Current connection pooling implementation is inefficient. Refactor to use modern approach." \
    --json > /dev/null

# P3 - Low priority
bd create "Add dark mode toggle" \
    -t feature -p 3 \
    -l "frontend,ui,nice-to-have" \
    -d "Implement system-wide dark mode with user preference saving." \
    --json > /dev/null

# Create an epic with child issues
EPIC_ID=$(bd create "Q4 Platform Improvements" \
    -t epic -p 1 \
    -d "Epic for all Q4 platform improvement work" \
    --json | jq -r '.id')

echo "Created epic: $EPIC_ID"

# Set some issues to in_progress
ISSUES=$(bd list --json | jq -r '.[0:2] | .[].id')
for id in $ISSUES; do
    bd update "$id" --status in_progress --json > /dev/null
    echo "Set $id to in_progress"
done

# Close a few old issues
CLOSE_ISSUES=$(bd list --json | jq -r '.[3:5] | .[].id')
for id in $CLOSE_ISSUES; do
    bd close "$id" --reason "Completed during demo setup" --json > /dev/null
    echo "Closed $id"
done

echo ""
echo "Demo data created successfully!"
echo ""
echo "To try the Emacs interface:"
echo "1. Load beads.el in Emacs: M-x load-file RET beads.el RET"
echo "2. Open the status buffer: M-x beads-status"
echo ""
echo "Key bindings in status buffer:"
echo "  c - Create new issue"
echo "  v - View issue details (or press RET)"
echo "  u - Update issue"
echo "  k - Close issue"
echo "  r - Refresh"
echo "  q - Quit"
echo ""
echo "Have fun exploring!"
