;;; org-editmarks.el --- Edit marks for org-mode



;;; Commentary:
;; This library provides a set of org-mode links for making "edit marks" in an
;; org-file. These are:
;; [[comment:some text]]
;; [[insert:some text]]
;; [[delete:some text]]
;; [[typo:mispeling]]

;; It has org-mode link limitations. So, don't include line breaks in the links.

;; The links export to LaTeX as todonotes, or colored text.
;; #+LATEX_HEADER: \usepackage[colorinlistoftodos]{todonotes}
;;
;; Put these in your org-file
;; \presetkeys{todonotes}{color=blue!30}{}
;; \todotoc
;; \listoftodos

;; Alternatively, use `ox-manuscript-build-with-comments'.

;; This was inspired in part by
;; https://github.com/joostkremers/criticmarkup-emacs. That package lacks
;; org-mode integration for export though. I started the idea here
;; http://kitchingroup.cheme.cmu.edu/blog/2015/04/24/Commenting-in-org-files/,
;; and this code improves on it that approach in some ways. This code differs
;; from org-comment.el
;; (https://www.mail-archive.com/emacs-orgmode@gnu.org/msg96440/org-comment.el)
;; mostly in display of links and functionality.

;;; Code:


(defun em-popup ()
  "Popup menu for editmark link follow action."
  (let ((menu (make-sparse-keymap
	       "Accept/reject/ignore")))
    (define-key menu [em-ignore-editmark-at-point]
      (cons "Ignore" 'em-ignore-editmark-at-point))
    (define-key menu [em-reject-editmark-at-point]
      (cons "Reject" 'em-reject-editmark-at-point))
    (define-key menu [em-accept-editmark-at-point]
      (cons "Accept" 'em-accept-editmark-at-point))
    (call-interactively (car (x-popup-menu t menu)))))


;; * The links
(org-add-link-type
 "comment"
 (lambda (path)
   "Offer to delete the comment."
   (em-popup))
 (lambda (path description format)
   (cond
    ((eq format 'latex)
     (format "\\todo[inline]{%s}%s"
	     path
	     (if description (format "{%s}" description) ""))))))


(org-add-link-type
 "delete"
 (lambda (path)
   (em-popup))
 (lambda (path description format)
   (cond
    ((eq format 'latex)
     (format "\\textcolor{red}{%s}" path)))))


(org-add-link-type
 "insert"
 (lambda (path)
   (em-popup))
 (lambda (path description format)
   (cond
    ((eq format 'latex)
     (format "\\textcolor{blue}{%s}" path)))))


(org-add-link-type
 "typo"
 (lambda (path)
   "Spell check region, and offer to delete."
   (let ((link (org-element-context))
	 (use-dialog-box nil))
     (save-excursion
       (ispell-region (org-element-property :begin link)
		      (org-element-property :end link))
       (em-popup))))
 (lambda (path description format)
   (cond
    ((eq format 'latex)
     (format "\\bold{\\textcolor{red}{%s}}" path)))))


;; ** Link faces and font-lock
(defface em-comment-face
  `((t (:inherit org-link
                 :foreground "DarkOrange1")))
  "Color for comment links.")


(defface em-insert-face
  `((t (:inherit org-link
                 :foreground "blue")))
  "Color for insert links.")


(defface em-delete-face
  `((t (:inherit org-link
                 :foreground "red"
		 :strike-through t)))
  "Color for delete links.")


