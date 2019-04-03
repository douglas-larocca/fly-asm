;;; fly-asm.el --- Minor mode for inspecting C/C++ compiler output

;; Author: Douglas La Rocca <larocca@larocca.io>
;; URL: https://github.com/douglas-larocca/fly-asm
;; Version: 0.1.3

;;; Commentary:

;;; TODO:

;;; Code:

(require 'nasm-mode)

(defgroup fly-asm nil
  "Minor mode for inspecting C/C++ compiler output"
  :prefix "fly-asm-"
  :link '(url-link :tag "Website for fly-asm"
                   "https://github.com/douglas-larocca/fly-asm")
  :group 'programming)

(defcustom fly-asm-dialect "intel"
  "assembly dialect to use for output"
  :type 'string
  :group 'fly-asm)

(defcustom fly-asm-source-language "c"
  "source language"
  :type 'string
  :group 'fly-asm)

(defcustom fly-asm-compilers '("gcc" "clang")
  "default compiler"
  :type 'list
  ;; :type 'string
  :group 'fly-asm)

(defcustom fly-asm-optimization-level 1
  "default optimization level"
  :type 'integer
  :group 'fly-asm)

(defcustom fly-asm-compiler-options
  '("-fno-asynchronous-unwind-tables")
  "Extra options to pass to the compiler"
  :type 'list
  :group 'fly-asm)

(defun fly-asm-filter-directives (buffer)
  "XXX not finished, replace regexp below with
regular expressions to test"
  (with-current-buffer buffer
    (save-excursion
      (goto-char 0)
      (while (not (eobp))
        (beginning-of-line)
        (if (or (looking-at "regexp"))
            (let ((eol (save-excursion (end-of-line) (point))))
              (delete-region (point) eol)))
        (forward-line)))))

(defun fly-asm-trim-string (string)
  "Remove white spaces in beginning and ending of STRING.
White space here is any of: space, tab, newline."
  (replace-regexp-in-string "\\`[ \t\n]*" ""
                            (replace-regexp-in-string "[ \t\n]*\\'" "" string)))

(defun fly-asm-command-fstring ()
  (mapconcat 'identity
             (append fly-asm-compiler-options
                     '("-masm=%s -m64 -O%d -S -o /dev/stdout -x%s -")) " "))

(defmacro fly-asm-compiler-args (&rest l)
  `(let ((fstring (fly-asm-command-fstring)))
     (split-string (format fstring ,@l))))

(defun fly-asm-process-filter (proc output)
  (when (buffer-live-p (process-buffer proc))
    (with-current-buffer (process-buffer proc)
      (let ((moving (= (point) (process-mark proc))))
        (save-excursion
          (goto-char (process-mark proc))
          (insert output)
          (set-marker (process-mark proc) (point)))
        (if moving (goto-char (process-mark proc)))))))

(defun fly-asm-process-sentinel (proc event)
  (let ((e (fly-asm-trim-string event)))
    (pcase e
      (`"finished"
       (display-buffer (process-buffer proc) 'other-window))
      (_ (message "%s" e)))))

(defun fly-asm-start-procs (compiler-commands)
  (let ((process-connection-type nil))
    (mapcar (lambda (compiler-command)
              (eval `(start-process "*fly-asm*"
                                    "*fly-asm-output*"
                                    ,@compiler-command)))
            compiler-commands)))

(defun fly-asm--build-comment-header (cmd)
  (mapconcat 'identity (cons ";;\n;;" (append cmd '("\n;;\n"))) " "))

(defun fly-asm-run-procs (start end procs cmds)
  (let* ((proc (car procs))
         (cmd (car cmds))
         (buf (process-buffer proc)))
    (progn
      (set-process-filter proc 'fly-asm-process-filter)
      (set-process-sentinel proc 'fly-asm-process-sentinel)
      (process-send-region proc start end)
      (with-current-buffer buf
        (process-send-eof proc)
        (fly-asm-process-filter proc 
          (fly-asm--build-comment-header cmd)))
      (if (eql nil (cdr procs))
          (with-current-buffer (process-buffer proc)
            (goto-char (point-min))
            (funcall 'nasm-mode))
        (fly-asm-run-procs start end (cdr procs) (cdr cmds))))))

(defun comment-filter (start end &optional delete)
  ;; TODO: implement file-level options, e.g.
  ;; // fly-asm
  ;; // optimization-level: 1
  ;; // compiler-args: -fno-omit-frame-pointer
  nil)

(defun fly-asm--read-region-comments (start end)
  (let* ((filter-buffer-substring-function 'comment-filter)
         (comment-lines (filter-buffer-substring start end)))
    (when comment-lines
      (message comment-lines))))

(defun fly-asm-send-region (start end)
  (interactive "r")
  (progn
    (fly-asm--read-region-comments start end)
    (let* ((compiler-args
            (fly-asm-compiler-args fly-asm-dialect
                                   fly-asm-optimization-level
                                   fly-asm-source-language))
           (compiler-commands
            (mapcar (lambda (cc)
                      (cons cc compiler-args))
                    fly-asm-compilers))
           (procs (fly-asm-start-procs compiler-commands)))
      (progn
        (with-current-buffer (get-buffer "*fly-asm-output*")
          (erase-buffer))
        (fly-asm-run-procs start
                           end
                           procs
                           compiler-commands)))))

(defvar fly-asm-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c <C-return>") 'fly-asm-send-region))
  "Keymap for fly-asm-mode.")

;;;###autoload
(define-minor-mode fly-asm-mode
  "Minor mode for inspecting C/C++ compiler output."
  :lighter " flyasm"
  :keymap fly-asm-mode-map
  :group 'fly-asm)

;;;###autoload
(defun fly-asm-mode-enable ()
  "Enable `fly-asm-mode'."
  (fly-asm-mode 1))

;;;###autoload
(defun fly-asm-mode-disable ()
  "Disable `fly-asm-mode'."
  (fly-asm-mode 0))

(provide 'fly-asm)
;;; fly-asm.el ends here
