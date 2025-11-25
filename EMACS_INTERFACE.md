# Emacs Interface for Beads

> **🎉 Working Demo Available!**
> See [EMACS_DEMO.md](EMACS_DEMO.md) for the working prototype and [beads.el](beads.el) for the implementation.
> Visual mockups available in [INTERFACE_MOCKUP.txt](INTERFACE_MOCKUP.txt).

## Overview

An Emacs interface for Beads modeled after magit's design philosophy:
- Single entry point with status buffer
- Single-key commands on items
- Expandable/collapsible sections
- Transient menus for complex operations
- Integration with existing Emacs workflows

## Core Entry Point

### `beads-status` (bound to `C-c b s`)

The main interface - equivalent to `magit-status`. Shows:

```
Beads Status [/home/user/project]
──────────────────────────────────────────────────────────────

Ready Work (3)
  bd-a1b2  P1  [task]    Fix authentication bug                @alice
  bd-f14c  P1  [feature] Add OAuth support                     @bob
  bd-3e7a  P2  [bug]     Handle edge case in parser            (unassigned)

In Progress (2)
  bd-1234  P0  [bug]     Critical security issue               @alice
  bd-5678  P1  [task]    Refactor login flow                   @bob

Blocked (1)
  bd-9abc  P2  [feature] Dashboard redesign                    @alice
    blocked by: bd-1234, bd-5678

Recent Updates (5)
  bd-def0  Closed 2h ago  [task] Update documentation
  bd-1111  Updated 3h ago [bug]  Fix memory leak
  ...

──────────────────────────────────────────────────────────────
Commands: c create  u update  v view  d deps  f filter  r refresh  ? help
```

### Single-Key Commands (in status buffer)

- `c` - Create new issue (opens transient)
- `u` - Update issue at point (opens transient)
- `v` - View issue details (opens detail buffer)
- `d` - Manage dependencies (opens transient)
- `s` - Change status (quick menu: open/in_progress/blocked/closed)
- `p` - Change priority (quick menu: P0-P4)
- `a` - Assign to user
- `l` - Manage labels
- `k` - Close issue at point
- `f` - Filter view (opens transient)
- `r` - Refresh buffer
- `g` - Same as `r` (magit convention)
- `q` - Quit buffer
- `?` - Help/cheatsheet
- `TAB` - Expand/collapse section
- `RET` - View issue at point (same as `v`)

## Transient Menus

### Create Issue Transient (`c` from status)

```
Create Issue
──────────────────────────────────────────
Type
 -t task       --type=task
 -f feature    --type=feature
 -b bug        --type=bug
 -e epic       --type=epic
 -h chore      --type=chore

Priority
 -0 P0 (Critical)    --priority=0
 -1 P1 (High)        --priority=1
 -2 P2 (Medium)      --priority=2  [default]
 -3 P3 (Low)         --priority=3
 -4 P4 (Backlog)     --priority=4

Options
 -a USER       --assignee=USER
 -l LABELS     --labels=LABELS
 -d DESC       --description=DESC

Actions
 c Create with title
 t Create from template
 m Create from markdown file
```

### Update Issue Transient (`u` from status)

```
Update Issue: bd-a1b2
──────────────────────────────────────────
Status
 s open
 i in_progress
 b blocked
 c closed

Priority
 0 P0  1 P1  2 P2  3 P3  4 P4

Options
 a Assignee
 l Labels
 d Description
 t Title

Actions
 u Update
 k Close with reason
```

### Dependencies Transient (`d` from status)

```
Dependencies: bd-a1b2
──────────────────────────────────────────
Add Dependency
 -b blocks           This issue blocks another
 -r related          Related issue
 -p parent           Parent issue
 -f discovered-from  Discovered from another issue

Actions
 a Add dependency (target ID)
 r Remove dependency (target ID)
 t Show dependency tree
 c Check for cycles
```

### Filter Transient (`f` from status)

```
Filter Issues
──────────────────────────────────────────
Status
 o open
 i in_progress
 b blocked
 c closed
 a all  [default]

Priority
 0 P0  1 P1  2 P2  3 P3  4 P4  x all  [default]

Other
 -a USER       --assignee=USER
 -l LABELS     --labels=LABELS (AND)
 -L LABELS     --labels-any=LABELS (OR)
 -t TEXT       --title-contains=TEXT
 -d TEXT       --desc-contains=TEXT

Actions
 f Apply filter
 r Reset filters
```

## Detail Buffer

### `beads-show` (opened with `v` or `RET`)

Shows full issue details with interactive commands:

