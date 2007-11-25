(in-package :sb-vm)

(macrolet
    ((def (name width)
       (let ((setfun (intern (format nil "%SET-PORT-~A" name) "SB-VM"))
             (getfun (intern (format nil "PORT-~A" name) "SB-VM")))
         `(progn
            (defun ,setfun (port val) (declare (type (unsigned-byte 16) port) (type (unsigned-byte ,width) val)) (,setfun port val))
            (defun ,getfun (port) (declare (type (unsigned-byte 16) port)) (,getfun port))
            (defsetf ,getfun ,setfun)))))
  (def byte 8)
  (def word 16)
  (def dword 32))
