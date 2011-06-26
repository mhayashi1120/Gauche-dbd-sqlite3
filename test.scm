;;
;; Test dbd.sqlite3 module
;;

(use gauche.test)
(test-start "dbd.sqlite3")
(use dbi)
(use dbd.sqlite3)
(use gauche.collection)
(test-module 'dbd.sqlite3)  ;; This checks the exported symbols are indeed bound.

;; Normal operation test

(define connection #f)

(test* "dbi-connect" '<sqlite3-connection>
       (let1 c (dbi-connect "dbi:sqlite3:test.db")
         (set! connection c)
         (class-name (class-of c))))

(test* "(dbi-execute (dbi-prepare connection \"CREATE TABLE tbl1 ... \")"
       #t
       (dbi-open?
        (dbi-execute
         (dbi-prepare connection
                      "CREATE TABLE tbl1(id CHAR(10), age SMALLINT, active BOOLEAN);"))))

(test* "(dbi-execute (dbi-prepare connection \"INSERT INTO tbl1 VALUES('foo', 26, 0);\")"
		#t
		(dbi-open?
			(dbi-execute
				(dbi-prepare connection
					"INSERT INTO tbl1 VALUES('foo', 26, 0);"))))

(test* "(dbi-execute (dbi-prepare connection \"INSERT INTO tbl1 VALUES(?, ?, ?);\")"
       #t
       (dbi-open?
        (dbi-execute
         (dbi-prepare connection "INSERT INTO tbl1 VALUES(?, ?, ?);")
         "bar" 32 0)))

(test* "(dbi-do connection \"INSERT INTO tbl1 (id, age) VALUES('baz');\")"
       #t
       (dbi-open?
        (dbi-do connection "INSERT INTO tbl1 (id) VALUES('baz');")))

(test* "(slot-ref (dbi-do connection \"SELECT * FROM tbl1;\") 'field-names)"
       '("id" "age" "active")
       (slot-ref
        (dbi-do connection "SELECT * FROM tbl1;")
        'field-names))

(test* "(dbi-execute (dbi-prepare connection  \"SELECT id, age FROM ..."
       '(("baz" #f) ("foo" 26) ("bar" 32))
       (map
        (lambda (row) (list (dbi-get-value row 0) (dbi-get-value row 1)))
        (dbi-execute
         (dbi-prepare connection "SELECT id, age FROM tbl1 ORDER BY age ASC;"))))

(test* "Checking transaction commit"
       '("tran1" "tran2")
       (begin
         (call-with-transaction connection
           (lambda ()
             (dbi-do connection "INSERT INTO tbl1 (id) VALUES('tran1');")
             (dbi-do connection "INSERT INTO tbl1 (id) VALUES('tran2');")))
         (map
          (lambda (row) (dbi-get-value row 0))
          (dbi-execute 
           (dbi-prepare connection "SELECT id FROM tbl1 WHERE id IN ('tran1', 'tran2')")))))

(test* "Checking transaction rollback"
       '()
       (begin
         (guard (e (else #f))
           (call-with-transaction connection
             (lambda ()
               (dbi-do connection "INSERT INTO tbl1 (id) VALUES('tran3');")
               ;; syntax error statement
               (dbi-do connection "INSERT INTO tbl (id) VALUES('tran4');"))))
         (map
          (lambda (row) (dbi-get-value row 0))
          (dbi-execute 
           (dbi-prepare connection "SELECT id FROM tbl1 WHERE id IN ('tran3', 'tran4')")))))

(test* "(dbi-open? connection)"
		#t
		(dbi-open? connection))

(test* "(dbi-close connection)"
		#t
		(dbi-close connection))

(test* "(dbi-open? connection)"
		#f
		(dbi-open? connection))

(test-end)
(sys-unlink "test.db")