```
Issue: bd-a1b2
──────────────────────────────────────────────────────────────
Title:       Fix authentication bug
Type:        task
Status:      open
Priority:    P1 (High)
Assignee:    @alice
Labels:      backend, security, urgent
Created:     2025-11-20 14:30:00
Updated:     2025-11-23 09:15:00

Description:
The authentication token validation is failing for certain edge
cases when the token contains special characters. This causes
users to be logged out unexpectedly.

Steps to reproduce:
1. Create token with UTF-8 characters
2. Attempt to validate
3. Observe failure

Notes:
[2025-11-23 09:15] @alice: Found root cause in token parser
[2025-11-22 16:30] @bob: Cannot reproduce locally
[2025-11-20 14:35] @alice: Filed from user report #4521

Dependencies:
Blocks (2):
  bd-f14c  [feature] Add OAuth support
  bd-9abc  [feature] Dashboard redesign

Related to (1):
  bd-3e7a  [bug] Handle edge case in parser

Discovered Work (0):
  (none)

──────────────────────────────────────────────────────────────
Commands: u update  s status  p priority  a assign  l labels
          d deps  n note  k close  r refresh  q quit
```

### Commands in Detail Buffer

- `u` - Update (opens transient)
- `s` - Change status
- `p` - Change priority
- `a` - Change assignee
- `l` - Manage labels
- `d` - Manage dependencies
- `n` - Add note (appends timestamped note)
- `k` - Close issue
- `o` - Open in external browser (if web UI configured)
- `y` - Copy issue ID to kill ring
- `r` / `g` - Refresh
- `q` - Quit buffer
- `RET` on dependency - Jump to that issue

## Additional Buffers

### Dependency Tree Buffer

Opened with `bd dep tree` or from detail buffer:

```
Dependency Tree: bd-a1b2
──────────────────────────────────────────────────────────────
bd-1234  [epic] Authentication System (P0, closed)
├─ bd-a1b2  [task] Fix authentication bug (P1, open) ★ YOU ARE HERE
│  ├─ bd-f14c  [feature] Add OAuth support (P1, blocked)
│  └─ bd-9abc  [feature] Dashboard redesign (P2, blocked)
└─ bd-5678  [task] Update auth docs (P2, closed)

Legend: open │ in_progress │ blocked │ closed

──────────────────────────────────────────────────────────────
Commands: RET jump to issue  r refresh  q quit
```

### Ready Work Buffer

Focused view of ready work (alternative to status buffer):

```
Ready Work (sorted by priority)
──────────────────────────────────────────────────────────────
P0 - Critical (0)

P1 - High (2)
  bd-a1b2  [task]    Fix authentication bug                @alice
  bd-f14c  [feature] Add OAuth support                     @bob

P2 - Medium (1)
  bd-3e7a  [bug]     Handle edge case in parser            (unassigned)

P3 - Low (0)

──────────────────────────────────────────────────────────────
Commands: RET view  u update  s start work  r refresh  q quit
```

## Core Integration

### Project Integration (Core Feature)

- Auto-detect `.beads/` directory (like projectile/project.el)
- `beads-status` defaults to current project
- `C-u M-x beads-status` prompts for project path

## Optional/Future Integration Features

### Org-mode Integration (Optional)

- `beads-org-export` - Export issues to org-mode TODO list
- `beads-org-link` - Create org links to beads issues (`beads:bd-a1b2`)
- Click org link opens `beads-show` buffer

### Magit Integration (Optional)

- `magit-beads-status` section in `magit-status` buffer
- Shows count of ready work and in-progress issues
- Press `b` in magit-status to jump to beads-status

### Embark Integration (Optional)

```elisp
;; Define embark actions for beads issues
(defvar-keymap embark-beads-issue-map
  :doc "Keymap for actions on beads issues"
  "v" #'beads-show
  "u" #'beads-update
  "s" #'beads-change-status
  "k" #'beads-close
  "y" #'beads-copy-id)
```

## Configuration

```elisp
;; ~/.emacs.d/init.el

(use-package beads
  :bind (("C-c b s" . beads-status)
         ("C-c b c" . beads-create)
         ("C-c b r" . beads-ready)
         ("C-c b f" . beads-find-issue))
  :config
  ;; Auto-refresh interval (seconds, nil to disable)
  (setq beads-auto-refresh-interval 60)

  ;; Default priority for new issues
  (setq beads-default-priority 2)

  ;; Default assignee
  (setq beads-default-assignee user-mail-address)

  ;; Number of recent updates to show
  (setq beads-status-recent-count 5)

  ;; Color coding
  (setq beads-priority-faces
        '((0 . error)    ; P0 - red
          (1 . warning)  ; P1 - yellow
          (2 . default)  ; P2 - default
          (3 . shadow)   ; P3 - dim
          (4 . shadow))) ; P4 - dim

  ;; Optional: Status icons (using all-the-icons or nerd-icons)
  (setq beads-use-icons t)

  ;; Optional: Enable magit integration
  (setq beads-magit-integration t)

  ;; Optional: Enable org-mode integration
  (setq beads-org-integration t))
```

