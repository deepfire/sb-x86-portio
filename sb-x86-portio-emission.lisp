;;;
;;; This is a hurried extract from the sbcl-os hack sources.
;;;

(in-package :sb-vm)

;;;; I/O instructions

(define-instruction in (segment accum port)
  (:emitter
   (aver (accumulator-p accum))
   (aver (or (and (integerp port) (<= 0 port #xff))
             (location= port dx-tn)))
   (let ((size (operand-size accum)))
     (maybe-emit-operand-size-prefix segment size)
     (if (integerp port)
         (progn
           (emit-byte segment (if (eq size :byte) #b11100100 #b11100100))
           (emit-byte segment port))
         (emit-byte segment (if (eq size :byte) #b11101100 #b11101100))))))

(define-instruction out (segment port accum)
  (:emitter
   (aver (accumulator-p accum))
   (aver (or (and (integerp port) (<= 0 port #xff))
             (location= port dx-tn)))
   (let ((size (operand-size accum)))
     (maybe-emit-operand-size-prefix segment size)
     (if (integerp port)
         (progn
           (emit-byte segment (if (eq size :byte) #b11100110 #b11100111))
           (emit-byte segment port))
         (emit-byte segment (if (eq size :byte) #b11101110 #b11101111))))))

;;; I/O access VOPs

(macrolet
    ((def (name width reg)
       (let ((setfun (intern (format nil "%SET-PORT-~A" name) "SB-VM"))
             (getfun (intern (format nil "PORT-~A" name) "SB-VM"))
             (setvop (intern (format nil "%SET-PORT-~A" name)))
             (getvop (intern (format nil "PORT-~A" name)))
             (setvop-c (intern (format nil "%SET-PORT-~A-C" name)))
             (getvop-c (intern (format nil "PORT-~A-C" name))))
         `(progn
            (defknown ,setfun ((unsigned-byte 16) (unsigned-byte ,width))
                (unsigned-byte ,width) ())
            (defknown ,getfun ((unsigned-byte 16))
                (unsigned-byte ,width) ())
            (define-vop (,setvop)
                (:translate ,setfun)
              (:args (port :scs (unsigned-reg) :target edx)
                     (value :scs (unsigned-reg) :target eax))
              (:arg-types unsigned-num unsigned-num)
              (:temporary (:sc unsigned-reg :offset eax-offset :target result :from (:argument 1) :to (:result 0)) eax)
              (:temporary (:sc unsigned-reg :offset edx-offset :from (:argument 0)) edx)
              (:results (result :scs (unsigned-reg)))
              (:result-types unsigned-num)
              (:generator 5
                          (move edx port)
                          (move eax value)
                          (inst out dx-tn ,reg)
                          (move result eax)))
            (define-vop (,setvop-c)
                (:translate ,setfun)
              (:args (value :scs (unsigned-reg) :target eax))
              (:arg-types (:constant (unsigned-byte 8)) unsigned-num)
              (:info port)
              (:temporary (:sc unsigned-reg :offset eax-offset :target result :from (:argument 0) :to (:result 0)) eax)
              (:results (result :scs (unsigned-reg)))
              (:result-types unsigned-num)
              (:generator 4
                          (move eax value)
                          (inst out port ,reg)
                          (move result eax)))
            (define-vop (,getvop)
                (:translate ,getfun)
              (:args (port :scs (unsigned-reg) :target edx))
              (:arg-types unsigned-num)
              (:temporary (:sc unsigned-reg :offset eax-offset :target result :to (:result 0)) eax)
              (:temporary (:sc unsigned-reg :offset edx-offset :from (:argument 0)) edx)
              (:results (result :scs (unsigned-reg)))
              (:result-types unsigned-num)
              (:generator 5
                          (move edx port)
                          ,(unless (= width 32) `(inst xor eax eax))
                          (inst in ,reg dx-tn)
                          (move result eax)))
            (define-vop (,getvop-c)
                (:translate ,getfun)
              (:arg-types (:constant (unsigned-byte 8)))
              (:info port)
              (:temporary (:sc unsigned-reg :offset eax-offset :to (:result 0)) eax)
              (:results (result :scs (unsigned-reg)))
              (:result-types unsigned-num)
              (:generator 4
                          ,(unless (= width 32) `(inst xor eax eax))
                          (inst in ,reg port)
                          (move result eax)))
            (defun ,setfun (val port) (declare (type (unsigned-byte ,width) val) (type (unsigned-byte 16) port)) (,setfun port val))
            (defun ,getfun (port) (declare (type (unsigned-byte 16) port)) (,getfun port))
            (defsetf ,getfun ,setfun)))))
  (def byte 8 al-tn)
  (def word 16 ax-tn)
  (def dword 32 eax-tn))

;;; "String" I/O access
(macrolet
    ((def (name accumulator)
       (let ((rfun (intern (format nil "READ-PORT-~AS" name) "SB-VM"))
             (wfun (intern (format nil "WRITE-PORT-~AS" name) "SB-VM"))
             (rvop (intern (format nil "READ-PORT-~AS" name)))
             (wvop (intern (format nil "WRITE-PORT-~AS" name))))
         `(progn
            (defknown ,rfun ((unsigned-byte 16) system-area-pointer
                             (unsigned-byte 32))
                (values) ())
            (defknown ,wfun ((unsigned-byte 16) system-area-pointer
                             (unsigned-byte 32))
                (values) ())
            (define-vop (,rvop)
                (:translate ,rfun)
              (:args (port :scs (unsigned-reg) :target edx)
                     (dest :scs (sap-reg) :target edi)
                     (count :scs (unsigned-reg) :target ecx))
              (:arg-types unsigned-num system-area-pointer unsigned-num)
              (:temporary (:sc unsigned-reg :offset edx-offset :from (:argument 0)) edx)
              (:temporary (:sc sap-reg :offset edi-offset :from (:argument 1)) edi)
              (:temporary (:sc unsigned-reg :offset ecx-offset :from (:argument 2)) ecx)
              (:generator 4
                          (move edx port)
                          (move edi dest)
                          (move ecx count)
                          (inst cld)
                          (inst rep)
                          (inst ins ,accumulator)))
            (define-vop (,wvop)
                (:translate ,wfun)
              (:args (port :scs (unsigned-reg) :target edx)
                     (source :scs (sap-reg) :target esi)
                     (count :scs (unsigned-reg) :target ecx))
              (:arg-types unsigned-num system-area-pointer unsigned-num)
              (:temporary (:sc unsigned-reg :offset edx-offset :from (:argument 0)) edx)
              (:temporary (:sc sap-reg :offset esi-offset :from (:argument 1)) esi)
              (:temporary (:sc unsigned-reg :offset ecx-offset :from (:argument 2)) ecx)
              (:generator 4
                          (move edx port)
                          (move esi source)
                          (move ecx count)
                          (inst cld)
                          (inst rep)
                          (inst outs ,accumulator)))))))
  (def :byte al-tn)
  (def :word ax-tn)
  (def :dword eax-tn))
