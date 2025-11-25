# Beads Emacs Interface - Demo Guide

This is a working mock/prototype of the magit-like Emacs interface for Beads.

## Quick Start

### 1. Set up demo data

```bash
./demo-setup.sh
```

This will:
- Initialize a beads database (if not exists)
- Create ~10 sample issues with various priorities and statuses
- Set some issues to in_progress
- Close a few issues to show recent updates

### 2. Load the interface in Emacs

```elisp
;; Load the beads package
(load-file "beads.el")

;; Open the status buffer
(beads-status)
```

Or use `M-x`:
```
M-x load-file RET beads.el RET
M-x beads-status RET
```

## Features Implemented

### Status Buffer (`beads-status`)

The main interface showing:
- **Statistics** - Summary of issue counts by status and priority
- **Ready Work** - Issues with no blockers
- **In Progress** - Currently active issues
- **Blocked** - Issues waiting on dependencies
- **Recent Updates** - Recently closed issues

#### Keybindings in Status Buffer

| Key | Command | Description |
|-----|---------|-------------|
| `c` | `beads-create-transient` | Create new issue (opens transient menu) |
| `v` or `RET` | `beads-show-issue` | View issue details |
| `u` | `beads-update-transient` | Update issue (opens transient menu) |
| `k` | `beads-close-issue` | Close issue at point |
| `s` | `beads-start-work` | Start work (set to in_progress) |
| `y` | `beads-copy-issue-id` | Copy issue ID to kill ring |
| `r` or `g` | `beads-refresh` | Refresh buffer (C-u to force) |
| `W` | `beads-ready` | Open ready work buffer |
| `S` | `beads-statistics` | Show statistics in minibuffer |
| `q` | `beads-quit` | Quit buffer |
| `?` | `describe-mode` | Show help |

### Ready Work Buffer (`beads-ready`)

A focused view showing only ready work, grouped by priority:
- Clear priority groupings (P0-P4)
- Count of issues per priority level
- Minimal distractions - just what's ready to work on

#### Keybindings in Ready Work Buffer

| Key | Command | Description |
|-----|---------|-------------|
| `v` or `RET` | `beads-show-issue` | View issue details |
| `s` | `beads-start-work` | Start work (set to in_progress) |
| `u` | `beads-update-transient` | Update issue |
| `k` | `beads-close-issue` | Close issue |
| `y` | `beads-copy-issue-id` | Copy issue ID |
| `r` or `g` | `beads-refresh` | Refresh buffer |
| `q` | `beads-quit` | Quit buffer |
| `?` | `describe-mode` | Show help |

### Detail Buffer (`beads-show`)

Shows full issue details including:
- All metadata (title, type, status, priority, assignee, labels)
- Timestamps (created, updated, closed)
- Description
- Notes
- Dependencies

#### Keybindings in Detail Buffer

| Key | Command | Description |
|-----|---------|-------------|
| `u` | `beads-update-transient` | Update issue |
| `k` | `beads-close-issue` | Close issue |
| `r` or `g` | `beads-refresh` | Refresh |
| `q` | `beads-quit` | Quit |

### Transient Menus

#### Create Issue Transient (`c`)

Interactive menu for creating issues with:
- **Type**: task, feature, bug, epic, chore
- **Priority**: P0-P4
- **Options**: assignee, labels, description

#### Update Issue Transient (`u`)

Quick updates for:
- **Status**: open, in_progress, blocked, closed
- **Priority**: P0-P4
- **Actions**: change assignee

## Example Workflow

1. **Open status buffer**
   ```
   M-x beads-status
   ```

2. **Create a new issue**
   - Press `c` to open create transient
   - Press `-b` to set type to bug
   - Press `-1` to set priority to P1
   - Press `c` to create with title
   - Enter title and press RET

3. **View issue details**
   - Navigate to an issue line
   - Press `v` or `RET`

4. **Update issue status**
   - In status or detail buffer, press `u`
   - Press `i` to set to in_progress
   - Buffer refreshes automatically

