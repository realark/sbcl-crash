(require 'asdf)
;; (load "~/quicklisp/setup.lisp")
(in-package :cl-user)
(ql:quickload :cffi)

(load-shared-object "./callyouback.so")

(defun lisp-callback ()
  ;; this will run on the foreign thread callback
  ;; (format T "lisp callback on thread: ~A~%" sb-thread:*current-thread*)
  )

(cffi:defcallback mycallback :void ()
                  (lisp-callback))


;;;; Main thread

(format T "Starting main lisp on thread ~A~%" sb-thread:*current-thread*)

(loop for i from 0 to 100000 do
     (cffi:foreign-funcall "reg" :pointer (cffi:callback mycallback) :void))

(format T "Program finished~%")
