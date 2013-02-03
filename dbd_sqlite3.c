#include "gauche_dbd_sqlite3.h"

#include <string.h>
#include <stdlib.h>

extern void Scm_Init_dbd_sqlite3lib(ScmModule*);

/* 
 -  sqlite3_reset()
 - int sqlite3_bind_blob(sqlite3_stmt*, int, const void*, int n, void(*)(void*));
   => gauche u8vector
    
 - int sqlite3_bind_double(sqlite3_stmt*, int, double);
   => gauche float

 - int sqlite3_bind_int(sqlite3_stmt*, int, int);
 - int sqlite3_bind_int64(sqlite3_stmt*, int, sqlite3_int64);
   => gauche int (bignum)

 - int sqlite3_bind_null(sqlite3_stmt*, int);
   => gauche #f

 - int sqlite3_bind_text(sqlite3_stmt*, int, const char*, int n, void(*)(void*));
 - int sqlite3_bind_text16(sqlite3_stmt*, int, const void*, int, void(*)(void*));
   => gauche text (TODO incomplete string)

 - int sqlite3_bind_value(sqlite3_stmt*, int, const sqlite3_value*);
   => TODO no need to implement?

 - int sqlite3_bind_zeroblob(sqlite3_stmt*, int, int n);
   => TODO ??? empty vector?


 - 5 type of bind parameter is supported native sqlite3

    + ?
    + ?NNN
    + :VVV
    + @VVV
    + $VVV

   but only support a named param `?' suffixed index param is not supported.
   TODO  how to encode parameter name? sqlite3 command seems to accept multibyte string.

 - sqlite3_bind_parameter_index()

 */

/* /\* params: Alist key is name of param, value is gauche object. *\/ */
/* void Sqlite3StmtBind(ScmSqlite3Stmt * stmt, ScmString * name, ScmObject * value) */
/* { */
/*     int index; */
/*     char realName; */
/*     /\* TODO *\/ */
/*     /\* http://www.sqlite.org/c3ref/bind_parameter_name.html */
/*      * the initial ":" or "$" or "@" or "?" is included as part of the name */
/*     *\/ */
/*     realName = Scm_GetStringConst(name); */
/*     index = sqlite3_bind_parameter_index(stmt->core, realName); */

/*     /\* Scm_GetInteger64(value); *\/ */
/*     /\* Scm_GetStringConst(value); *\/ */
/*     /\* Scm_GetDouble(value); *\/ */
/* } */

/*
 * Module functions.
 */

ScmObj Scm_Init_dbd_sqlite3(void)
{
    ScmModule *mod;

    /* Register this DSO to Gauche */
    SCM_INIT_EXTENSION(dbd_sqlite3);

    /* Create the module if it doesn't exist yet. */
    mod = SCM_MODULE(SCM_FIND_MODULE("dbd.sqlite3", TRUE));

    /* Register stub-generated procedures */
    Scm_Init_dbd_sqlite3lib(mod);
}

