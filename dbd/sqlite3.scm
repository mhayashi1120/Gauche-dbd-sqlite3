(define-module dbd.sqlite3
  (use dbi)
  (use gauche.uvector)
  (use util.list)
  (use util.match)
  (use gauche.collection)
  (export
   <sqlite3-driver>
   <sqlite3-connection>
   <sqlite3-result-set>
   )
  )
(select-module dbd.sqlite3)

(dynamic-load "dbd_sqlite3")

;;;
;;; DBI interfaces
;;;

(define-class <sqlite3-driver> (<dbi-driver>)
  ())

(define-class <sqlite3-connection> (<dbi-connection>)
  ((%handle :init-value #f)))

(define-class <sqlite3-result-set> (<relation> <sequence>)
  ((%handle :init-value #f)
   (field-names :init-value #f)
   (rows :init-form '())))

(define-condition-type <sqlite3-error> <dbi-error> #f
  (error-code))

(define-method dbi-make-connection ((d <sqlite3-driver>)
                                    (options <string>)
                                    (option-alist <list>)
                                    . args)
  (let* ((db-name
          (match option-alist
                 (((maybe-db . #t) . rest) maybe-db)
                 (else (assoc-ref option-alist "db" #f))))
         (conn (make <sqlite3-connection>)))
    (with-error-handler
      (lambda (e) (error <dbi-error> :message "SQLite3 open failed"))
      (lambda () (slot-set! conn '%handle (sqlite3-open db-name))))
    conn))

(define-method dbi-execute-using-connection
  ((c <sqlite3-connection>) (q <dbi-query>) params)
  (let* ((handle (slot-ref c '%handle))
         (query-string (apply (slot-ref q 'prepared) params))
         (result 
          (with-error-handler
            (lambda (e) (error <dbi-error> :message (slot-ref e 'message)))
            (lambda () (prepare handle query-string)))))
    (unless result
      (errorf
       <dbi-error> :error-message (sqlite3-error-message handle)
       "SQLite3 query failed: ~a" (sqlite3-error-message handle)))
    (step result)
    result))

(define-method dbi-escape-sql ((c <sqlite3-connection>) str)
  (sqlite3-escape-string str))

(define-method dbi-open? ((c <sqlite3-connection>))
  (not (sqlite3-closed-p (slot-ref c '%handle))))

(define-method dbi-open? ((c <sqlite3-result-set>))
  (not (sqlite3-statement-closed-p (slot-ref c '%handle))))

(define-method dbi-close ((c <sqlite3-connection>))
  (with-error-handler
    (lambda (e) (error <dbi-error> :message (slot-ref e 'message)))
    (cut sqlite3-close (slot-ref c '%handle))))

(define-method dbi-close ((result-set <sqlite3-result-set>))
  (sqlite3-statement-finish (slot-ref result-set '%handle)))

(define (prepare db query)
  (let ((stmt (make-sqlite-statement))
        (result-set (make <sqlite3-result-set>)))
    (if (sqlite3-prepare db stmt query)
      (begin
        (slot-set! result-set '%handle stmt)
        (slot-set! result-set 'field-names (sqlite3-statement-column-names stmt))
        result-set)
      #f)))

;;;
;;; Relation interfaces
;;;

(define-method relation-column-names ((r <sqlite3-result-set>))
  (ref r 'field-names))

(define-method relation-accessor ((r <sqlite3-result-set>))
  (let1 columns (ref r 'field-names)
    (lambda (row column . maybe-default)
      (cond
       ((find-index (cut string=? <> column) columns)
        => (cut vector-ref row <>))
       ((pair? maybe-default) (car maybe-default))
       (else (error "invalud column name:" column))))))

;;TODO
(define-method relation-modifier ((r <sqlite3-result-set>))
  )

(define-method relation-rows ((r <sqlite3-result-set>))
  (slot-ref r 'rows))

;;;
;;; Sequence interfaces
;;;

(define-method call-with-iterator ((r <sqlite3-result-set>) proc . option)
  (let* ((cache (reverse (slot-ref r 'rows)))
         (item #f)
         (next (^ () 
                  (cond 
                   ((pair? cache)
                    (begin0
                      (car cache)
                      (set! cache (cdr cache))))
                   (else
                    item))))
         (end? (^ () (and (null? cache)
                          (begin
                            (set! item (step r))
                            (not item))))))
    (proc end? next)))

(define (step rset)

  (define (get handle)
    (and (not (sqlite3-statement-end? handle))
         (sqlite3-statement-step handle)))

  (if-let1 row (get (slot-ref rset '%handle))
    (begin
      (slot-set! rset 'rows (cons row (slot-ref rset 'rows)))
      row)
    #f))

(provide "dbd/sqlite3")
