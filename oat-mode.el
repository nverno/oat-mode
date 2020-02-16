;;; oat-mode.el --- Emacs mode for editing Oat source -*- lexical-binding: t; -*-

;; This is free and unencumbered software released into the public domain.

;; Author: Noah Peart <noah.v.peart@gmail.com>
;; URL: https://github.com/nverno/oat-mode
;; Package-Requires:
;; Created: 16 February 2020

;; This file is not part of GNU Emacs.
;;
;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 3, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth
;; Floor, Boston, MA 02110-1301, USA.
;;
;;; Description:
;;; Commentary:
;;
;; Derives from `cc-mode', so uses the c-lang interface to modify variables
;; inherited from `java-mode'.
;; 
;; Just using `java-mode' is pretty reasonable already, but this specializes
;; to oat's grammar and removes java's (or most of it).
;; Java handles the `int[] var` style syntax well
;;
;; Lang-dependent code in cc-font.el/cc-langs.el
;;
;;; Installation:
;;
;; Just add to `load-path' and generate autoloads or
;; ```lisp
;; (require 'oat-mode)
;;```
;;; Code:
(eval-when-compile
  (require 'cl-lib)
  (require 'cc-langs)
  (require 'cc-fonts))
(require 'cc-mode)

(defgroup oat nil
  "Major mode for editing Oat source files."
  :group 'languages
  :prefix "oat-")

(defcustom oat-indent-offset 2
  "Amount by which expressions are indented."
  :type 'integer
  :group 'oat)

(defcustom oat-font-lock-extra-types java-font-lock-extra-types
  "List of extra types to recognize (regexps)."
  :type 'sexp
  :group 'oat)

;;; Modifications of java's defaults -- `c-lang-constants'
;; 
;; `c-constant-kwds' are fine => null, true, false
;; `c-paren-stmt-key' already handles vars in for loops

(eval-and-compile (c-add-language 'oat-mode 'java-mode))

(c-lang-defconst c-primitive-type-kwds oat '("void" "int" "string" "bool" "var"))
(c-lang-defconst c-simple-stmt-kwds oat '("return"))
(c-lang-defconst c-type-list-kwds oat '("new"))
;; (c-lang-defconst c-modifier-kwds oat '("global"))
(c-lang-defconst c-block-stmt-kwds oat '("else" "for" "if" "while"))
(c-lang-defconst c-keywords
  oat '("else" "false" "for" "global" "if" "new" "null" "return" "true" "void"
        "while" "struct"))
(c-lang-defconst c-prefix-spec-kwds oat '("struct"))
(c-lang-defconst c-defun-type-name-decl-kwds oat '("struct"))
(c-lang-defconst c-arithmetic-operators
  oat '("*" "+" "-" "~" "<<" ">>" ">>>" "<" "<=" ">" ">=" "==" "!=" "&" "|"
        "[&]" "[|]"))

;; remove all these keywords from oat's font-locking
(eval-when-compile
  (defmacro oat:undef-c-consts (&rest kwds)
    (macroexp-progn
     (cl-loop for kwd in kwds
        collect `(c-lang-defconst ,kwd oat nil)))))

(oat:undef-c-consts
 c-inexpr-class-kwds
 c-primary-expr-kwds
 c-brace-list-decl-kwds
 c-before-label-kwds
 c-block-stmt-1-2-kwds
 c-ref-list-kwds
 c-label-kwds
 c-other-decl-kwds
 c-case-kwds
 c-postfix-decl-spec-kwds
 c-ref-list
 c-modifier-kwds)

(defconst oat-font-lock-keywords-1 (c-lang-const c-matchers-1 oat))
(defconst oat-font-lock-keywords-2 (c-lang-const c-matchers-2 oat))
(defconst oat-font-lock-keywords-3 (c-lang-const c-matchers-3 oat))
(defvar oat-font-lock-keywords
  ;; XXX: how to add '?' here -- this doesn't work
  (append '(("\\?" . 'font-lock-preprocessor-face)) oat-font-lock-keywords-3)
  "Default expressions to highlight in `oat-mode'.")

(defun oat-font-lock-keywords-2 ()
  (c-compose-keywords-list oat-font-lock-keywords-2))
(defun oat-font-lock-keywords-3 ()
  (c-compose-keywords-list oat-font-lock-keywords-3))
(defun oat-font-lock-keywords ()
  (c-compose-keywords-list oat-font-lock-keywords))

;; -------------------------------------------------------------------
;;; Indentation

;; linux style handles proper indentation of final '}' in structs
(add-to-list 'c-default-style '(oat-mode . "linux"))

;; handles indentation in struct fields, since the last element
;; has no trailing semicolon
(defun oat-lineup-statement (langelem)
  (let ((in-assign (c-lineup-assignments langelem)))
    (if (not in-assign) '- '++)))

;; use C syntax
(defvar oat-mode-syntax-table nil)

;;;###autoload
(define-derived-mode oat-mode prog-mode "Oat"
  "Major mode for editing oat files.

\\{oat-mode-map}"
  :after-hook (c-update-modeline)
  :syntax-table c-mode-syntax-table     ; C-style comments

  ;; initialize cc-mode stuff
  (c-initialize-cc-mode t)
  ;; (2/15/20) `c-last-open-c-comment-start-on-line-re' declared obsolete,
  ;; but, I don't see a way to avoid the warning
  ;; Note: appears to have been fixed (2/16/20) -- after which remove
  ;; XXX: remove the `with-no-warnings'
  (with-no-warnings (c-init-language-vars oat-mode))
  (c-common-init 'oat-mode)
  (setq-local comment-start "/* ")
  (setq-local comment-end " */")

  ;; if? / nullable <type>?
  (modify-syntax-entry ?? "w")
  (font-lock-add-keywords 'oat-mode '(("\\?" . 'font-lock-preprocessor-face)))

  ;; indentation
  (setq c-basic-offset oat-indent-offset)
  ;; indentation after last struct field / lineup var assignments
  (c-set-offset 'inher-cont #'c-lineup-multi-inher)
  (c-set-offset 'statement-cont #'oat-lineup-statement)
  (c-set-offset 'statement 0)
  (c-run-mode-hooks 'c-mode-common-hook))

;;;###autoload(add-to-list 'auto-mode-alist '("\\.oat\\'" . oat-mode))

(provide 'oat-mode)
;; Local Variables:
;; coding: utf-8
;; indent-tabs-mode: nil
;; End:
;;; oat-mode.el ends here
