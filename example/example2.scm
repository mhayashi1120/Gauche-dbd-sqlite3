(use dbi)
(use gauche.collection)

(define connection 
  (dbi-connect "dbi:sqlite3:example.db"))

(for-each
 (lambda (row)
   (format
    (current-output-port)
    "id:~a  age:~a\n"
    (dbi-get-value row 0)
    (dbi-get-value row 1)))
 (dbi-execute
  (dbi-prepare connection
               "SELECT id, age FROM tbl1 ORDER BY age ASC;")))


(dbi-close connection)

