;;
;; Test dbd.sqlite3 module
;;

(use gauche.test)
(test-start "dbd.sqlite3")
(use dbi)
(use dbd.sqlite3)
(use gauche.collection)

;; Normal operation test

(define connection #f)

(define (cleanup-test)
  (define (remove-file file)
    (when (file-exists? file)
      (sys-unlink file)))
  (remove-file "test2.db")
  (remove-file "test2.db-journal"))

(test* "dbi-connect" 
       <sqlite3-connection>
       ;; URI extension
       (let1 c (dbi-connect "dbi:sqlite3:file:test2.db?mode=memory")
         (set! connection c)
         (class-of c)))

(test* "dbi-connect"
       <sqlite3-connection>
       (let1 c (dbi-make-connection
                (dbi-make-driver "sqlite3") ""
                `(("db" . "file:test2.db?mode=memory")))
         (set! connection c)
         (class-of c)))

(test-end)

(cleanup-test)
