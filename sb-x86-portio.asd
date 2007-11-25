(defpackage :sb-x86-portio.system
  (:use :cl :asdf))

(in-package :sb-x86-portio.system)

(defsystem :sb-x86-portio
  :components ((:file "sb-x86-portio-emission")
               (:file "sb-x86-portio" :depends-on ("sb-x86-portio-emission"))))