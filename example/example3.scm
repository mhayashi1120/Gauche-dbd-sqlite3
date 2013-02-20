(use dbi)
(use gauche.collection)
(use dbd.sqlite3)

(define connection
  (dbi-connect "dbi:sqlite3:example.db"))

(call-with-transaction connection
  (lambda (tran)
    (dbi-execute
     (dbi-prepare connection
                  "INSERT INTO tbl1 VALUES('foo', 26, 0);"))

    (dbi-execute
     (dbi-prepare connection
                  "INSERT INTO tbl1 VALUES(?, ?, ?);")
     "bar" 32 0)))
