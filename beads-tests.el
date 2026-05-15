;;; beads-tests.el --- Tests for beads.el -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'beads)

(ert-deftest beads-command-args-keeps-argv-lists ()
  (should (equal (beads--command-args '("update" "bd-1" "--claim"))
                 '("update" "bd-1" "--claim"))))

(ert-deftest beads-run-json-appends-json-flag-as-argv ()
  (let (captured)
    (cl-letf (((symbol-function 'beads--run-command)
               (lambda (command)
                 (setq captured command)
                 "[]")))
      (should (equal (beads--run-json '("show" "bd-1")) nil))
      (should (equal captured '("show" "bd-1" "--json"))))))

(ert-deftest beads-create-with-title-preserves-spaces-and-quotes ()
  (let (captured)
    (cl-letf (((symbol-function 'beads--run-command)
               (lambda (command)
                 (setq captured command)
                 ""))
              ((symbol-function 'read-string)
               (lambda (&rest _args)
                 "Fix \"quoted\" title with spaces"))
              ((symbol-function 'derived-mode-p)
               (lambda (&rest _args) nil)))
      (beads-create-with-title '("--description=Body text" "--labels=one,two")))
    (should (equal captured
                   '("create"
                     "Fix \"quoted\" title with spaces"
                     "--description=Body text"
                     "--labels=one,two")))))

(ert-deftest beads-close-issue-preserves-spaces-and-quotes ()
  (let (captured)
    (cl-letf (((symbol-function 'beads--run-command)
               (lambda (command)
                 (setq captured command)
                 ""))
              ((symbol-function 'beads--issue-at-point)
               (lambda () "bd-9"))
              ((symbol-function 'read-string)
               (lambda (&rest _args)
                 "Completed \"carefully\" with spaces"))
              ((symbol-function 'beads-refresh)
               (lambda (&rest _args) nil)))
      (beads-close-issue))
    (should (equal captured
                   '("close"
                     "bd-9"
                     "--reason"
                     "Completed \"carefully\" with spaces")))))

(ert-deftest beads-change-assignee-preserves-spaces ()
  (let (captured)
    (cl-letf (((symbol-function 'beads--run-command)
               (lambda (command)
                 (setq captured command)
                 ""))
              ((symbol-function 'beads--issue-at-point)
               (lambda () "bd-12"))
              ((symbol-function 'read-string)
               (lambda (&rest _args)
                 "Dean Giberson"))
              ((symbol-function 'beads-refresh)
               (lambda (&rest _args) nil)))
      (beads-change-assignee))
    (should (equal captured
                   '("update" "bd-12" "--assignee" "Dean Giberson")))))

(provide 'beads-tests)
;;; beads-tests.el ends here
