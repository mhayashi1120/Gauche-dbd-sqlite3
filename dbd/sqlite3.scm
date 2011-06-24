(define-module dbd.sqlite3
	(use dbi)
	(use gauche.uvector)
	(use util.list)
	(use util.match)
	(use gauche.collection)
	;;(use gauche.sequence)
	(export
		<sqlite3-driver>
		<sqlite3-connection>
		<sqlite3-result-set>
		<sqlite3-error>)
	)
(select-module dbd.sqlite3)

(dynamic-load "dbd_sqlite3")





(define-class <sqlite3-driver> (<dbi-driver>) ())


(define-class <sqlite3-connection> (<dbi-connection>)
	((%handle :init-keyword :handle :init-value #f)))

(define-class <sqlite3-result-set> (<collection>)
	(
		(%handle :init-keyword :handle :init-value #f)
		(%prev :init-keyword :prev :init-value #f)
		(field-names :init-keyword :field-names :init-value #f)
		))






(define
	sqlite3-db-open
	(lambda
		(path)
		(let1 db (make <sqlite3-handle>)
			(if
				(sqlite-c-open db path)
				db
				#f))))

(define
	sqlite3-step
	(lambda
		(result-set)
		(let1 v (sqlite-c-stmt-step (slot-ref result-set '%handle))
			(slot-set! result-set '%prev v)
			v
			)))

(define
	sqlite3-db-execute
	(lambda
		(db query)
		(let
			(
				(stmt (make <sqlite3-stmt>))
				(result-set (make <sqlite3-result-set>))
				)
			(if
				(sqlite-c-execute db stmt query)
				(begin
					(slot-set! result-set '%handle stmt)
					(slot-set! result-set 'field-names (sqlite-c-stmt-column-names stmt))
					result-set)
				#f
				))))

(define
	sqlite3-db-close
	(lambda (db) (sqlite-c-close db)))

(define
	sqlite3-db-closed?
	(lambda (db) (sqlite-c-closed-p db)))


(define-condition-type <sqlite3-error> <dbi-error> #f)


(define-method dbi-make-connection
	(
		(d <sqlite3-driver>)
		(options <string>)
		(option-alist <list>)
		. args
		)
	(let*
		(
			(db-name
				(match option-alist
					(
						((maybe-db . #t) . rest) maybe-db)
					(else (assoc-ref option-alist "db" #f))))
			(conn (make <sqlite3-connection>))
			(db (sqlite3-db-open db-name))
			)
		(unless db (error <sqlite3-error> :message "SQLite3 open failed"))
		(slot-set! conn '%handle db)
		conn
		))


(define-method dbi-execute-using-connection
	(
		(c <sqlite3-connection>)
		(q <dbi-query>)
		params
		)
	(let*
		(
			(handle (slot-ref c '%handle))
			(query-string (apply (slot-ref q 'prepared) params))
			(result #f)
			)
		(with-error-handler
			(lambda (e) (error <sqlite3-error> :message (slot-ref e 'message)))
			(lambda () (set! result (sqlite3-db-execute handle query-string)))
			)
		(if result
			(begin
				(sqlite3-step result)
				result
				)
			(errorf
				<sqlite3-error> :error-message (sqlite-c-error-message handle)
				"SQLite3 query failed: ~a" (sqlite-c-error-message handle))
			)
		
		))



(define-method dbi-close ((result-set <sqlite3-result-set>))
	(sqlite-c-stmt-finish (slot-ref result-set '%handle)))

(define-method dbi-close ((c <sqlite3-connection>))
	(with-error-handler
		(lambda (e) (error <sqlite3-error> :message (slot-ref e 'message)))
		(cut sqlite3-db-close (slot-ref c '%handle))
		)
	)


(define-method dbi-open? ((c <sqlite3-connection>))
	(not (sqlite3-db-closed? (slot-ref c '%handle))))

(define-method dbi-escape-sql ((c <sqlite3-connection>) str)
	(sqlite-c-escape-string (slot-ref c '%handle) str))

(define-method call-with-iterator ((r <sqlite3-result-set>) proc . option)
	(let*
		(
			(prev #f)
			(end? (cut sqlite-c-stmt-end-p (slot-ref r '%handle)))
			(next
				(lambda
					()
					(set! prev (slot-ref r '%prev))
					(with-error-handler
						(lambda (e) (error <sqlite3-error> :message (slot-ref e 'message)))
						(cut sqlite3-step r)
						)
					prev
					))
			)
	  (proc end? next)))





(provide "dbd/sqlite3")