## Advanced Features

### Quick Commands

- `beads-create-bug-here` - Create bug issue with current file/line context
- `beads-create-todo-here` - Create task from current location
- `beads-close-current` - Close the issue you're currently viewing

### Search and Filter

- `beads-search` - Full-text search across titles, descriptions, notes
- `beads-filter-by-label` - Filter by label with completion
- `beads-filter-by-assignee` - Filter by assignee with completion

### Bulk Operations

- Mark multiple issues in status buffer (`m` to mark, `u` to unmark, `U` to unmark all)
- Bulk close (`K`)
- Bulk priority change (`P`)
- Bulk label add/remove (`L`)
- Bulk assignee change (`A`)

### Workflow Shortcuts

- `beads-start-work` - Mark issue as in_progress and assign to self
- `beads-finish-work` - Close current issue and jump to next ready issue
- `beads-block-on` - Mark current issue as blocked by another

## Implementation Notes

### Core Data Structures

```elisp
(cl-defstruct beads-issue
  id title type status priority
  assignee labels description notes
  created-at updated-at closed-at
  dependencies dependents)

(cl-defstruct beads-dependency
  from to type)
```

### JSON Parsing

All `bd` commands use `--json` flag for programmatic access:

```elisp
(defun beads--run-json (command)
  "Run bd COMMAND and parse JSON output."
  (let* ((json-array-type 'list)
         (json-object-type 'alist)
         (output (shell-command-to-string
                  (format "bd %s --json" command))))
    (json-read-from-string output)))
```

### Async Operations

Use `async-shell-command` for long-running operations:

```elisp
(defun beads-sync-async ()
  "Sync beads database asynchronously."
  (async-shell-command "bd sync" "*beads-sync*"))
```

### Auto-refresh

```elisp
(defvar-local beads--refresh-timer nil)

(defun beads--start-auto-refresh ()
  "Start auto-refresh timer for current buffer."
  (when beads-auto-refresh-interval
    (setq beads--refresh-timer
          (run-at-time beads-auto-refresh-interval
                       beads-auto-refresh-interval
                       #'beads-refresh-current-buffer))))
```

## User Experience Goals

1. **Zero Learning Curve for Magit Users**
   - Same keybindings philosophy (single-key, mnemonic)
   - Same buffer navigation (sections, TAB to expand)
   - Same transient menu approach

2. **Fast and Responsive**
   - Cache JSON responses
   - Async operations for slow commands
   - Incremental updates (don't refresh entire buffer)

3. **Visual Clarity**
   - Color-coded priorities
   - Status icons
   - Clear section separators
   - Proper alignment

4. **Workflow Integration**
   - Works with projectile/project.el
   - Integrates with magit
   - Org-mode export/links
   - Company/completion for issue IDs

## MVP Feature Set

The initial version should focus on:

1. **Core Buffers**
   - `beads-status` - Main status buffer
   - `beads-show` - Issue detail view
   - `beads-ready` - Ready work focused view

2. **Essential Commands**
   - Create, update, close issues
   - Change status, priority, assignee
   - View dependencies
   - Basic filtering

3. **Core Integration**
   - Project.el detection
   - JSON parsing from `bd` commands

## Future Enhancements

- **Org-mode Integration**: Export to TODO, org-links
- **Magit Integration**: Status section in magit-status
- **Embark Integration**: Embark actions for issues
- **Dashboard**: Summary view across all projects
- **Notifications**: Desktop notifications for issue updates
- **Templates**: Interactive template creation/editing
- **Time Tracking**: Integration with org-clock
- **Statistics**: Charts and graphs of issue trends
- **AI Integration**: Use LLM for issue summarization/suggestions
- **Multi-select**: Bulk operations with visual selection
- **Agenda View**: Calendar view of deadlines (if added to beads)
- **Dependency Tree Buffer**: Visual graph rendering
- **Icons**: all-the-icons or nerd-icons support

## Open Questions

1. Should we support inline editing (like magit's commit message buffer)?
2. How to handle multi-project workflows? Separate buffers or unified view?
3. Should we cache issue data or always fetch fresh from `bd`?
4. Integration with LSP for creating issues from code problems?
5. Support for custom fields/extensions to the database?
