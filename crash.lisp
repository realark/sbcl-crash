(in-package :cl-user)

(eval-when (:compile-toplevel :load-toplevel :execute)
  (ql:quickload :cffi)
  #+win32
  (load-shared-object "callyouback.dll")
  #+linux
  (load-shared-object "./callyouback.so")

  (defvar *sem* (sb-thread:make-semaphore :count 0))
  (defvar *callback-lock* (sb-thread:make-mutex))

  (defun lisp-callback ()
    (sb-thread:signal-semaphore *sem*)
    ;; this will run on the foreign thread callback
    (format T "~A : in callback waiting on mutex~%" (sb-thread:thread-name sb-thread:*current-thread*))
    (sb-thread:grab-mutex *callback-lock*)
    (sb-thread:release-mutex *callback-lock*)
    (sb-thread:signal-semaphore *sem*)
    (format T "~A : callback complete.~%" (sb-thread:thread-name sb-thread:*current-thread*)))

  (cffi:defcallback mycallback :void ()
    (lisp-callback)))

(defun run-crash-demo ()
  (format T "~A: Starting main lisp on thread~%" (sb-thread:thread-name sb-thread:*current-thread*))
  (sb-thread:grab-mutex *callback-lock*)
  ;; run our lisp callback
  (sb-thread:make-thread (lambda ()
                           (cffi:foreign-funcall "reg" :pointer (cffi:callback mycallback) :void)))

  ;; wait until the callback is active
  (format T "~A: Wait on sem ~A.~%" (sb-thread:thread-name sb-thread:*current-thread*) *sem*)
  (sb-thread:wait-on-semaphore *sem*)
  ;; BUG! Do a gc while the callback frame is active. Crashes on windows.
  (format T "~A: Doing a full GC.~%" (sb-thread:thread-name sb-thread:*current-thread*))
  (sb-ext:gc :full T)
  (format T "~A: Cleaning up.~%" (sb-thread:thread-name sb-thread:*current-thread*))
  ;; shouldn't make it here, but if we did let's clean up.
  (sb-thread:release-mutex *callback-lock*)
  (sb-thread:wait-on-semaphore *sem*)
  (format T "~A: Crash demo finished.~%" (sb-thread:thread-name sb-thread:*current-thread*)))
