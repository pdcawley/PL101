(define (kons kar kdr)
  (lambda (cmd args)
    (cond ((= cmd 'kar) kar)
          ((= cmd 'kdr) kdr)
          ((= cmd 'knull?) #f)
          ((= cmd 'ktype) 'pair)
          ((= cmd 'set-kar!) (set! kar (car args)))
          ((= cmd 'set-kdr!) (set! cdr (car args)))
          (else error "Bad command: " 'cmd))))

(define *the-empty-kons*
  (lambda (cmd args)
    (cond ((= cmd 'null?) #t)
          ((= cmd 'ktype) 'null)
          (else error "Command " 'cmd
                "expects argument of type <pair>; given '()"))))

(define (kar kons) (kons 'kar ()))
(define (kdr kons) (kons 'kdr ()))
(define (knull? kons) (kons 'knull? ()))
(define (set-kar! kons val) (kons 'set-kar (list val)))
(define (set-kdr! kons val) (kons 'set-kdr (list val)))
(define (kpair? kons) (= (kons 'ktype ()) 'pair))
