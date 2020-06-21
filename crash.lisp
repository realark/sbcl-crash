(in-package :cl-user)

(eval-when (:compile-toplevel :load-toplevel :execute)
  (ql:quickload :cffi))

(eval-when (:compile-toplevel :load-toplevel :execute)
  #+cffi
  (progn
    #+linux
    (unless (cffi:list-foreign-libraries)
      (cffi:load-foreign-library "./libSDL2-2.0.so.0")
      (cffi:load-foreign-library "./libSDL2_mixer-2.0.so.0"))
    (ql:quickload '(:sdl2-mixer))))

(cffi:defcallback postmix-callback :void ((udata :pointer) (stream :pointer) (len :int))
  (declare (ignore udata stream len))
  ;; just make a bunch of garbage on a foreign thread callback
  (loop :for i :from 0 :below 100 :do
       (make-array 100000 :initial-element (random 73) :adjustable t)))

(defun %set-postmix-callback (callback &optional udata)
  (unwind-protect
       (progn
         (sdl2-ffi.functions:sdl-lock-audio-device 1)
         (sdl2-ffi.functions:mix-set-post-mix callback udata))
    (sdl2-ffi.functions:sdl-unlock-audio-device 1)))

(defun init-mixer ()
  (sdl2-mixer:init)
  (sdl2-mixer:open-audio 44100 :s16sys 2 2048)
  (sdl2-mixer:allocate-channels 2)
  (%set-postmix-callback (cffi:callback postmix-callback)))

(defun run-crash-demo ()
  (init-mixer)

  ;; foreign thread is making garbage. LDB should appear soon.
  (sleep 30)

  ;; oops. Guess we didn't crash. I'll clean up I guess.
  (loop :while (/= 0 (sdl2-mixer:init 0)) :do
       (sdl2-mixer:quit)))
