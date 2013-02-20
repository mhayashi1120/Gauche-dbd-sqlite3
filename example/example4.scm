(use dbi)
(use gauche.collection)
(use dbd.sqlite3)
(use gauche.version)

(unless (version>=? (sqlite3-libversion) "3.7.13")
  (error "URI filename is not working in this version of libsqlite3 "
         (sqlite3-libversion)))

(define connection
  (dbi-connect "dbi:sqlite3:file:example.db?mode=memory"))

(map print
     (dbi-do connection "select :a1, @a2, $a3, ?4, ?, ?6, :a7"
             '(:pass-through #t) :a1 1 :@a2 2 :$a3 3 :4 4 :? 5 :?6 6 ::a7 7))

(dbi-close connection)

