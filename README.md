# beads.el

A magit-inspired Emacs interface for [Beads](https://github.com/beadsinc/beads) issue tracking.

## What is Beads?

Beads is a lightweight, local-first issue tracking system that stores issues in a SQLite database within your project directory (`.beads/`). It's designed for developers who want fast, offline issue tracking without the overhead of web-based tools.

## What is beads.el?

beads.el provides a complete Emacs interface for Beads, modeled after magit's design philosophy:
- **Single entry point** with a status buffer showing your work at a glance
- **Single-key commands** for all common operations
- **Transient menus** for complex operations like creating and updating issues
- **Keyboard-driven workflow** that keeps you in Emacs

## Features

- **Status Buffer** - Overview of ready work, in-progress issues, blocked items, and recent updates
- **Single-Key Commands** - `c` create, `u` update, `v` view, `k` close, `s` start work, and more
- **Transient Menus** - Interactive menus for creating and updating issues with all options
- **Detail View** - Full issue information with inline actions
- **Ready Work Buffer** - Focused view of issues ready to work on, grouped by priority
- **Issue Caching** - Smart caching with 30-second TTL for snappy performance
- **Visual Clarity** - Color-coded priorities, status symbols, and clean layouts
- **Project Integration** - Auto-detects `.beads/` directory in your project

## Requirements

- Emacs 27.1 or later
- [Beads CLI](https://github.com/beadsinc/beads) (`bd` command) installed and in PATH
- `transient` package (usually bundled with magit)

## Installation

### Manual Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/beads.el.git ~/.emacs.d/beads.el
   ```

2. Add to your Emacs configuration:
   ```elisp
   (add-to-list 'load-path "~/.emacs.d/beads.el")
   (require 'beads)

   ;; Optional: Set up keybindings
   (global-set-key (kbd "C-c b s") #'beads-status)
   (global-set-key (kbd "C-c b c") #'beads-create-transient)
   (global-set-key (kbd "C-c b r") #'beads-ready)
   ```

### Using use-package

```elisp
(use-package beads
  :load-path "~/.emacs.d/beads.el"
  :bind (("C-c b s" . beads-status)
         ("C-c b c" . beads-create-transient)
         ("C-c b r" . beads-ready))
  :config
  ;; Optional: customize settings
  (setq beads-auto-refresh-interval 60)
  (setq beads-default-priority 2))
```

## Quick Start

### Try the Demo

1. Run the demo setup script to create sample data:
   ```bash
   ./demo-setup.sh
   ```

2. In Emacs, load beads.el:
   ```
   M-x load-file RET beads.el RET
   ```

3. Open the status buffer:
   ```
   M-x beads-status RET
   ```

### Basic Workflow

1. **View your work** - `M-x beads-status` or `C-c b s`
2. **Create an issue** - Press `c` in the status buffer, configure options, press `c` again
3. **View details** - Navigate to an issue and press `v` or `RET`
4. **Start work** - Press `s` on an issue to mark it as in_progress
5. **Update status** - Press `u` to open the update transient menu
6. **Close issue** - Press `k` and enter a close reason

## Keybindings

### In Status Buffer

| Key | Command | Description |
|-----|---------|-------------|
| `c` | Create issue | Opens transient menu for creating new issues |
| `v`, `RET` | View issue | Show full issue details |
| `u` | Update issue | Opens transient menu for updating |
| `s` | Start work | Mark issue as in_progress |
| `k` | Close issue | Close issue with reason |
| `y` | Copy ID | Copy issue ID to kill ring |
| `r`, `g` | Refresh | Refresh buffer (C-u to force) |
| `W` | Ready work | Open focused ready work buffer |
| `S` | Statistics | Show statistics |
| `q` | Quit | Quit buffer |
| `?` | Help | Show keybindings |

### In Detail Buffer

| Key | Command | Description |
|-----|---------|-------------|
| `u` | Update | Update this issue |
| `k` | Close | Close this issue |
| `r`, `g` | Refresh | Refresh buffer |
| `q` | Quit | Quit buffer |

### In Ready Work Buffer

| Key | Command | Description |
|-----|---------|-------------|
| `v`, `RET` | View issue | Show full issue details |
| `s` | Start work | Mark as in_progress |
| `u` | Update | Update issue |
| `k` | Close | Close issue |
| `y` | Copy ID | Copy issue ID |
| `r`, `g` | Refresh | Refresh buffer |
| `q` | Quit | Quit buffer |

## Configuration

```elisp
;; Auto-refresh interval (seconds, nil to disable)
(setq beads-auto-refresh-interval 60)

;; Default priority for new issues (0-4)
(setq beads-default-priority 2)

;; Number of recent updates to show in status buffer
(setq beads-status-recent-count 5)

;; Custom priority colors
(setq beads-priority-faces
      '((0 . error)    ; P0 - Critical (red)
        (1 . warning)  ; P1 - High (yellow/orange)
        (2 . default)  ; P2 - Medium (default)
        (3 . shadow)   ; P3 - Low (dimmed)
        (4 . shadow))) ; P4 - Backlog (dimmed)
```

## Documentation

- **[EMACS_DEMO.md](EMACS_DEMO.md)** - Comprehensive demo guide with examples and workflows
- **[EMACS_INTERFACE.md](EMACS_INTERFACE.md)** - Full specification and design documentation
- **[INTERFACE_MOCKUP.txt](INTERFACE_MOCKUP.txt)** - Visual mockups of all buffers

## Screenshots

See [INTERFACE_MOCKUP.txt](INTERFACE_MOCKUP.txt) for visual examples of:
- Status buffer layout
- Issue detail view
- Transient menus for creating and updating issues

## Current Status

beads.el is a **working prototype** suitable for daily use. The core functionality is complete:

- ✅ Status buffer with multiple sections
- ✅ Create, update, and close issues
- ✅ Transient menus for complex operations
- ✅ Detail view with full issue information
- ✅ Ready work focused buffer
- ✅ Issue caching and project detection

### Future Enhancements

- Section folding/expansion (TAB)
- Dependency management transient
- Filter transient for advanced queries
- Org-mode integration (links, export)
- Magit integration (status section)
- Embark actions
- Async operations for long-running commands
- Auto-refresh timer

## Contributing

Contributions are welcome! Areas that could use help:
- Testing with large issue databases
- Performance optimization
- Additional transient menus (dependencies, filters)
- Integration with other Emacs packages
- Documentation improvements

## License

Copyright (c) 2025 Dean Giberson

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## Acknowledgments

- Inspired by [magit](https://magit.vc/)'s excellent interface design
- Built for [Beads](https://github.com/beadsinc/beads) issue tracking

## Questions?

See the [demo guide](EMACS_DEMO.md) for detailed usage examples and the [interface specification](EMACS_INTERFACE.md) for complete documentation.
