;;; extend-dnd.el --- R drag and Drop
;; 
;; Filename: extend-dnd.el
;; Description: R Drag and Drop
;; Author: Matthew L. Fidler
;; Maintainer: Matthew L. Fidler
;; Created: Thu Feb  9 09:37:32 2012 (-0600)
;; Version: 0.01
;; Last-Updated: Fri Feb 10 16:14:02 2012 (-0600)
;;           By: Matthew L. Fidler
;;     Update #: 49
;; URL: https://github.com/mlf176f2/extend-dnd
;; Keywords: EXTEND, Drag and Drop
;; Compatibility: Tested with Emacs 24.
;; 
;; Features that might be required by this library:
;;
;;   `assoc', `backquote', `button', `bytecomp', `cconv', `cl',
;;   `dropdown-list', `easymenu', `help-fns', `help-mode',
;;   `macroexp', `view', `warnings', `yasnippet', `yasnippet-bundle'.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 
;;; Commentary: 
;; 
;; Drag and drop files into EXTEND and produce code.  Currently supports
;; only R and CSV but is extendable to other languages.
;;
;; Put this somewhere in your load path and add the following to your
;; .emacs
;;
;; (require 'extend-dnd)
;; (extend-dnd-activate)
;; 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 
;;; Change Log:
;; 
;; 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
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
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 
;;; Code:

(require 'yasnippet nil t)
(require 'yasnippet-bundle nil t)

(defadvice dnd-open-local-file (around extend-import-drag-and-drop activate)
  "* Extended Drag File Support"
  (unless (extend-dnd (ad-get-arg 0))
    ad-do-it))

(defadvice dnd-open-file (around extend-import-drag-and-drop activate)
  "* Extended Drag File Support"
  (unless (extend-dnd (ad-get-arg 0))
    ad-do-it))

(defgroup extend-dnd nil
  "Drag and Drop support for Emacs Speaks Statistics"
  :group 'files)

(defcustom extend-dnd-dirs t
  "Drag and Drop Support for Directories.  Will process each file in the directory."
  :group 'endend-dnd
  :type 'boolean)

(defcustom extend-dnd-supported-files
  '((nxhtml-mode
     (("jpg" "<img src=\"%s\">" format))
     ))
  "Extend Drag and Drop supported files in generic modes, other than `ess-mode'"
  :type '(repeat
	  (list
	   (sexp :tag "Major mode")
	   (repeat 
	    (list
	     (string :tag "Extension")
	     (string :tag "Function Name, Format or Yasnippet key")
	     (choice
	      (const format :tag "Format.  Should include one %s representing the file name")
	      (const function :tag "Function")
	      (const yasnippet :tag "Yasnippet (key of expansion)"))))
	   )))

(defcustom extend-dnd-ess-supported-files
  '(("S"
     (("R"
       (("csv" "read.csv(\"%s\",na.strings=c(\".\",\"NA\"));" format))))))
  "Extend Drag and Drop supported files in Emacs Speaks Statistics"
  :type '(repeat
	  (list
	   (string :tag "ESS Language")
	   (repeat 
	    (list
	     (string :tag "ESS dialect")
	     (repeat 
	      (list
	       (string :tag "Extension")
	       (string :tag "Function Name, Format or Yasnippet key")
	       (choice
		(const format :tag "Format.  Should include one %s representing the file name")
		(const function :tag "Function")
		(const yasnippet :tag "Yasnippet (key of expansion)"))))))))
  :group 'extend-dnd)

