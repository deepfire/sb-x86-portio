;;; -*- Mode: Lisp; indent-tabs-mode: nil -*-

(defsystem :sb-x86-portio
  :components ((:file "sb-x86-portio-emission")
               (:file "sb-x86-portio" :depends-on ("sb-x86-portio-emission"))))
