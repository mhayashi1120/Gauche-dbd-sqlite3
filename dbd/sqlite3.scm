(define-module dbd.sqlite3
  (use dbi)
  (use gauche.uvector)
  (use util.list)
  (use util.match)
  (use gauche.sequence)
  (use util.stream)
  (export
   <sqlite3-driver>
   <sqlite3-connection>
   <sqlite3-result-set>
   sqlite3-error-message
   sqlite3-table-columns
   sqlite3-last-id
   ))
(select-module dbd.sqlite3)

(dynamic-load "dbd_sqlite3")

;;;
;;; Sqlite3 specific interfaces
;;;

(define (sqlite3-table-columns conn table)
  (do-select conn "PRAGMA table_info(?)"
             (^r (dbi-get-value r 1)) table))

(define (sqlite3-error-message conn)
  (sqlite3-last-errmsg (slot-ref conn '%handle)))

(define (sqlite3-last-id conn)
  (sqlite3-last-insert-rowid (slot-ref conn '%handle)))

;; SQLite3 accept `:' `@' `$' as named parameter prefix.
;; default named parameter is `:' prefix, same as scheme constant symbol prefix.
;; http://www.sqlite.org/c3ref/bind_blob.html
(define (sqlite3-keyword-name keyword)
  (let ([name (keyword->string keyword)])
    (cond
     [(#/^[@$]/ name)
      ;; @VVV, $VVV
      name]
     [(#/^[0-9]+$/ name)
      ;; ?NNN
      #`"?,|name|"]
     [(string=? "?" name)
      ;; no named parameter
      #f]
     [else
      ;; :VVV 
      #`":,|name|"])))

;; params = (:a1 1 :@a2 2 :$a3 3 :4 4 :? 5)
;; sql = "select :a1, @a2, $a3, ?4, ?"
;; this return #(1 2 3 4 5) row
(define (keywords->params keywords)
  (let loop ([keys keywords]
             [index 1])
    (cond
     [(null? keys)
      '()]
     [else
      (unless (>= (length keys) 2)
        (error "keyword list not even" keys))
      (let ([key (car keys)]
            [val (match (cadr keys)
                   ;; text
                   [(? string? x) x]
                   ;; integer
                   [(or (? fixnum? x)
                        (? bignum? x)) x]
                   ;; float
                   [(? real? x) x]
                   ;; blob
                   [(? u8vector? x) x]
                   ;; NULL
                   [#f #f]
                   ;; handle as text
                   [x (x->string x)])])
        (unless (keyword? key)
          (error "Invalid keyword" key))
        (let1 keyname (sqlite3-keyword-name key)
          (cons
           (cons (or keyname index) val)
           (loop (cddr keys) (+ index 1)))))])))

;;;
;;; DBI interfaces
;;;

(define-class <sqlite3-driver> (<dbi-driver>)
  ())

(define-class <sqlite3-connection> (<dbi-connection>)
  ((%handle :init-value #f)
   (%filename :init-value #f :init-keyword :filename)))

(define-class <sqlite3-result-set> (<relation> <sequence>)
  ((%db :init-keyword :db)
   (%handle :init-keyword :handle)
   (%stream :init-value #f)
   (%cache :init-form '())
   (field-names :init-keyword :field-names)))

(define-condition-type <sqlite3-error> <dbi-error> #f
  (error-code))

(define-macro (with-guard . body)
  `(guard (e [else (error <sqlite3-error>
                         :message (condition-ref e 'message))])
     ,@body))

(define-method dbi-make-connection ((d <sqlite3-driver>)
                                    (options <string>)
                                    (option-alist <list>)
                                    . args)
  (let* ([db-name
          (match option-alist
                 (((maybe-db . #t) . rest) maybe-db)
                 (else (assoc-ref option-alist "db" #f)))]
         [conn (make <sqlite3-connection>
                 :filename db-name)]
         ;; SQLITE_OPEN_URI is not yet implemented at least 3.7.3
         ;; 
         [flags #x40])
    (slot-set! conn '%handle
               (with-guard (sqlite3-open db-name flags)))
    conn))

(define-method dbi-execute-using-connection
  ((c <sqlite3-connection>) (q <dbi-query>) params)

  (let* ([db (slot-ref c '%handle)]
         [prepared (slot-ref q 'prepared)]
         [query (if (string? prepared)
                  prepared
                  (apply prepared params))]
         [stmt (sqlite3-prepare db query)])

    (when (string? prepared)
      (sqlite3-bind-parameters stmt (keywords->params params)))

    (let1 result (make <sqlite3-result-set>
                   :db db
                   :handle stmt
                   :field-names (sqlite3-statement-column-names stmt))
      ;; execute first step of this statement
      (slot-set! result '%stream (statement-next result))
      result)))

(define-method dbi-prepare ((c <sqlite3-connection>) (sql <string>) . args)
  (let-keywords args ((pass-through #f))
    (let1 prepared (if pass-through
                     sql
                     (dbi-prepare-sql c sql))
      (make <dbi-query> :connection c
            :prepared prepared))))

(define-method dbi-escape-sql ((c <sqlite3-connection>) str)
  (sqlite3-escape-string str))

(define-method dbi-open? ((c <sqlite3-connection>))
  (not (sqlite3-db-closed? (slot-ref c '%handle))))

(define-method dbi-open? ((c <sqlite3-result-set>))
  (not (sqlite3-statement-closed? (slot-ref c '%handle))))

(define-method dbi-close ((c <sqlite3-connection>))
  (with-guard
   (sqlite3-db-close (slot-ref c '%handle))))

(define-method dbi-close ((result-set <sqlite3-result-set>))
  (sqlite3-statement-close (slot-ref result-set '%handle)))

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
       (else
        (error "<sqlite3-result-set>: invalud column name:" column))))))

(define-method relation-modifier ((r <sqlite3-result-set>))
  (let1 columns (ref r 'field-names)
    (lambda (row column val)
      (cond
       ((find-index (cut string=? <> column) columns)
        => (cut vector-set! row <> val))
       (else
        (error "<sqlite3-result-set>: invalid column:" column))))))

(define-method relation-rows ((r <sqlite3-result-set>))
  (map identity r))

;;;
;;; Sequence interfaces
;;;

(define-method call-with-iterator ((r <sqlite3-result-set>) proc . option)
  (let* ([s (slot-ref r '%stream)]
         [next (^ () (begin0
                       (stream-car s)
                       (set! s (stream-cdr s))))]
         [end? (^ () (stream-null? s))])
    (proc end? next)))

(define (statement-next rset)

  (define (next)
    (with-guard
     (sqlite3-statement-step (slot-ref rset '%handle))))

  (cond
   [(sqlite3-statement-end? (slot-ref rset '%handle))
    stream-null]
   [(next) =>
    (^n (stream-delay (cons n (statement-next rset))))]
   [else
    stream-null]))

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
    (guard (e [else
               (guard (e2 [else
                           ;; FATAL: failed to rollback
                           (raise (make-compound-condition e e2))])
                 (dbi-rollback tran))
               (raise e)])
      (begin0
        (proc tran)
        (dbi-commit tran)))))

(define (with-transaction conn proc . flags)
  (apply call-with-transaction conn
         (^t (proc))
         flags))

(define-method dbi-tables ((conn <dbi-connection>))
  '())

(export-if-defined call-with-transaction with-transaction dbi-tables)


;;;
;;; Transaction interfaces
;;;

(define-class <sqlite3-transaction> (<dbi-transaction>)
  ())

(define-method dbi-begin-transaction ((conn <sqlite3-connection>) . args)
  (rlet1 tran (make <sqlite3-transaction> :connection conn)
    (do-one-time conn "BEGIN TRANSACTION")))


(define-method dbi-commit ((tran <sqlite3-transaction>) . args)
  (do-one-time (slot-ref tran 'connection)
               "COMMIT TRANSACTION"))

(define-method dbi-rollback ((tran <sqlite3-transaction>) . args)
  (do-one-time (slot-ref tran 'connection)
               "ROLLBACK TRANSACTION"))

;;;
;;; dbi extensions TODO  URL
;;;

(define-method dbi-tables ((conn <sqlite3-connection>))
  (do-select conn
             "SELECT name FROM sqlite_master WHERE type='table'"
             (^r (dbi-get-value r 0))))

;;;
;;; internal utilities
;;;

(define (do-select con sql proc . args)
  (let1 rset (apply dbi-do con sql args)
    (begin0 (map proc rset)
      (dbi-close rset))))

(define (do-one-time con sql . args)
  (let1 r (apply dbi-do con sql args)
    (dbi-close r)))