(defface em-typo-face
  `((t (:inherit org-link
                 :foreground "red"
		 :weight bold)))
  "Color for typo links.")

;; Modified from org-activate-bracket-links.
(defun em-activate-links (link-type face limit)
  "Add text properties for Edit Mark bracketed links.
Argument LINK-TYPE the type of link to activate.
Argument FACE The face to put on the LINK-TYPE.
Argument LIMIT the search limit."
  (while (and (re-search-forward org-bracket-link-regexp limit t)
	      (not (org-in-src-block-p)))
    (let* ((hl (org-match-string-no-properties 1))
	   (type (save-match-data
		   (and (string-match org-plain-link-re hl)
			(match-string-no-properties 1 hl))))
	   help ip vp)
      
      (when (string= type link-type)
	(setq help (concat "LINK: " (save-match-data (org-link-unescape hl)))
	      ip (org-maybe-intangible
		  (list 'invisible 'org-link
			'face face
			'keymap org-mouse-map
			'mouse-face 'highlight
			'font-lock-multiline t
			'help-echo help
			'htmlize-link `(:uri ,hl)))
	      vp (list 'keymap org-mouse-map
		       'face face
		       'mouse-face 'highlight
		       'font-lock-multiline t
		       'help-echo help
		       'htmlize-link `(:uri ,hl)))
	;; We need to remove the invisible property here.  Table narrowing
	;; may have made some of this invisible.
	(org-remove-flyspell-overlays-in (match-beginning 0) (match-end 0))
	(remove-text-properties (match-beginning 0) (match-end 0)
				'(invisible nil))
	(if (match-end 3)
	    (progn
	      (add-text-properties (match-beginning 0) (match-beginning 3) ip)
	      (org-rear-nonsticky-at (match-beginning 3))
	      (add-text-properties (match-beginning 3) (match-end 3) vp)
	      (org-rear-nonsticky-at (match-end 3))
	      (add-text-properties (match-end 3) (match-end 0) ip)
	      (org-rear-nonsticky-at (match-end 0)))
	  (add-text-properties (match-beginning 0) (match-beginning 1) ip)
	  (org-rear-nonsticky-at (match-beginning 1))
	  (add-text-properties (match-beginning 1) (match-end 1) vp)
	  (org-rear-nonsticky-at (match-end 1))
	  (add-text-properties (match-end 1) (match-end 0) ip)
	  (org-rear-nonsticky-at (match-end 0)))
	t))))


