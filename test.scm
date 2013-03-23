;;
;; Test dbd.sqlite3 module
;;

(use gauche.test)
(test-start "dbd.sqlite3")
(use dbi)
(use dbd.sqlite3)
(use gauche.collection)
(use gauche.version)
(test-module 'dbd.sqlite3)  ;; This checks the exported symbols are indeed bound.

;; Normal operation test

(define connection #f)

(define (select-rows sql . params)
  (let1 rset (apply dbi-do connection sql '() params)
    (unwind-protect
     (map identity rset)
     (dbi-close rset))))

(define (select-rows2 sql . params)
  (let1 rset (apply dbi-do connection sql '(:pass-through #t) params)
    (unwind-protect
     (map identity rset)
     (dbi-close rset))))

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
       #f
       (dbi-open?
        (dbi-execute
         ;; http://www.sqlite.org/datatype3.html
         ;;TODO NUMERIC
         (dbi-prepare connection
                      "CREATE TABLE tbl1(id INTEGER, name TEXT, image NONE, rate REAL);"))))

(test* "Checking insert common fields"
       #f
       (dbi-open?
        (dbi-execute
         (dbi-prepare connection
                      "INSERT INTO tbl1 VALUES(1, 'name 1', x'0101', 0.8);"))))

(test* "Checking insert common fields 2"
       #f
       (dbi-open?
        (dbi-execute
         (dbi-prepare connection "INSERT INTO tbl1 VALUES(?, ?, x'0202', ?);")
         2 "name 2" 0.7)))

(test* "Checking insert common fields 3"
       #f
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
(cond
 [(version<? (sqlite3-libversion) "3.7.11")
  (test* "Checking transaction unable rollback"
         '(#(201))
         ;; Open pending query
         (let1 pending-rset (dbi-do connection "SELECT 1 FROM tbl1;")
           (guard (e [else (print (string-join
                                    (map
                                     (cut condition-ref <> 'message)
                                     (slot-ref e '%conditions))
                                    ", "))])
              (call-with-transaction connection
                (lambda (tran)
                  (dbi-do connection "INSERT INTO tbl1 (id) VALUES(201);")
                  ;; non existent table
                  (dbi-do connection "INSERT INTO tbl (id) VALUES(202);"))))
           (dbi-close pending-rset)
           (select-rows "SELECT id FROM tbl1 WHERE id IN (201, 202)")))]
 [else
  ;; http://www.sqlite.org/changes.html
  ;; 2012 March 20 (3.7.11)
  ;; Pending statements no longer block ROLLBACK. Instead, the pending
  ;; statement will return SQLITE_ABORT upon next access after the
  ;; ROLLBACK.
  (test* "Checking transaction can rollback (but previous version can not)"
         (list () (with-module dbd.sqlite3 <sqlite3-error>))
         ;; Open pending query
         (let1 pending-rset (dbi-do connection "SELECT 1 FROM tbl1;")
           (unwind-protect
            (begin
              (guard (e [else (print (condition-ref e 'message))])
                (call-with-transaction connection
                  (lambda (tran)
                    (dbi-do connection "INSERT INTO tbl1 (id) VALUES(201);")
                    ;; non existent table
                    (dbi-do connection "INSERT INTO tbl (id) VALUES(202);"))))
              (list
               (select-rows "SELECT id FROM tbl1 WHERE id IN (201, 202)")
               (guard (e [else (class-of e)])
                 (map (^x x) pending-rset))))
            (dbi-close pending-rset))))])

(let* ([query (dbi-prepare connection "SELECT 1 FROM tbl1;")]
       [rset (dbi-do connection "SELECT 1 FROM tbl1;")])
  (begin
    (unwind-protect
     (test* "Checking working statements 1"
            1
            (length (sqlite3-working-statements connection)))
     (dbi-close rset))
    (test* "Checking working statements 2"
           0
           (length (sqlite3-working-statements connection)))))

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

(test* "Checking previous compound 2nd statements working"
       '(#(403))
       (select-rows "SELECT id FROM tbl1 WHERE id IN (403);"))

(test* "Checking compound statements getting 1st select and 2nd has syntax error"
       (test-error (with-module dbd.sqlite3 <sqlite3-error>))
       (select-rows "SELECT 1; SELECT;"))

(test* "Checking multiple SELECT statements"
       '(#(403) #(301 #f) #(302 #f))
       (select-rows "SELECT id FROM tbl1 WHERE id IN (403); SELECT id, name FROM tbl1 WHERE id IN (301, 302)"))

(test* "Checking parameter bindings"
       '(#("abcdeあ" #xffff #x7fffffffffffffff 0.99 #f))
       (select-rows "SELECT ?, ?, ?, ?, ?;"
                    "abcdeあ" #xffff #x7fffffffffffffff 0.99 #f))

(test* "Checking named parameter bindings (pass-through)"
       '(#("abcdeあ" #xffff #x7fffffffffffffff #x-8000000000000000 #u8(0 1 15 255) 0.99 #f
           #x7fffffffffffffff #x-8000000000000000))
       (select-rows2
        (string-append
         "SELECT "
         " :string_multibyte1, :small_int, :bigpositive_num, :bignegative_num"
         ", :u8vector, :float, :null1"
         ", :overflow_positive_num, :overflow_negative_num"
         )
        :string_multibyte1 "abcdeあ"
        :small_int #xffff
        :bigpositive_num #x7fffffffffffffff
        :overflow_positive_num #x8000000000000000
        :bignegative_num #x-8000000000000000
        :overflow_negative_num #x-8000000000000001
        :u8vector #u8(0 1 15 255)
        :float 0.99
        :null1 #f))

(test* "Checking named parameter bindings 2 (pass-through)"
       '(#(1 2 3 4 5 6 7))
       (select-rows2
        (string-append
         "SELECT "
         ;; : prefix
         "  :a1"
         ;; @ prefix
         ", @a2"
         ;; $ prefix
         ", $a3"
         ;; indexed parameter
         ", ?4"
         ;; anonymous parameter
         ", ?"
         ;; keyword has ? prefix
         ", ?6"
         ;; keyword has : prefix
         ", :a7")
        :a1 1 :@a2 2 :$a3 3 :4 4 :? 5 :?6 6 ::a7 7))

(test* "Checking compound statements for named parameter (pass-through)"
       '(#(1 2) #(1 3))
       (select-rows2
        (string-append
        "SELECT :a1, :a2;"
        "SELECT :a1, :a3;")
        :a1 1 :a2 2 :a3 3))

(test* "Checking compound statements with no parameter (pass-through)"
       '(#("a1" "a2") #("a3" "a4"))
       (select-rows2
        (string-append
        "SELECT 'a1', 'a2';"
        "SELECT 'a3', 'a4';")))

(cond
 [(version>? (sqlite3-libversion) "3.7.12")
  (test* "Checking VACUUM is not working when there is pending statement."
         (test-error (with-module dbd.sqlite3 <sqlite3-error>))
         (let1 pending-rset (dbi-do connection "SELECT 1 FROM tbl1;")
           (guard (e [else
                      (print (condition-ref e 'message))
                      (dbi-close pending-rset)
                      (raise e)])
             (dbi-do connection "VACUUM"))))
  (test* "Checking VACUUM is working."
         '()
         (map (^x x) (dbi-do connection "VACUUM;")))]
 [else
  (test* "Checking VACUUM is not working."
         (test-error (with-module dbd.sqlite3 <sqlite3-error>))
         (dbi-do connection "VACUUM"))])

(test* "Checking no working statements"
       '()
       (sqlite3-working-statements connection))

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

(cond-expand
 ;; FIXME: cygwin version can't chmod file..
 [gauche.os.cygwin]
 [else
  (test* "Checking failed to open db"
         (test-error (with-module dbd.sqlite3 <sqlite3-error>))
         (begin
           (with-output-to-file "unacceptable.db"
             (^()))
           (sys-chmod "unacceptable.db" #o000)
           (dbi-connect "dbi:sqlite3:unacceptable.db")))])

(test* "Checking multibyte filename"
       #t
       (let1 c (dbi-connect "dbi:sqlite3:てすと.db")
         (unwind-protect
          (dbi-open? c)
          (dbi-close c))))


(test-end)

(cleanup-test)
