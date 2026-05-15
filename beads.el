;;; beads.el --- Magit-like interface for Beads issue tracker -*- lexical-binding: t; -*-

;; Copyright (C) 2025

;; Author: Beads Contributors
;; Version: 0.2.0
;; Package-Requires: ((emacs "28.1") (transient "0.4.0"))
;; Keywords: tools, vc
;; URL: https://github.com/steveyegge/beads

;;; Commentary:

;; A magit-like interface for the Beads issue tracker.
;; Provides a status buffer, issue details, and transient menus
;; for managing issues with keyboard-driven commands.
;;
;; Quick Start:
;;   M-x beads-status    - Open main status buffer
;;   M-x beads-ready     - Open ready work buffer
;;
;; Key Bindings (in status buffer):
;;   c - Create issue    v/RET - View details    u - Update issue
;;   k - Close issue     s - Start work          r/g - Refresh
;;   y - Copy issue ID   ? - Help

;;; Code:

(require 'cl-lib)
(require 'transient)
(require 'json)
(require 'subr-x)

;;; Customization

(defgroup beads nil
  "Magit-like interface for Beads issue tracker."
  :group 'tools)

(defcustom beads-auto-refresh-interval 60
  "Auto-refresh interval in seconds, or nil to disable."
  :type '(choice (const :tag "Disabled" nil)
                 (integer :tag "Seconds"))
  :group 'beads)

(defcustom beads-default-priority 2
  "Default priority for new issues (0=highest, 4=lowest)."
  :type 'integer
  :group 'beads)

(defcustom beads-status-recent-count 5
  "Number of recent updates to show in status buffer."
  :type 'integer
  :group 'beads)

(defcustom beads-ready-limit 50
  "Maximum number of ready issues to fetch and display.
Set to a large number to show all ready issues."
  :type 'integer
  :group 'beads)

(defcustom beads-priority-faces
  '((0 . error)
    (1 . warning)
    (2 . default)
    (3 . shadow)
    (4 . shadow))
  "Alist mapping priority levels to face names."
  :type '(alist :key-type integer :value-type face)
  :group 'beads)

(defcustom beads-status-symbols
  '((open . "○")
    (in_progress . "◐")
    (blocked . "●")
    (deferred . "❄")
    (pinned . "📌")
    (hooked . "◇")
    (closed . "✓"))
  "Symbols for issue statuses."
  :type '(alist :key-type symbol :value-type string)
  :group 'beads)

(defcustom beads-show-statistics t
  "Whether to show statistics in status buffer."
  :type 'boolean
  :group 'beads)

(defcustom beads-enable-auto-refresh nil
  "Whether to enable auto-refresh timer.
Set to non-nil to automatically refresh every `beads-auto-refresh-interval' seconds."
  :type 'boolean
  :group 'beads)

;;; Data Structures

(cl-defstruct beads-issue
  "Represents a Beads issue."
  id title type status priority
  assignee labels description notes
  created-at updated-at closed-at
  dependencies)

(cl-defstruct beads-dependency
  "Represents a dependency between issues."
  from to type)

;;; Core Variables

(defvar-local beads--current-project nil
  "Current project directory for this buffer.")

(defvar-local beads--refresh-timer nil
  "Auto-refresh timer for current buffer.")

(defvar-local beads--issues-cache nil
  "Cached list of issues for current buffer.")

(defvar-local beads--cache-time nil
  "Time when issues cache was last updated.")

(defvar-local beads--current-issue-id nil
  "Current issue ID being displayed in this buffer (for detail views).")

;;; Utility Functions

(defun beads--find-project-root ()
  "Find the project root directory containing .beads/."
  (or beads--current-project
      (let ((dir (locate-dominating-file default-directory ".beads")))
        (when dir
          (expand-file-name dir)))))

(defun beads--project-label (&optional project)
  "Return abbreviated project label for buffer names."
  (if project
      (directory-file-name (abbreviate-file-name project))
    "unknown"))

(defun beads--command-args (command)
  "Normalize COMMAND into a list of bd argv strings."
  (cond
   ((null command) nil)
   ((listp command) command)
   ((stringp command) (split-string-and-unquote command))
   (t (user-error "Invalid bd command args: %S" command))))

(defun beads--run-command (command)
  "Run bd COMMAND and return output as string.
COMMAND may be a list of argv strings or a shell-like string.
Returns nil and displays error message if command fails."
  (let ((default-directory (or (beads--find-project-root)
                               default-directory))
        (args (beads--command-args command)))
    (condition-case err
        (with-temp-buffer
          (let ((stdout-buffer (current-buffer))
                (stderr-file (make-temp-file "beads-stderr-")))
            (unwind-protect
                (let ((exit-code
                       (apply #'process-file "bd" nil
                              (list stdout-buffer stderr-file) nil
                              args))
                      (stdout "")
                      (stderr ""))
                  (setq stdout (string-trim-right (buffer-string)))
                  (with-temp-buffer
                    (insert-file-contents stderr-file)
                    (setq stderr (string-trim (buffer-string))))
                  (cond
                   ((and (integerp exit-code) (zerop exit-code))
                    (when (and (not (string-empty-p stderr))
                               (not (string-empty-p stdout)))
                      (message "bd warning: %s" stderr))
                    (unless (string-empty-p stderr)
                      (when (string-empty-p stdout)
                        (message "bd warning: %s" stderr)))
                    stdout)
                   (t
                    (user-error "bd command failed: %s"
                                (if (string-empty-p stderr)
                                    (format "exit code %s" exit-code)
                                  stderr)))))
              (delete-file stderr-file))))
      (error
       (message "Failed to run bd command: %s" (error-message-string err))
       nil))))

(defun beads--run-json (command)
  "Run bd COMMAND and parse JSON output.
Returns nil and displays error message if parsing fails."
  (when-let* ((output (beads--run-command
                       (append (beads--command-args command)
                               '("--json")))))
    (let* ((json-array-type 'list)
           (json-object-type 'alist)
           (json-false nil))
      (condition-case err
          (json-read-from-string output)
        (json-parse-error
         (message "Failed to parse JSON from bd: %s" output)
         nil)
        (error
         (message "Unexpected error parsing JSON: %s" (error-message-string err))
         nil)))))

(defun beads--format-time-ago (timestamp)
  "Format TIMESTAMP as relative time ago."
  (if (not timestamp)
      "never"
    (let* ((time (if (stringp timestamp)
                     (date-to-time timestamp)
                   timestamp))
           (diff (time-subtract (current-time) time))
           (seconds (time-to-seconds diff)))
      (cond
       ((< seconds 60) "just now")
       ((< seconds 3600) (format "%dm ago" (/ seconds 60)))
       ((< seconds 86400) (format "%dh ago" (/ seconds 3600)))
       ((< seconds 604800) (format "%dd ago" (/ seconds 86400)))
       (t (format-time-string "%Y-%m-%d" time))))))

(defun beads--priority-face (priority)
  "Get face for PRIORITY level."
  (if priority
      (or (cdr (assoc priority beads-priority-faces))
          'default)
    'default))

(defun beads--status-symbol (status)
  "Get symbol for STATUS."
  (if (and status (stringp status))
      (or (cdr (assoc (intern status) beads-status-symbols))
          "?")
    "?"))

(defun beads--priority-name (priority)
  "Get human-readable name for PRIORITY."
  (if priority
      (pcase priority
        (0 "Critical")
        (1 "High")
        (2 "Medium")
        (3 "Low")
        (4 "Backlog")
        (_ "Unknown"))
    "Unknown"))

(defun beads--calculate-statistics (issues)
  "Calculate statistics from ISSUES list."
  (let ((total (length issues))
        (by-status (make-hash-table :test 'equal))
        (by-priority (make-hash-table :test 'equal)))
    (dolist (issue issues)
      (let ((status (beads-issue-status issue))
            (priority (beads-issue-priority issue)))
        (puthash status (1+ (gethash status by-status 0)) by-status)
        (puthash priority (1+ (gethash priority by-priority 0)) by-priority)))
    (list :total total
          :by-status by-status
          :by-priority by-priority)))

(defun beads--parse-issue (data)
  "Parse issue DATA from JSON alist."
  (make-beads-issue
   :id (alist-get 'id data)
   :title (alist-get 'title data)
   :type (or (alist-get 'issue_type data) (alist-get 'type data))
   :status (alist-get 'status data)
   :priority (alist-get 'priority data)
   :assignee (alist-get 'assignee data)
   :labels (alist-get 'labels data)
   :description (alist-get 'description data)
   :notes (alist-get 'notes data)
   :created-at (alist-get 'created_at data)
   :updated-at (alist-get 'updated_at data)
   :closed-at (alist-get 'closed_at data)
   :dependencies (or (alist-get 'dependents data) (alist-get 'dependencies data))))

;;; Data Fetching

(defun beads--get-issues (&optional force-refresh)
  "Get all issues, using cache unless FORCE-REFRESH is non-nil."
  (when (or force-refresh
            (not beads--issues-cache)
            (not beads--cache-time)
            (> (time-to-seconds (time-subtract (current-time) beads--cache-time))
               30))
    (let ((data (beads--run-json '("list" "--all"))))
      (setq beads--issues-cache (mapcar #'beads--parse-issue data)
            beads--cache-time (current-time))))
  beads--issues-cache)

(defun beads--get-ready-issues ()
  "Get ready work issues."
  (let ((data (beads--run-json
               (list "ready" "--limit" (number-to-string beads-ready-limit)))))
    (mapcar #'beads--parse-issue data)))

(defun beads--get-issue-by-id (id)
  "Get issue by ID."
  (let ((data (beads--run-json (list "show" id))))
    (when data
      ;; bd show returns an array with a single object, extract first element
      (beads--parse-issue (if (listp data) (car data) data)))))

;;; Status Buffer Rendering

(defun beads--insert-separator ()
  "Insert a visual separator line."
  (insert (propertize (make-string 70 ?─) 'face 'shadow) "\n"))

(defun beads--insert-section-header (title count &optional may-have-more)
  "Insert section header with TITLE and COUNT.
If MAY-HAVE-MORE is non-nil, append '+' to indicate more items may exist."
  (insert (propertize title 'face 'bold))
  (when count
    (insert (propertize (format " (%d%s)" count (if may-have-more "+" ""))
                        'face 'shadow)))
  (insert "\n"))

(defun beads--insert-issue-line (issue &optional show-status)
  "Insert a single line for ISSUE.
If SHOW-STATUS is non-nil, include status symbol."
  (let* ((id (beads-issue-id issue))
         (priority (or (beads-issue-priority issue) 2))
         (status (or (beads-issue-status issue) "unknown"))
         (type (or (beads-issue-type issue) "unknown"))
         (title (or (beads-issue-title issue) "Untitled"))
         (assignee (beads-issue-assignee issue))
         (labels (beads-issue-labels issue))
         (face (beads--priority-face priority))
         (line-start (point)))
    ;; Status symbol (if requested)
    (when show-status
      (insert (propertize (format "%s " (beads--status-symbol status))
                          'face face)))
    ;; Issue ID
    (insert (propertize (format "%-8s " id) 'face face))
    ;; Priority
    (insert (propertize (format "P%d " priority) 'face face))
    ;; Type
    (insert (propertize (format "[%-7s] " type) 'face 'italic))
    ;; Title (truncate if too long)
    (let* ((max-title-len (if show-status 38 42))
           (truncated (truncate-string-to-width title max-title-len 0 nil "…"))
           (padded (format (format "%%-%ds " max-title-len) truncated)))
      (insert (propertize padded 'face face)))
    ;; Assignee
    (if assignee
        (insert (propertize (format "@%s" assignee) 'face 'success))
      (insert (propertize "(none)" 'face 'shadow)))
    ;; Labels (if any)
    (when labels
      (insert " ")
      (insert (propertize (format "[%s]" (string-join labels ","))
                          'face 'font-lock-keyword-face)))
    (insert "\n")
    ;; Add text property for the issue ID
    (put-text-property line-start (point) 'beads-issue-id id)))

(defun beads--filter-issues-by-status (issues status)
  "Filter ISSUES by STATUS."
  (seq-filter (lambda (issue)
                (string= (beads-issue-status issue) status))
              issues))

(defun beads--insert-status-section (issues status title empty-message)
  "Insert a status section for ISSUES matching STATUS using TITLE.
Show EMPTY-MESSAGE when there are no matching issues."
  (let ((matches (beads--filter-issues-by-status issues status)))
    (beads--insert-section-header title (length matches))
    (if matches
        (dolist (issue matches)
          (beads--insert-issue-line issue))
      (insert (propertize empty-message 'face 'shadow)))
    (insert "\n")))

(defun beads--render-status-buffer ()
  "Render the main status buffer."
  (let ((inhibit-read-only t)
        (project (beads--find-project-root))
        (issues (beads--get-issues))
        (ready-issues (beads--get-ready-issues)))
    (erase-buffer)

    ;; Header
    (insert (propertize (format "Beads Status [%s]\n"
                                (abbreviate-file-name (or project default-directory)))
                        'face 'bold))
    (beads--insert-separator)

    ;; Statistics (if enabled)
    (when (and beads-show-statistics issues)
      (let* ((stats (beads--calculate-statistics issues))
             (total (plist-get stats :total))
             (by-status (plist-get stats :by-status))
             (by-priority (plist-get stats :by-priority)))
        (insert "\n")
        (insert (propertize "Summary: " 'face 'bold))
        (insert (format "%d total | " total))
        (insert (format "%d ready | " (length ready-issues)))
        (insert (format "%d in-progress | "
                        (gethash "in_progress" by-status 0)))
        (insert (format "%d blocked | "
                        (gethash "blocked" by-status 0)))
        (insert (format "%d deferred | "
                        (gethash "deferred" by-status 0)))
        (insert (format "%d hooked | "
                        (gethash "hooked" by-status 0)))
        (insert (format "%d pinned | "
                        (gethash "pinned" by-status 0)))
        (insert (format "P0:%d P1:%d P2:%d Closed:%d\n"
                        (gethash 0 by-priority 0)
                        (gethash 1 by-priority 0)
                        (gethash 2 by-priority 0)
                        (gethash "closed" by-status 0)))
        (insert "\n")))
    (insert "\n")

    ;; Ready Work section
    (let ((may-have-more (and ready-issues
                              (>= (length ready-issues) beads-ready-limit))))
      (beads--insert-section-header "Ready Work" (length ready-issues) may-have-more))
    (if ready-issues
        (dolist (issue ready-issues)
          (beads--insert-issue-line issue))
      (insert (propertize "  (no ready work)\n" 'face 'shadow)))
    (insert "\n")

    ;; Additional status sections
    (beads--insert-status-section issues "in_progress" "In Progress"
                                  "  (nothing in progress)\n")
    (beads--insert-status-section issues "blocked" "Blocked"
                                  "  (no blocked issues)\n")
    (beads--insert-status-section issues "hooked" "Hooked"
                                  "  (no hooked issues)\n")
    (beads--insert-status-section issues "deferred" "Deferred"
                                  "  (no deferred issues)\n")
    (beads--insert-status-section issues "pinned" "Pinned"
                                  "  (no pinned issues)\n")

    ;; Recent Updates section (closed issues sorted by updated_at)
    (let* ((closed (beads--filter-issues-by-status issues "closed"))
           (recent (seq-take (seq-sort-by #'beads-issue-updated-at
                                          #'string>
                                          closed)
                            beads-status-recent-count)))
      (beads--insert-section-header "Recent Updates" (length recent))
      (if recent
          (dolist (issue recent)
            (let ((time-ago (beads--format-time-ago (beads-issue-updated-at issue))))
              (insert (propertize (format "  %-8s  Closed %-10s  [%-7s] %s\n"
                                          (beads-issue-id issue)
                                          time-ago
                                          (beads-issue-type issue)
                                          (truncate-string-to-width
                                           (beads-issue-title issue) 38 0 nil "…"))
                                  'face 'shadow
                                  'beads-issue-id (beads-issue-id issue)))))
        (insert (propertize "  (no recent updates)\n" 'face 'shadow)))
      (insert "\n"))

    ;; Footer
    (beads--insert-separator)
    (insert (propertize "Commands: " 'face 'bold))
    (insert "c create  v view  u update  k close  s start-work  y copy-id\n")
    (insert (propertize "          " 'face 'bold))
    (insert "r refresh  W ready-buffer  ? help  q quit\n")

    (goto-char (point-min))))

;;; Detail Buffer Rendering

(defun beads--format-dependency (dep-data)
  "Format a single dependency DEP-DATA as a clickable line."
  (let* ((id (alist-get 'id dep-data))
         (title (alist-get 'title dep-data))
         (status (alist-get 'status dep-data))
         (priority (alist-get 'priority dep-data))
         (type (or (alist-get 'issue_type dep-data) (alist-get 'type dep-data)))
         (face (beads--priority-face priority))
         (line-start (point)))
    (insert "  ")
    ;; Status symbol
    (insert (propertize (format "%s " (beads--status-symbol status)) 'face face))
    ;; Issue ID (clickable)
    (insert (propertize (format "%-12s " (or id "unknown")) 'face face))
    ;; Priority
    (when priority
      (insert (propertize (format "P%d " priority) 'face face)))
    ;; Type
    (when type
      (insert (propertize (format "[%-7s] " type) 'face 'italic)))
    ;; Title
    (insert (propertize (or title "Untitled") 'face face))
    (insert "\n")
    ;; Make the whole line clickable
    (when id
      (put-text-property line-start (point) 'beads-issue-id id))))

(defun beads--render-detail-buffer (issue)
  "Render detail buffer for ISSUE."
  (let ((inhibit-read-only t))
    (erase-buffer)

    ;; Header
    (insert (propertize (format "Issue: %s  %s\n"
                                (or (beads-issue-id issue) "unknown")
                                (beads--status-symbol (beads-issue-status issue)))
                        'face 'bold))
    (beads--insert-separator)

    ;; Metadata
    (insert (propertize "Title:       " 'face 'bold)
            (format "%s\n" (or (beads-issue-title issue) "Untitled")))
    (insert (propertize "Type:        " 'face 'bold)
            (propertize (or (beads-issue-type issue) "unknown") 'face 'italic) "\n")
    (insert (propertize "Status:      " 'face 'bold)
            (format "%s\n" (or (beads-issue-status issue) "unknown")))
    (insert (propertize "Priority:    " 'face 'bold)
            (let ((priority (or (beads-issue-priority issue) 2)))
              (propertize (format "P%d (%s)\n"
                                  priority
                                  (beads--priority-name priority))
                          'face (beads--priority-face priority))))
    (insert (propertize "Assignee:    " 'face 'bold)
            (if (beads-issue-assignee issue)
                (propertize (format "@%s" (beads-issue-assignee issue))
                            'face 'success)
              (propertize "(unassigned)" 'face 'shadow))
            "\n")

    (when (beads-issue-labels issue)
      (insert (propertize "Labels:      " 'face 'bold)
              (propertize (mapconcat #'identity (beads-issue-labels issue) ", ")
                          'face 'font-lock-keyword-face)
              "\n"))

    (insert (propertize "Created:     " 'face 'bold)
            (format "%s (%s)\n"
                    (beads-issue-created-at issue)
                    (beads--format-time-ago (beads-issue-created-at issue))))
    (insert (propertize "Updated:     " 'face 'bold)
            (format "%s (%s)\n"
                    (beads-issue-updated-at issue)
                    (beads--format-time-ago (beads-issue-updated-at issue))))

    (when (beads-issue-closed-at issue)
      (insert (propertize "Closed:      " 'face 'bold)
              (format "%s (%s)\n"
                      (beads-issue-closed-at issue)
                      (beads--format-time-ago (beads-issue-closed-at issue)))))

    (insert "\n")

    ;; Description
    (when (and (beads-issue-description issue)
               (not (string-empty-p (beads-issue-description issue))))
      (insert (propertize "Description:\n" 'face 'bold))
      (insert (beads-issue-description issue))
      (insert "\n\n"))

    ;; Notes
    (when (and (beads-issue-notes issue)
               (not (string-empty-p (beads-issue-notes issue))))
      (insert (propertize "Notes:\n" 'face 'bold))
      (insert (beads-issue-notes issue))
      (insert "\n\n"))

    ;; Dependencies
    (insert (propertize "Dependencies:\n" 'face 'bold))
    (let ((deps (beads-issue-dependencies issue)))
      (if (and deps (listp deps) (> (length deps) 0))
          (progn
            (dolist (dep deps)
              (beads--format-dependency dep))
            (insert "\n"))
        (insert (propertize "  (none)\n\n" 'face 'shadow))))

    ;; Footer
    (beads--insert-separator)
    (insert (propertize "Commands: " 'face 'bold))
    (insert "v view-dependency  u update  s start-work  k close\n")
    (insert (propertize "          " 'face 'bold))
    (insert "y copy-id  r refresh  q quit\n")

    (goto-char (point-min))))

;;; Interactive Commands

(defun beads-refresh (&optional force)
  "Refresh current beads buffer.
With prefix arg FORCE, clear cache before refreshing."
  (interactive "P")
  (when force
    (setq beads--issues-cache nil
          beads--cache-time nil))
  (cond
   ((derived-mode-p 'beads-status-mode)
    (beads--render-status-buffer)
    (message "Refreshed beads status"))
   ((derived-mode-p 'beads-ready-mode)
    (beads--render-ready-buffer)
    (message "Refreshed ready work"))
   ((derived-mode-p 'beads-show-mode)
    (when-let* ((id (or beads--current-issue-id
                        (get-text-property (point) 'beads-issue-id))))
      (let ((issue (beads--get-issue-by-id id)))
        (when issue
          (beads--render-detail-buffer issue)
          (message "Refreshed issue %s" id)))))
   (t
    (message "Not in a beads buffer"))))

(defun beads--issue-at-point ()
  "Get the issue ID at point.
In detail buffers, returns the current issue ID.
Otherwise, looks for the beads-issue-id text property."
  (or (and (derived-mode-p 'beads-show-mode)
           beads--current-issue-id)
      (get-text-property (point) 'beads-issue-id)))

(defun beads-show-issue (id)
  "Show details for issue ID."
  (interactive
   (list (or (beads--issue-at-point)
             (read-string "Issue ID: "))))
  (when id
    (let* ((project (beads--find-project-root))
           (issue (beads--get-issue-by-id id))
           (buf-name (format "*beads: %s [%s]*"
                             id
                             (beads--project-label project))))
      (if issue
          (let ((buf (get-buffer-create buf-name)))
            (with-current-buffer buf
              (beads-show-mode)
              (setq beads--current-project project)
              (setq beads--current-issue-id id)
              (beads--render-detail-buffer issue))
            (pop-to-buffer buf))
        (message "Issue %s not found" id)))))

;;;###autoload
(defun beads-status ()
  "Show Beads status buffer."
  (interactive)
  (let ((project (beads--find-project-root)))
    (unless project
      (user-error "Not in a Beads project (no .beads/ directory found)"))
    (let* ((buf-name (format "*beads-status: %s*"
                             (beads--project-label project)))
           (buf (get-buffer-create buf-name)))
      (with-current-buffer buf
        (beads-status-mode)
        (setq beads--current-project project)
        (beads--render-status-buffer))
      (pop-to-buffer buf))))

(defun beads-quit ()
  "Quit current beads buffer."
  (interactive)
  (quit-window t))

(defun beads-copy-issue-id ()
  "Copy issue ID at point to kill ring."
  (interactive)
  (if-let* ((id (beads--issue-at-point)))
      (progn
        (kill-new id)
        (message "Copied %s to kill ring" id))
    (user-error "No issue at point")))

(defun beads-start-work ()
  "Start work on issue at point using Beads claim semantics."
  (interactive)
  (if-let* ((id (beads--issue-at-point)))
      (progn
        (beads--run-command (list "update" id "--claim"))
        (message "Started work on %s" id)
        (beads-refresh))
    (user-error "No issue at point")))

;;;###autoload
(defun beads-ready ()
  "Show ready work buffer with focused view of ready issues."
  (interactive)
  (let ((project (beads--find-project-root)))
    (unless project
      (user-error "Not in a Beads project (no .beads/ directory found)"))
    (let* ((buf-name (format "*beads-ready: %s*"
                             (beads--project-label project)))
           (buf (get-buffer-create buf-name)))
      (with-current-buffer buf
        (beads-ready-mode)
        (setq beads--current-project project)
        (beads--render-ready-buffer))
      (pop-to-buffer buf))))

(defun beads--render-ready-buffer ()
  "Render the ready work buffer."
  (let ((inhibit-read-only t)
        (project (beads--find-project-root))
        (ready-issues (beads--get-ready-issues)))
    (erase-buffer)

    ;; Header
    (insert (propertize (format "Ready Work [%s]\n"
                                (abbreviate-file-name (or project default-directory)))
                        'face 'bold))
    (let ((count (length ready-issues))
          (may-have-more (>= (length ready-issues) beads-ready-limit)))
      (insert (propertize (format "Sorted by priority • %d%s %s ready\n"
                                  count
                                  (if may-have-more "+" "")
                                  (if (= count 1) "issue" "issues"))
                          'face 'shadow)))
    (beads--insert-separator)
    (insert "\n")

    (if ready-issues
        ;; Group by priority
        (let ((by-priority (make-hash-table :test 'equal)))
          ;; Group issues
          (dolist (issue ready-issues)
            (let* ((priority (beads-issue-priority issue))
                   (existing (gethash priority by-priority)))
              (puthash priority (cons issue existing) by-priority)))

          ;; Display each priority group
          (dolist (priority '(0 1 2 3 4))
            (let ((issues (reverse (gethash priority by-priority))))
              (when issues
                (insert (propertize (format "P%d - %s (%d)\n"
                                            priority
                                            (beads--priority-name priority)
                                            (length issues))
                                    'face (beads--priority-face priority)))
                (dolist (issue issues)
                  (beads--insert-issue-line issue))
                (insert "\n")))))
      (insert (propertize "  No ready work available.\n\n" 'face 'shadow))
      (insert (propertize "  Issues may be blocked, already claimed, deferred, hooked, or otherwise not claimable yet.\n"
                          'face 'shadow)))

    ;; Footer
    (insert "\n")
    (beads--insert-separator)
    (insert (propertize "Commands: " 'face 'bold))
    (insert "v view  s start-work  u update  k close  r refresh  q quit\n")

    (goto-char (point-min))))

(defun beads-statistics ()
  "Show project statistics."
  (interactive)
  (let* ((issues (beads--get-issues t))
         (stats (beads--calculate-statistics issues)))
    (message "Total: %d | Open: %d | In Progress: %d | Blocked: %d | Closed: %d"
             (plist-get stats :total)
             (gethash "open" (plist-get stats :by-status) 0)
             (gethash "in_progress" (plist-get stats :by-status) 0)
             (gethash "blocked" (plist-get stats :by-status) 0)
             (gethash "closed" (plist-get stats :by-status) 0))))

;;; Transient Menus

(transient-define-prefix beads-create-transient ()
  "Create a new Beads issue."
  ["Type"
   ("-t" "task" "--type=task")
   ("-f" "feature" "--type=feature")
   ("-b" "bug" "--type=bug")
   ("-e" "epic" "--type=epic")
   ("-h" "chore" "--type=chore")]
  ["Priority"
   ("-0" "P0 (Critical)" "--priority=0")
   ("-1" "P1 (High)" "--priority=1")
   ("-2" "P2 (Medium)" "--priority=2")
   ("-3" "P3 (Low)" "--priority=3")
   ("-4" "P4 (Backlog)" "--priority=4")]
  ["Options"
   ("-a" "Assignee" "--assignee=")
   ("-l" "Labels" "--labels=")
   ("-d" "Description" "--description=")]
  ["Actions"
   ("c" "Create with title" beads-create-with-title)
   ("q" "Quit" transient-quit-one)])

(defun beads-create-with-title (&optional args)
  "Create issue with ARGS from transient."
  (interactive (list (transient-args 'beads-create-transient)))
  (let ((title (read-string "Issue title: ")))
    (beads--run-command (append (list "create" title) args))
    (message "Created issue: %s" title)
    (when (derived-mode-p 'beads-status-mode)
      (beads-refresh))))

(transient-define-prefix beads-update-transient ()
  "Update an issue."
  ["Status"
   ("s" "open" (lambda () (interactive) (beads-set-status "open")))
   ("i" "in_progress" (lambda () (interactive) (beads-set-status "in_progress")))
   ("b" "blocked" (lambda () (interactive) (beads-set-status "blocked")))
   ("c" "closed" (lambda () (interactive) (beads-set-status "closed")))]
  ["Priority"
   ("0" "P0" (lambda () (interactive) (beads-set-priority 0)))
   ("1" "P1" (lambda () (interactive) (beads-set-priority 1)))
   ("2" "P2" (lambda () (interactive) (beads-set-priority 2)))
   ("3" "P3" (lambda () (interactive) (beads-set-priority 3)))
   ("4" "P4" (lambda () (interactive) (beads-set-priority 4)))]
  ["Actions"
   ("a" "Change assignee" beads-change-assignee)
   ("q" "Quit" transient-quit-one)])

(defun beads-set-status (status)
  "Set STATUS for issue at point."
  (if-let* ((id (beads--issue-at-point)))
      (progn
        (beads--run-command (list "update" id "--status" status))
        (message "Set %s to %s" id status)
        (beads-refresh))
    (user-error "No issue at point")))

(defun beads-set-priority (priority)
  "Set PRIORITY for issue at point."
  (if-let* ((id (beads--issue-at-point)))
      (progn
        (beads--run-command
         (list "update" id "--priority" (number-to-string priority)))
        (message "Set %s priority to P%d" id priority)
        (beads-refresh))
    (user-error "No issue at point")))

(defun beads-change-assignee ()
  "Change assignee for issue at point."
  (interactive)
  (if-let* ((id (beads--issue-at-point)))
      (let ((assignee (read-string "Assignee: ")))
        (beads--run-command (list "update" id "--assignee" assignee))
        (message "Assigned %s to %s" id assignee)
        (beads-refresh))
    (user-error "No issue at point")))

(defun beads-close-issue ()
  "Close issue at point."
  (interactive)
  (if-let* ((id (beads--issue-at-point)))
      (let ((reason (read-string "Close reason: " "Completed")))
        (beads--run-command (list "close" id "--reason" reason))
        (message "Closed %s" id)
        (beads-refresh))
    (user-error "No issue at point")))

;;; Mode Definitions

(defvar beads-status-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "c") #'beads-create-transient)
    (define-key map (kbd "u") #'beads-update-transient)
    (define-key map (kbd "v") #'beads-show-issue)
    (define-key map (kbd "RET") #'beads-show-issue)
    (define-key map (kbd "k") #'beads-close-issue)
    (define-key map (kbd "s") #'beads-start-work)
    (define-key map (kbd "y") #'beads-copy-issue-id)
    (define-key map (kbd "r") #'beads-refresh)
    (define-key map (kbd "g") #'beads-refresh)
    (define-key map (kbd "W") #'beads-ready)
    (define-key map (kbd "S") #'beads-statistics)
    (define-key map (kbd "q") #'beads-quit)
    (define-key map (kbd "?") #'describe-mode)
    map)
  "Keymap for `beads-status-mode'.")

(define-derived-mode beads-status-mode special-mode "Beads-Status"
  "Major mode for Beads status buffer.

Shows an overview of all issues organized by status with ready work,
in-progress, blocked, and recently updated sections.

Key bindings:
\\<beads-status-mode-map>
\\[beads-create-transient] - Create new issue
\\[beads-show-issue] - View issue details
\\[beads-update-transient] - Update issue
\\[beads-close-issue] - Close issue
\\[beads-start-work] - Start work (set to in_progress)
\\[beads-copy-issue-id] - Copy issue ID
\\[beads-refresh] - Refresh buffer
\\[beads-ready] - Open ready work buffer
\\[beads-statistics] - Show statistics
\\[describe-mode] - Show this help
\\[beads-quit] - Quit buffer

\\{beads-status-mode-map}"
  (setq-local revert-buffer-function #'beads-refresh)
  (setq truncate-lines t))

(defvar beads-show-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "v") #'beads-show-issue)
    (define-key map (kbd "RET") #'beads-show-issue)
    (define-key map (kbd "u") #'beads-update-transient)
    (define-key map (kbd "s") #'beads-start-work)
    (define-key map (kbd "k") #'beads-close-issue)
    (define-key map (kbd "y") #'beads-copy-issue-id)
    (define-key map (kbd "r") #'beads-refresh)
    (define-key map (kbd "g") #'beads-refresh)
    (define-key map (kbd "q") #'beads-quit)
    (define-key map (kbd "?") #'describe-mode)
    map)
  "Keymap for `beads-show-mode'.")

(define-derived-mode beads-show-mode special-mode "Beads-Show"
  "Major mode for Beads issue detail buffer.

Shows full details for a single issue including metadata, description,
notes, and dependencies.

Key bindings:
\\<beads-show-mode-map>
\\[beads-show-issue] - View dependency details (when on a dependency line)
\\[beads-update-transient] - Update issue
\\[beads-start-work] - Start work (set to in_progress)
\\[beads-close-issue] - Close issue
\\[beads-copy-issue-id] - Copy issue ID
\\[beads-refresh] - Refresh
\\[describe-mode] - Show this help
\\[beads-quit] - Quit buffer

\\{beads-show-mode-map}"
  (setq-local revert-buffer-function #'beads-refresh)
  (setq truncate-lines nil))

(defvar beads-ready-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "v") #'beads-show-issue)
    (define-key map (kbd "RET") #'beads-show-issue)
    (define-key map (kbd "s") #'beads-start-work)
    (define-key map (kbd "u") #'beads-update-transient)
    (define-key map (kbd "k") #'beads-close-issue)
    (define-key map (kbd "y") #'beads-copy-issue-id)
    (define-key map (kbd "r") #'beads-refresh)
    (define-key map (kbd "g") #'beads-refresh)
    (define-key map (kbd "q") #'beads-quit)
    (define-key map (kbd "?") #'describe-mode)
    map)
  "Keymap for `beads-ready-mode'.")

(define-derived-mode beads-ready-mode special-mode "Beads-Ready"
  "Major mode for Beads ready work buffer.

Shows a focused view of ready work grouped by priority.

Key bindings:
\\<beads-ready-mode-map>
\\[beads-show-issue] - View issue details
\\[beads-start-work] - Start work (set to in_progress)
\\[beads-update-transient] - Update issue
\\[beads-close-issue] - Close issue
\\[beads-copy-issue-id] - Copy issue ID
\\[beads-refresh] - Refresh buffer
\\[describe-mode] - Show this help
\\[beads-quit] - Quit buffer

\\{beads-ready-mode-map}"
  (setq-local revert-buffer-function
              (lambda (&rest _) (beads--render-ready-buffer)))
  (setq truncate-lines t))

;;; Footer

(provide 'beads)

;;; beads.el ends here
