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
         ;; http://www.sqlite.org/datatype3.html
         ;;TODO NUMERIC
         (dbi-prepare connection
                      "CREATE TABLE tbl1(id INTEGER, name TEXT, image NONE, rate REAL);"))))

(test* "(dbi-execute (dbi-prepare connection \"INSERT INTO tbl1 VALUES...\")"
		#t
		(dbi-open?
			(dbi-execute
				(dbi-prepare connection
					"INSERT INTO tbl1 VALUES(1, 'name 1', x'0001', 0.8);"))))

(test* "(dbi-execute (dbi-prepare connection \"INSERT INTO tbl1 VALUES(?, ?, ?);\")"
       #t
       (dbi-open?
        (dbi-execute
         (dbi-prepare connection "INSERT INTO tbl1 VALUES(?, ?, ?, ?);")
         2 "name 2" "blob 2" 0.7)))

(test* "(dbi-do connection \"INSERT INTO tbl1 (id) VALUES(3);\")"
       #t
       (dbi-open?
        (dbi-do connection "INSERT INTO tbl1 (id) VALUES(3);")))

(test* "(slot-ref (dbi-do connection \"SELECT * FROM tbl1;\") 'field-names)"
       '("id" "name" "image" "rate")
       (slot-ref
        (dbi-do connection "SELECT * FROM tbl1;")
        'field-names))

(test* "(dbi-execute (dbi-prepare connection  \"SELECT id, age FROM ..."
       '((1 "name 1" "blob 1" 0.8) (2 "name 2" "blob 2" 0.7) (3 #f #f #f))
       (map
        (lambda (row) (list 
                       (dbi-get-value row 0)
                       (dbi-get-value row 1)
                       (dbi-get-value row 2)
                       (dbi-get-value row 3)))
        (dbi-execute
         (dbi-prepare connection "SELECT id, name, image, rate FROM tbl1 ORDER BY id ASC;"))))

(test* "Checking transaction commit"
       '(101 102)
       (begin
         (call-with-transaction connection
           (lambda ()
             (dbi-do connection "INSERT INTO tbl1 (id) VALUES(101);")
             (dbi-do connection "INSERT INTO tbl1 (id) VALUES(102);")))
         (map
          (lambda (row) (dbi-get-value row 0))
          (dbi-execute 
           (dbi-prepare connection "SELECT id FROM tbl1 WHERE id IN (101, 102)")))))

(test* "Checking transaction rollback"
       '()
       (begin
         (guard (e (else #f))
           (call-with-transaction connection
             (lambda ()
               (dbi-do connection "INSERT INTO tbl1 (id) VALUES(103);")
               ;; syntax error statement
               (dbi-do connection "INSERT INTO tbl (id) VALUES(104);"))))
         (map
          (lambda (row) (dbi-get-value row 0))
          (dbi-execute 
           (dbi-prepare connection "SELECT id FROM tbl1 WHERE id IN (103, 104)")))))

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


