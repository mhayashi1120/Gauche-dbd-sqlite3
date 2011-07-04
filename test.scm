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

(define (select-rows sql)
  (map
   identity
   (dbi-do connection sql)))

(test* "dbi-connect" '<sqlite3-connection>
       (let1 c (dbi-connect "dbi:sqlite3:test.db")
         (set! connection c)
         (class-name (class-of c))))

(test* "Creating test table"
       #t
       (dbi-open?
        (dbi-execute
         ;; http://www.sqlite.org/datatype3.html
         ;;TODO NUMERIC
         (dbi-prepare connection
                      "CREATE TABLE tbl1(id INTEGER, name TEXT, image NONE, rate REAL);"))))

(test* "Checking insert common fields"
       #t
       (dbi-open?
        (dbi-execute
         (dbi-prepare connection
                      "INSERT INTO tbl1 VALUES(1, 'name 1', x'0101', 0.8);"))))

(test* "Checking insert common fields 2"
       #t
       (dbi-open?
        (dbi-execute
         (dbi-prepare connection "INSERT INTO tbl1 VALUES(?, ?, x'0202', ?);")
         2 "name 2" 0.7)))

(test* "Checking insert common fields 3"
       #t
       (dbi-open?
        (dbi-do connection "INSERT INTO tbl1 (id) VALUES(3);")))

(test* "Checking field names"
       '("id" "name" "image" "rate")
       (let1 rset (dbi-do connection "SELECT * FROM tbl1;")
         ;;TODO fix after auto close
         (begin0
           (slot-ref rset 'field-names)
           (dbi-close rset))))

(test* "Checking current inserted values"
       '(#(1 "name 1" #u8(1 1) 0.8) #(2 "name 2" #u8(2 2) 0.7) #(3 #f #f #f))
       (select-rows "SELECT id, name, image, rate FROM tbl1 ORDER BY id ASC;"))

(test* "Checking transaction commit"
       '(#(101) #(102))
       (begin
         (call-with-transaction connection
           (lambda (tran)
             (dbi-do connection "INSERT INTO tbl1 (id) VALUES(101);")
             (dbi-do connection "INSERT INTO tbl1 (id) VALUES(102);")))
         (select-rows "SELECT id FROM tbl1 WHERE id IN (101, 102)")))

(test* "Checking transaction rollback"
       '()
       (begin
         (guard (e (else (print (condition-ref e 'message))))
           (call-with-transaction connection
             (lambda (tran)
               (dbi-do connection "INSERT INTO tbl1 (id) VALUES(103);")
               ;; non existent table
               (dbi-do connection "INSERT INTO tbl (id) VALUES(104);"))))
         (select-rows "SELECT id FROM tbl1 WHERE id IN (103, 104)")))

(test* "Checking full bit number insertion"
       '(#(-1))
       (begin
         (dbi-do connection "INSERT INTO tbl1 (id) VALUES(-1);")
         (select-rows "SELECT id FROM tbl1 WHERE id = -1")))

(test* "Checking long number insertion"
       '(#(#x7fffffff))
       (begin
         (dbi-do connection "INSERT INTO tbl1 (id) VALUES(2147483647);")
         (select-rows "SELECT id FROM tbl1 WHERE id = 2147483647")))

(test* "Checking exceed long number insertion"
       '(#(#x80000000))
       (begin
         (dbi-do connection "INSERT INTO tbl1 (id) VALUES(2147483648);")
         (select-rows "SELECT id FROM tbl1 WHERE id = 2147483648")))

(test* "Checking exceed long number insertion 3"
       '(#(4294967295))
       (begin
         (dbi-do connection "INSERT INTO tbl1 (id) VALUES(4294967295);")
         (select-rows "SELECT id FROM tbl1 WHERE id = 4294967295")))

(test* "Checking exceed long number insertion 4"
       '(#(4294967296))
       (begin
         (dbi-do connection "INSERT INTO tbl1 (id) VALUES(4294967296);")
         (select-rows "SELECT id FROM tbl1 WHERE id = 4294967296")))

(test* "Checking exceed long number insertion 5"
       '(#(4294967297))
       (begin
         (dbi-do connection "INSERT INTO tbl1 (id) VALUES(4294967297);")
         (select-rows "SELECT id FROM tbl1 WHERE id = 4294967297")))

(test* "Checking minus long number insertion"
       '(#(#x-80000000))
       (begin
         (dbi-do connection "INSERT INTO tbl1 (id) VALUES(-2147483648);")
         (select-rows "SELECT id FROM tbl1 WHERE id = -2147483648")))

(test* "Checking exceed minus long number insertion"
       '(#(#x-80000001))
       (begin
         (dbi-do connection "INSERT INTO tbl1 (id) VALUES(-2147483649);")
         (select-rows "SELECT id FROM tbl1 WHERE id = -2147483649")))

(test* "Checking minus max number insertion"
       '(#(#x-8000000000000000))
       (begin
         (dbi-do connection "INSERT INTO tbl1 (id) VALUES(-9223372036854775808);")
         (select-rows "SELECT id FROM tbl1 WHERE id = -9223372036854775808")))

(test* "Checking minus max number insertion"
       '(#(#x7fffffffffffffff))
       (begin
         (dbi-do connection "INSERT INTO tbl1 (id) VALUES(9223372036854775807);")
         (select-rows "SELECT id FROM tbl1 WHERE id = 9223372036854775807")))

(test* "Checking auto increment id"
       1
       (begin
         (dbi-do connection "CREATE TABLE tbl2(id INTEGER PRIMARY KEY);")
         (dbi-do connection "INSERT INTO tbl2 (id) VALUES(NULL);")
         (sqlite3-last-id connection)))

(test* "Checking dbi-tables"
       '("tbl1" "tbl2")
       (dbi-tables connection))

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


