(in-package :cl-user)
(eval-when (:compile-toplevel :load-toplevel :execute)
  (ql:quickload '(:sdl2-mixer :cffi)))

(defvar *sem* (sb-thread:make-semaphore :count 0))
(defvar *callback-lock* (sb-thread:make-mutex))

(cffi:defcallback postmix-callback :void ((udata :pointer) (stream :pointer) (len :int))
  (declare (ignore udata stream len))
  (sb-thread:signal-semaphore *sem*)
  ;; this will run on the foreign thread callback
  (format T "~A : in callback waiting on mutex~%" (sb-thread:thread-name sb-thread:*current-thread*))
  (sb-thread:grab-mutex *callback-lock*)
  (sb-thread:release-mutex *callback-lock*)
  (sb-thread:signal-semaphore *sem*)
  (format T "~A : callback complete.~%" (sb-thread:thread-name sb-thread:*current-thread*)))

(defun %set-postmix-callback (callback &optional udata)
  (unwind-protect
       (progn
         (sdl2-ffi.functions:sdl-lock-audio-device 1)
         (sdl2-ffi.functions:mix-set-post-mix callback udata))
    (sdl2-ffi.functions:sdl-unlock-audio-device 1)))

(defun run-crash-demo ()
  (format T "~A: Starting main lisp on thread~%" (sb-thread:thread-name sb-thread:*current-thread*))
  (sb-thread:grab-mutex *callback-lock*)
  (sdl2-mixer:init)
  (sdl2-mixer:open-audio 44100 :s16sys 2 2048)
  (sdl2-mixer:allocate-channels 2)
  (%set-postmix-callback (cffi:callback postmix-callback))

  ;; wait until the callback is active
  (format T "~A: Wait on sem ~A.~%" (sb-thread:thread-name sb-thread:*current-thread*) *sem*)
  (sb-thread:wait-on-semaphore *sem*)

  ;; BUG!!!
  ;; Do a gc while the callback frame is active. Crashes on windows.
  (format T "~A: Doing a full GC.~%" (sb-thread:thread-name sb-thread:*current-thread*))
  (sb-ext:gc :full T)

  (format T "~A: Cleaning up.~%" (sb-thread:thread-name sb-thread:*current-thread*))
  ;; shouldn't make it here, but if we did let's clean up.
  (sb-thread:release-mutex *callback-lock*)
  (sb-thread:wait-on-semaphore *sem*)
  (format T "~A: Crash demo finished.~%" (sb-thread:thread-name sb-thread:*current-thread*))
  (%set-postmix-callback (cffi:null-pointer))
  (loop :while (/= 0 (sdl2-mixer:init 0)) :do
       (sdl2-mixer:quit)))