(defun em-activate-comments (limit)
  "Function to activate comment links.
Activate to LIMIT."
  (em-activate-links "comment" 'em-comment-face limit))


(defun em-activate-typos (limit)
  "Function to activate typo links.
Activate to LIMIT."
  (em-activate-links "typo" 'em-typo-face limit))


(defun em-activate-inserts (limit)
  "Function to activate insert links.
Activate to LIMIT."
  (em-activate-links "insert" 'em-insert-face limit))


(defun em-activate-deletes (limit)
  "Function to activate delete links.
Activate to LIMIT."
  (em-activate-links "delete" 'em-delete-face limit))


(defun em-font-lock-enable ()
  "Add the font-lock activation functions."
  (font-lock-add-keywords
   nil
   '((em-activate-comments (0  'em-comment-face t))
     (em-activate-typos (0  'em-typo-face t))
     (em-activate-inserts (0  'em-insert-face t))
     (em-activate-deletes (0  'em-delete-face t)))
   t))


(add-hook 'org-mode-hook 'em-font-lock-enable)

;; * Insertion functions


(defun em-comment (comment)
  "Insert a link with COMMENT as the description.
If region is active, it is wrapped in the comment."
  (interactive "sComment: ")
  (if (region-active-p)
      (setf (buffer-substring (region-beginning)
			      (region-end))
	    (format "[[comment:%s][%s]] "
		    comment
		    (buffer-substring (region-beginning) (region-end))))
    (insert (format "[[comment:%s]] "
		    comment))))


(defun em-typo ()
  "Insert a typo link.
If the region is active, enclose it in the link, otherwise wrap the word at point."
  (interactive)
  (if (region-active-p)
      (setf (buffer-substring (region-beginning)
			      (region-end))
	    (format "[[typo:%s]]" (buffer-substring (region-beginning)
						    (region-end))))

    (let ((w (thing-at-point 'word)))
      (backward-char (length w))
      (re-search-forward w)
      (setf (buffer-substring (match-beginning 0) (match-end 0))
	    (format "[[typo:%s]]" (match-string 0))))))


(defun em-insert ()
  "Insert an insert link, or mark the active region for insertion."
  (interactive)
  (if (region-active-p)
      (setf (buffer-substring (region-beginning)
			      (region-end))
	    (format "[[insert:%s]] "
		    (buffer-substring (region-beginning) (region-end))))
    (insert "[[insert:]] ")
    (backward-char 2)))


(defun em-delete (r1 r2)
  "Mark the region from R1 to R2 for deletion."
  (interactive "r")
  (setf (buffer-substring (region-beginning)
			  (region-end))
	(format "[[delete:%s]] "
		(buffer-substring (region-beginning) (region-end))))
  (goto-char (org-element-property :end (org-element-context))))


(defun em-replace (r1 r2)
  "Delete the region R1 to R2 and insert new text."
  (interactive "r")
  (em-delete r1 r2)
  (deactivate-mark)
  (em-insert))


;; * Delete an editmark

(defun em-ignore-editmark-at-point ()
  "Just ignore the editmark at point."
  (interactive)
  nil)


(defun em-accept-editmark-at-point ()
  "Accept the editmark at point.
Remove link markup."
  (interactive)
  (let ((link (org-element-context)))
    (cond
     ;; insert
     ((string= (org-element-property :type link) "insert")
      (setf (buffer-substring (org-element-property :begin link)
			      (org-element-property :end link))
	    (org-element-property :path link)))
     ;; delete
     ((string= (org-element-property :type link) "delete")
      (setf (buffer-substring (org-element-property :begin link)
			      (org-element-property :end link))
	    ""))
     ;; comment
     ((string= (org-element-property :type link) "comment")
      (error "You cannot accept a comment. You can delete it"))
     ;; typo
     ((string= (org-element-property :type link) "typo")
      (setf (buffer-substring
	     (org-element-property :begin link)
	     (org-element-property :end link))
	    (org-element-property :path (org-element-context))))
     
     (t
      (error "%s not implemented" (org-element-property :type link))))))


(defun em-reject-editmark-at-point ()
  "Delete the editmark at point."
  (interactive)
  (let ((link (org-element-context)))
    (cond
     ((member (org-element-property :type link) '("insert"
						  "delete"))
      (setf (buffer-substring (org-element-property :begin link)
			      (org-element-property :end link))
	    ""))
     
     ((string= (org-element-property :type link) "typo")
      (setf (buffer-substring
	     (org-element-property :begin link)
	     (org-element-property :end link))
	    (org-element-property :path (org-element-context))))
     
     ((string= (org-element-property :type link) "comment")
      (setf (buffer-substring (org-element-property :begin link)
			      (org-element-property :end link))
	    (if (org-element-property :contents-begin link)
		;; this is a [[comment:text][wrapped text]]
		(buffer-substring (org-element-property :contents-begin link)
				  (org-element-property :contents-end link))

	      "")))
     (t
      (error "%s not implemented" (org-element-property :type link))))))


(defun em-next-editmark ()
  "Navigate forward to next editmark."
  (interactive)
  (re-search-forward "\\[\\[\\(comment\\|typo\\|insert\\|delete\\):" nil 'mv))


(defun em-previous-editmark ()
  "Navigate backward to previous editmark."
  (interactive)
  (re-search-backward "\\[\\[\\(comment\\|typo\\|insert\\|delete\\):" nil 'mv)
  (forward-char))

;; * See all Edit Marks

(defun em-editmark-candidates ()
  "Provides an alist of editmarks and their beginning position."
  (org-element-map (org-element-parse-buffer) 'link
    (lambda (link)
      (when (member (org-element-property :type link) '("comment"
							"typo"
							"insert"
							"delete"))
	(cons (buffer-substring (org-element-property :begin link)
				(org-element-property :end link))
	      (org-element-property :begin link))))))


(defun em-editmarks ()
  "Show an ivy selection buffer of all the editmarks in the buffer.
The default action is to visit the mark."
  (interactive)
  (ivy-read "Select editmark: " (em-editmark-candidates)
	    :action '(1
		      ("o" (lambda (x)
			     (goto-char x))
		       "open editmark")
		      ("d" (lambda (x)
			     (goto-char x)
			     (em-delete-editmark-at-point))
		       "delete editmark"))))

;; * Keybindings

(define-prefix-command 'em-map)
(global-set-key (kbd "H-e") em-map)

(define-key em-map "t" 'em-typo)
(define-key em-map "c" 'em-comment)
(define-key em-map "i" 'em-insert)
(define-key em-map "d" 'em-delete)
(define-key em-map "r" 'em-replace)
(define-key em-map "k" 'em-reject-editmark-at-point)
(define-key em-map "a" 'em-accept-editmark-at-point)
(define-key em-map "l" 'em-editmarks)

(define-key em-map "n" 'em-next-editmark)
(define-key em-map "p" 'em-previous-editmark)

(provide 'org-editmarks)

;;; org-editmarks.el ends here