(defcustom extend-dnd-relative t
  "Use a relative directory."
  :type 'boolean
  :group 'extend-dnd)

(defvar extend-dnd-active nil
  "Determines if EXTEND drag and drop is active.")

;;;###autoload
(defalias 'extend-drag-and-drop-activate 'extend-dnd-activate)
;;;###autoload
(defun extend-dnd-activate ()
  "Activates extend-dnd"
  (interactive)
  (setq extend-dnd-active t))

(defun extend-dnd-file (file text type )
  "Handle Drag and Drop for FILE of TYPE with TEXT"
  (let ((f file)
	(fn nil))
    (when extend-dnd-relative
      (when (string-match "^[A-Z]:" f)
        (setq f (concat (downcase  (substring f 0 1))
                        (substring f 1))))
      (setq f (file-relative-name f (file-name-directory (buffer-file-name)))))
    (cond
     ((eq type 'format)
      (insert (format text f))
      (insert "\n"))
     ((eq type 'function)
      (setq fn (intern text))
      (when (and fn (functionp fn))
	(funcall fn f)))
     ((eq type 'yasnippet)
      (when (fboundp 'yas/expand-snippet)
	(let (templates)
          (setq templates
                (mapcan #'(lambda (table)
                            (yas/fetch table text))
                        (yas/get-snippet-tables)))
	  (when templates
	    (set-mark (point))
	    (let ((deactivate-mark nil))
	      (insert f))
            (yas/expand-or-prompt-for-template templates))))))))

(defun extend-dnd-dir (dir list)
  "Extended DND on a directory"
  (let ((files (directory-files dir t))
	exts
	ret)
    (mapc (lambda(f)
	    (message "%s,%s" f list)
	    (setq exts (assoc (file-name-extension f) list))
	    (when exts
	      (when (fboundp 'yas/exit-all-snippets)
		(yas/exit-all-snippets))
	      (extend-dnd-file f (nth 1 exts) (nth 2 exts))
	      (setq ret 't)))
	  files)
    (symbol-value 'ret)))

(defun extend-dnd (uri)
  "Extended Drag and drop support"
  (let ((f (dnd-get-local-file-name uri t))
	list
	exts
	pt
	ret)
    (when extend-dnd-active
      (setq exts (assoc major-mode extend-dnd-supported-files))
      (when exts
        (setq list (cadr exts))
        (setq exts (assoc (file-name-extension f) (cadr exts)))
        (if exts
            (progn
              (extend-dnd-file f (nth 1 exts) (nth 2 exts))
              (setq ret 't))
          (unless ret
            (when extend-dnd-dirs
              (setq ret (extend-dnd-dir f list))))))
      (unless ret
        (when (eq major-mode 'ess-mode)
          (setq exts (assoc ess-language extend-dnd-ess-supported-files))
          (when exts
            (setq exts (assoc ess-dialect (cadr exts)))
            (when exts
              (setq list (cadr exts))
              (setq exts (assoc (file-name-extension f) (cadr exts)))
              (if exts
                  (progn
                    (extend-dnd-file f (nth 1 exts) (nth 2 exts))
                    (setq ret 't))
                (when extend-dnd-dirs
                  (setq ret (extend-dnd-dir f list)))))))))
    (symbol-value 'ret)))


;;yas/load-snippet-buffer
  
;; From http://lists.gnu.org/archive/html/bug-gnu-emacs/2001-02/msg00066.html
(defun extend-add-to-alist (alist-var elt-cons &optional no-replace)
  "Add to the value of ALIST-VAR an element ELT-CONS if it isn't there yet.
If an element with the same car as the car of ELT-CONS is already present,
replace it with ELT-CONS unless NO-REPLACE is non-nil; if a matching
element is not already present, add ELT-CONS to the front of the alist.
The test for presence of the car of ELT-CONS is done with `equal'."
  (let ((existing-element (assoc (car elt-cons) (symbol-value alist-var))))
    (if existing-element
        (or no-replace
            (rplacd existing-element (cdr elt-cons)))
      (set alist-var (cons elt-cons (symbol-value alist-var))))))

(defun extend-dnd-yas-add ()
  "Adds currently opened buffer to DND snippet list"
  (interactive)
  (let ((f (buffer-file-name)) key ext mode-lst)
    (when f
      (setq f (file-name-directory f))
      (setq key (file-name-sans-extension (file-name-nondirectory f)))
      (when (string-match "[/\\]\\([^/\\]+\\)[/\\]?$" f)
	(setq f (intern (match-string 1 f)))
	(when f
	  (save-excursion
	    (goto-char (point-min))
	    (when (re-search-forward "# *key: *\\(.*?\\) *$" nil t)
	      (setq key (buffer-substring-no-properties
			 (match-beginning 1) (match-end 1)))))
          (setq ext (read-from-minibuffer "Drag and Drop Extension: "))
	  (when (string-match "^[.]" ext)
	    (setq ext (replace-match "" nil nil ext)))
	  (setq mode-lst (assoc f extend-dnd-supported-files))
          (if mode-lst
	      (progn
		(setq mode-lst (cadr mode-lst))
		(extend-add-to-alist 'mode-lst `(,ext ,key yasnippet))
		(extend-add-to-alist 'extend-dnd-supported-files
				     `(,f ,mode-lst)))
            (add-to-list 'extend-dnd-supported-files
			 `(,f ((,ext ,key yasnippet)))))
          (customize-save-variable 'extend-dnd-supported-files
                                   extend-dnd-supported-files))))))

(defmacro extend-dnd-after-yas (&rest p)
  "Extend dnd after yasnippet load"
  `(progn
     (eval-after-load "yasnippet"
       (define-key snippet-mode-map "\C-c \C-d" 'extend-dnd-yas-add)
       ,@p
       )
     (eval-after-load "yasnippet-bundle"
       ,@p)))
(define-key snippet-mode-map "\C-c\C-d" 'extend-dnd-yas-add)


(provide 'extend-dnd)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; extend-dnd.el ends here
