(use dbi)
		

(define connection
  (dbi-connect "dbi:sqlite3:example.db"))

(dbi-open?
 (dbi-execute
  (dbi-prepare connection
               "CREATE TABLE tbl1(id CHAR(10), age SMALLINT, active BOOLEAN);")))

(dbi-execute
 (dbi-prepare connection
              "INSERT INTO tbl1 VALUES('foo', 26, 0);"))

(dbi-execute
 (dbi-prepare connection
              "INSERT INTO tbl1 VALUES(?, ?, ?);")
 "bar" 32 0)

(dbi-do connection "INSERT INTO tbl1 (id) VALUES('baz');")

(dbi-close connection)

