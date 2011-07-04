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
   sqlite3-error-message
   sqlite3-table-columns

   ))
(select-module dbd.sqlite3)

(dynamic-load "dbd_sqlite3")

;;;
;;; Sqlite3 specific interfaces
;;;

(define (sqlite3-table-columns conn table)
  (map
   (lambda (row) 
     (dbi-get-value row 1))
   (dbi-do conn "PRAGMA table_info(?)" '() table)))

;;;
;;; DBI interfaces
;;;

(define-class <sqlite3-driver> (<dbi-driver>)
  ())

(define-class <sqlite3-connection> (<dbi-connection>)
  ((%handle :init-value #f)))

(define-class <sqlite3-result-set> (<relation> <sequence>)
  ((%db :init-keyword :db)
   (%handle :init-keyword :handle)
   (field-names :init-keyword :field-names)
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
    (guard (e (else (error <sqlite3-error> :message "SQLite3 open failed")))
      (slot-set! conn '%handle (sqlite3-open db-name)))
    conn))

(define-method dbi-execute-using-connection
  ((c <sqlite3-connection>) (q <dbi-query>) params)
  (let* ((handle (slot-ref c '%handle))
         (query-string (apply (slot-ref q 'prepared) params))
         (result 
          (guard (e (else (error <sqlite3-error> :message (slot-ref e 'message))))
            (let ((res (prepare handle query-string)))
              (unless res
                (errorf
                 <sqlite3-error> :error-message (sqlite3-error-message handle)
                 "SQLite3 query failed: ~a" (sqlite3-error-message handle)))
              res))))
    (step result)
    result))

(define-method dbi-escape-sql ((c <sqlite3-connection>) str)
  (sqlite3-escape-string str))

(define-method dbi-open? ((c <sqlite3-connection>))
  (not (sqlite3-closed-p (slot-ref c '%handle))))

(define-method dbi-open? ((c <sqlite3-result-set>))
  (not (sqlite3-statement-closed-p (slot-ref c '%handle))))

(define-method dbi-close ((c <sqlite3-connection>))
  (guard (e (else (error <sqlite3-error> :message (slot-ref e 'message))))
    (sqlite3-close (slot-ref c '%handle))))

(define-method dbi-close ((result-set <sqlite3-result-set>))
  (sqlite3-statement-finish (slot-ref result-set '%handle)))

(define (prepare db query)
  (let ((stmt (make-sqlite-statement)))
    (if (sqlite3-prepare db stmt query)
      (make <sqlite3-result-set>
        :db db
        :handle stmt
        :field-names (sqlite3-statement-column-names stmt))
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
  (map identity r))

;;;
;;; Sequence interfaces
;;;

(define-method call-with-iterator ((r <sqlite3-result-set>) proc . option)
  (let* ((cache (reverse (slot-ref r 'rows)))
         (item #f)
         (next (lambda () 
                 (cond 
                  ((pair? cache)
                   (begin0
                     (car cache)
                     (set! cache (cdr cache))))
                  (else
                   item))))
         (end? (lambda () (and (null? cache)
                               (begin
                                 (set! item (step r))
                                 (not item))))))
    (proc end? next)))

(define (step rset)

  (define (get handle)
    (and (not (sqlite3-statement-end? handle))
         (sqlite3-statement-step handle)))

  (guard (e (else (error <sqlite3-error> 
                         :message (sqlite3-error-message (slot-ref rset '%db)))))
    (if-let1 row (get (slot-ref rset '%handle))
      (begin
        (slot-set! rset 'rows (cons row (slot-ref rset 'rows)))
        row)
      #f)))

;;;
;;;TODO dbi extensions
;;;

;;TODO isolation level
(define-class <dbi-transaction> ()
  ((connection :init-keyword :connection)))

;; Begin transaction and return <dbi-transaction> instance.
(define-method dbi-begin-transaction ((conn <dbi-connection>) . args)
  (make <dbi-transaction> :connection conn))

(define-method dbi-commit ((tran <dbi-transaction>) . args))

(define-method dbi-rollback ((tran <dbi-transaction>) . args))

;; proc accept a <dbi-transaction>.
(define (call-with-transaction conn proc . flags)
  (let1 tran (apply dbi-begin-transaction conn flags)
    (guard (e (else 
               (guard (e2 (else 
                           (raise (make-compound-condition e e2))))
                      (dbi-rollback tran)
                      (raise e))))
      (begin0
        (proc tran)
        (dbi-commit tran)))))

(define-method dbi-tables ((conn <dbi-connection>))
  '())

(export-if-defined call-with-transaction dbi-tables)


;;;
;;; Transaction interfaces
;;;

(define-class <sqlite3-transaction> (<dbi-transaction>)
  ())

(define-method dbi-begin-transaction ((conn <sqlite3-connection>) . args)
  (rlet1 tran (make <sqlite3-transaction> :connection conn)
    (dbi-do conn "BEGIN TRANSACTION")))

(define-method dbi-commit ((tran <sqlite3-transaction>) . args)
  (dbi-do (slot-ref tran 'connection)
          "COMMIT TRANSACTION"))

(define-method dbi-rollback ((tran <sqlite3-transaction>) . args)
  (dbi-do (slot-ref tran 'connection)
          "ROLLBACK TRANSACTION"))

(define-method dbi-tables ((conn <sqlite3-connection>))
  (map
   (lambda (row) (dbi-get-value row 0))
   (dbi-do conn "SELECT name FROM sqlite_master WHERE type='table'")))

