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

(define (cleanup-test)
  (define (remove-file file)
    (when (file-exists? file)
      (sys-unlink file)))
  (remove-file "test.db")
  (remove-file "test.db-journal")
  (remove-file "てすと.db")
  (remove-file "unacceptable.db"))

(cleanup-test)

(test* "dbi-connect"
       <sqlite3-connection>
       (let1 c (dbi-connect "dbi:sqlite3:test.db")
         (set! connection c)
         (class-of c)))

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
         (begin0
           (slot-ref rset 'field-names)
           ;; Must close result if rset is pending query.
           ;; See the http://www.sqlite.org/lang_transaction.html ROLLBACK section.
           (dbi-close rset))))

(test* "Checking current inserted values"
       '(#(1 "name 1" #u8(1 1) 0.8) #(2 "name 2" #u8(2 2) 0.7) #(3 #f #f #f))
       (select-rows "SELECT id, name, image, rate FROM tbl1 ORDER BY id ASC;"))

(let ((rset (dbi-do connection "SELECT id FROM tbl1 ORDER BY id ASC")))
  (test* "Checking result when quit on the way"
         '(#(1) #(2))
         (call-with-iterator rset
           (lambda (end? next)
             (let loop ((count 0)
                        (res '()))
               (cond
                ((or (end?)
                     (> count 1))
                 (reverse! res))
                (else
                 (loop (+ count 1)
                       (cons (next) res))))))))

  (test* "Checking result 1"
         '(#(1) #(2) #(3))
         (map identity rset))
  (test* "Checking result 2"
         '(#(1) #(2) #(3))
         (map identity rset)))

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

;; See the http://www.sqlite.org/lang_transaction.html ROLLBACK section.
(test* "Checking transaction unable rollback"
       '(#(201))
       (begin
         ;; Open pending query
         (dbi-do connection "SELECT 1 AS FOO;")
         (guard (e (else (print (string-join
                                 (map
                                  (cut condition-ref <> 'message)
                                  (slot-ref e '%conditions))
                                 ", "))))
           (call-with-transaction connection
             (lambda (tran)
               (dbi-do connection "INSERT INTO tbl1 (id) VALUES(201);")
               ;; non existent table
               (dbi-do connection "INSERT INTO tbl (id) VALUES(202);"))))
         (select-rows "SELECT id FROM tbl1 WHERE id IN (201, 202)")))

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
       '(#(#xffffffff))
       (begin
         (dbi-do connection "INSERT INTO tbl1 (id) VALUES(4294967295);")
         (select-rows "SELECT id FROM tbl1 WHERE id = 4294967295")))

(test* "Checking exceed long number insertion 4"
       '(#(#x100000000))
       (begin
         (dbi-do connection "INSERT INTO tbl1 (id) VALUES(4294967296);")
         (select-rows "SELECT id FROM tbl1 WHERE id = 4294967296")))

(test* "Checking exceed long number insertion 5"
       '(#(#x100000001))
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

(test* "Checking max number insertion"
       '(#(#x7fffffffffffffff))
       (begin
         (dbi-do connection "INSERT INTO tbl1 (id) VALUES(9223372036854775807);")
         (select-rows "SELECT id FROM tbl1 WHERE id = 9223372036854775807")))

(test* "Checking auto increment id"
       '(1 2)
       (begin
         (dbi-do connection "CREATE TABLE tbl2(id INTEGER PRIMARY KEY);")
         (dbi-do connection "INSERT INTO tbl2 (id) VALUES(NULL);")
         (let1 res1 (sqlite3-last-id connection)
           (dbi-do connection "INSERT INTO tbl2 (id) VALUES(NULL);")
           (let1 res2 (sqlite3-last-id connection)
             (list res1 res2)))))

(test* "Checking compound INSERT statements"
       '(#(301) #(302) #(303))
       (begin
         (dbi-do connection "INSERT INTO tbl1 (id) VALUES (301); INSERT INTO tbl1 (id) VALUES (302);INSERT INTO tbl1 (id) VALUES (303)")
         (select-rows "SELECT id FROM tbl1 WHERE id IN (301, 302, 303)")))

(test* "Checking compound statements getting last select"
       '(#(401) #(402))
       (select-rows "INSERT INTO tbl1 (id) VALUES (401); INSERT INTO tbl1 (id) VALUES (402);SELECT id FROM tbl1 WHERE id IN (401, 402)"))

(test* "Checking compound statements getting 1st select"
       '(#(401) #(402))
       (select-rows "SELECT id FROM tbl1 WHERE id IN (401, 402); INSERT INTO tbl1 (id) VALUES (403);"))

(test* "Checking compound statements before"
       '(#(403))
       (select-rows "SELECT id FROM tbl1 WHERE id IN (403);"))

(test* "Checking compound statements getting 1st select and 2nd has syntax error"
       (test-error <error>)
       (select-rows "SELECT 1; SELECT;"))

;; TODO
(test* "Checking multiple SELECT statements"
       '(#(403) #(301 #f) #(302 #f))
       (select-rows "SELECT id FROM tbl1 WHERE id IN (403); SELECT id, name FROM tbl1 WHERE id IN (301, 302)"))

;; FIXME
(test* "Checking VACUUM is not working."
       (test-error <error>)
       (dbi-do connection "VACUUM"))

(test* "Checking dbi-tables"
       '("tbl1" "tbl2")
       (dbi-tables connection))

(test* "Checking still open connection"
		#t
		(dbi-open? connection))

(test* "Checking closing connection"
		#t
		(dbi-close connection))

(test* "Checking connection was closed"
		#f
		(dbi-open? connection))

(test* "Checking failed to open db"
       (test-error (with-module dbd.sqlite3 <sqlite3-error>))
       (begin
         (with-output-to-file "unacceptable.db"
           (^()))
         (sys-chmod "unacceptable.db" #o000)
         (dbi-connect "dbi:sqlite3:unacceptable.db")))

(test* "Checking multibyte filename"
       #t
       (let1 c (dbi-connect "dbi:sqlite3:てすと.db")
         (dbi-open? c)))
       

(test-end)

(cleanup-test)