5. **Close an issue**
   - Navigate to issue
   - Press `k`
   - Enter close reason

## What's Implemented

✅ **Core Buffers**
- Status buffer with multiple sections
- Ready work buffer (focused view)
- Detail buffer with full issue info
- Statistics display

✅ **Data Integration**
- JSON parsing from `bd` commands
- Issue caching (30 second TTL)
- Project root detection
- Better error handling and feedback

✅ **Commands**
- Create issues via transient
- Update status, priority, assignee
- Close issues with reason
- Start work (quick in_progress)
- Copy issue ID to kill ring
- View issue details
- Refresh buffers (force with C-u)
- Show statistics

✅ **UI Features**
- Color-coded priorities (P0-P4)
- Status symbols (○ ◐ ◌ ●)
- Time-relative formatting ("2h ago")
- Label display in issue lines
- Proper text properties for navigation
- Keyboard-driven interface
- Truncated titles with ellipsis
- Summary statistics line

## What's Not Implemented (Yet)

⏸️ **Advanced Features**
- Dependency management transient
- Filter transient
- Bulk operations
- Label management UI
- Dependency tree buffer
- Ready work focused buffer

⏸️ **Integrations**
- Org-mode links
- Magit section
- Embark actions
- Icons support

⏸️ **Polish**
- Section folding/expansion (TAB)
- Better error handling
- Async operations
- Auto-refresh timer
- Completion for assignees/labels

## Known Limitations

1. **No section folding** - TAB doesn't expand/collapse sections yet
2. **Basic error handling** - Errors from `bd` commands may not display nicely
3. **No completion** - Assignee and label inputs don't offer completion
4. **Synchronous operations** - All `bd` commands block Emacs
5. **Simple caching** - Cache invalidation is time-based only

## Customization

```elisp
;; In your init.el

(with-eval-after-load 'beads
  ;; Auto-refresh every 60 seconds
  (setq beads-auto-refresh-interval 60)

  ;; Default priority for new issues
  (setq beads-default-priority 2)

  ;; Number of recent updates to show
  (setq beads-status-recent-count 5)

  ;; Custom priority colors
  (setq beads-priority-faces
        '((0 . error)       ; P0 - red
          (1 . warning)     ; P1 - yellow/orange
          (2 . default)     ; P2 - default
          (3 . shadow)      ; P3 - dimmed
          (4 . shadow)))    ; P4 - dimmed

  ;; Keybindings
  (global-set-key (kbd "C-c b s") #'beads-status))
```

## Architecture Notes

### Data Flow

```
User Action → Command → bd CLI (--json) → JSON Parse → Render Buffer
                ↓
            Cache (30s TTL)
```

### Buffer Lifecycle

```
beads-status
  ↓
  User presses 'v' on issue
  ↓
beads-show (detail buffer for that issue)
  ↓
  User presses 'u'
  ↓
Transient menu opens
  ↓
  User selects action
  ↓
bd command runs
  ↓
Buffer refreshes
```

### Key Abstractions

- `beads-issue` struct - Holds parsed issue data
- `beads--run-json` - Execute bd command and parse JSON
- `beads--get-issues` - Fetch and cache all issues
- `beads--render-status-buffer` - Render main status view
- Text properties - Store issue IDs for navigation

## Next Steps

To continue development:

1. **Section Folding**
   - Implement section markers
   - Add TAB binding to toggle sections

2. **Filter/Search**
   - Add filter transient
   - Implement in-buffer filtering

3. **Dependencies**
   - Dependency transient menu
   - Inline dependency tree rendering

4. **Polish**
   - Better error messages
   - Loading indicators
   - Async command execution

5. **Integration**
   - Org-mode link handler
   - Magit status section

## Feedback Welcome!

This is a proof-of-concept. Try it out and provide feedback on:
- UI/UX feel compared to magit
- Missing features you'd want
- Performance with larger issue sets
- Keybinding choices
- Visual presentation
