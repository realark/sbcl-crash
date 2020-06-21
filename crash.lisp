(in-package :cl-user)
(eval-when (:compile-toplevel :load-toplevel :execute)
  (ql:quickload :cffi)
  #+cffi
  (progn
    #+linux
    (unless (cffi:list-foreign-libraries)
      (cffi:load-foreign-library "./libSDL2-2.0.so.0")
      (cffi:load-foreign-library "./libSDL2_mixer-2.0.so.0"))
    (ql:quickload '(:sdl2-mixer))))

(defvar *sem* (sb-thread:make-semaphore :count 0))
(defvar *callback-lock* (sb-thread:make-mutex))

(cffi:defcallback postmix-callback :void ((udata :pointer) (stream :pointer) (len :int))
  (declare (ignore udata stream len))
  ;; (sb-thread:signal-semaphore *sem*) ; let other threads know our callback is running
  ;; (format T "~A : in callback waiting on mutex~%" (sb-thread:thread-name sb-thread:*current-thread*))
  ;; (loop :for i :from 0 :below 10 :do
  ;;      (sb-ext:gc :full T))
  ;; (sb-thread:grab-mutex *callback-lock*)
  ;; (sb-thread:release-mutex *callback-lock*)
  ;; (sb-thread:signal-semaphore *sem*)
  (my-callback)
  ;; (format T "~A : callback complete.~%" (sb-thread:thread-name sb-thread:*current-thread*))
  )

(defun my-callback ()
  ;; (format T "~A : in callback waiting on mutex~%" (sb-thread:thread-name sb-thread:*current-thread*))
  (gc-churn)
  )

(defun %set-postmix-callback (callback &optional udata)
  (unwind-protect
       (progn
         (sdl2-ffi.functions:sdl-lock-audio-device 1)
         (sdl2-ffi.functions:mix-set-post-mix callback udata))
    (sdl2-ffi.functions:sdl-unlock-audio-device 1)))

(defun init-mixer ()
  (sb-thread:grab-mutex *callback-lock*)
  (sdl2-mixer:init)
  (sdl2-mixer:open-audio 44100 :s16sys 2 2048)
  (sdl2-mixer:allocate-channels 2)
  (%set-postmix-callback (cffi:callback postmix-callback)))

(defun run-crash-demo ()
  (format T "~A: Starting main lisp on thread~%" (sb-thread:thread-name sb-thread:*current-thread*))
  (init-mixer)

  ;; wait until the callback is active
  (format T "~A: Wait on sem ~A.~%" (sb-thread:thread-name sb-thread:*current-thread*) *sem*)
  (sb-ext:gc :full T)
  (sb-thread:wait-on-semaphore *sem*)

  ;; BUG!!!
  ;; Do a gc while the callback frame is active. Crashes on windows.
  (format T "~A: Doing a full GC.~%" (sb-thread:thread-name sb-thread:*current-thread*))
  (gc-churn)

  (format T "~A: Cleaning up.~%" (sb-thread:thread-name sb-thread:*current-thread*))
  ;; shouldn't make it here, but if we did let's clean up.
  (sb-thread:release-mutex *callback-lock*)
  (sb-thread:wait-on-semaphore *sem*)
  (format T "~A: Crash demo finished.~%" (sb-thread:thread-name sb-thread:*current-thread*))
  (%set-postmix-callback (cffi:null-pointer))
  (loop :while (/= 0 (sdl2-mixer:init 0)) :do
       (sdl2-mixer:quit)))

(defun gc-churn ()
  ;; (sb-ext:gc :full T) ; weirdly enough, doing an explicit GC avoids a crash
  (loop :for i :from 0 :below 100 :do
       (make-array 100000 :initial-element (random 73) :adjustable t)))
