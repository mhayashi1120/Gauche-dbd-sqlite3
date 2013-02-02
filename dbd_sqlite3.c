#include "gauche_dbd_sqlite3.h"

#include <string.h>
#include <stdlib.h>
#include <gauche/bignum.h>

ScmClass *Sqlite3Class;
ScmClass *Sqlite3StmtClass;

extern void Scm_Init_dbd_sqlite3lib(ScmModule*);
static void Sqlite3Db_finalize(ScmObj obj);
static void Sqlite3Stmt_finalize(ScmObj obj);

static void stmt_check(ScmSqlite3Stmt * stmt)
{
    if (! stmt->executed) Scm_Error("<sqlite3-statement-handle> not executed yet");
    if (stmt->terminated) Scm_Error("<sqlite3-statement-handle> already closed");
}

static int PrepareStatement(ScmSqlite3 * db, const char * sql, ScmSqlite3Stmt * stmt)
{
    sqlite3_stmt * vm = NULL;
    const char * tail;

    if (sqlite3_prepare_v2(db->core, sql, -1, &vm, &tail) != SQLITE_OK) {
	/* Failed */
	return 0;
    }

    stmt->core = vm;
    stmt->tail = tail;

    return 1;
}

static ScmObj MakeRowVector(ScmSqlite3Stmt * stmt)
{
    unsigned int i, num;
    ScmObj result;
    ScmObj value;
    num = sqlite3_column_count(stmt->core);
    result = Scm_MakeVector(num, SCM_FALSE);

    for (i = 0; i < num; i++) {
	switch (sqlite3_column_type(stmt->core, i)) {
	case SQLITE_INTEGER:
	    value = Scm_MakeBignumFromSI(sqlite3_column_int64(stmt->core, i));
	    break;
	case SQLITE_FLOAT:
	    value = Scm_MakeFlonum(sqlite3_column_double(stmt->core, i));
	    break;
	case SQLITE_TEXT:
	    value = SCM_MAKE_STR_COPYING(sqlite3_column_text(stmt->core, i));
	    break;
	case SQLITE_BLOB:
	    value = Scm_MakeU8VectorFromArray(
		sqlite3_column_bytes(stmt->core, i),
		(unsigned char *)sqlite3_column_blob(stmt->core, i));
	    break;
	case SQLITE_NULL:
	    value = SCM_FALSE;
	    break;
	default:
	    Scm_Error("unknown sqlite3_column_type");
	}

	Scm_VectorSet(SCM_VECTOR(result), i, value);
    }

    return SCM_OBJ(result);
}

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

ScmObj Sqlite3StmtStep(ScmSqlite3Stmt * stmt)
{
    int rc;

    stmt_check(stmt);

    rc = sqlite3_step(stmt->core);

    if (rc == SQLITE_ROW) {

	return MakeRowVector(stmt);

    } else if (rc == SQLITE_DONE) {
	/* TODO  */
	/* multiple SELECT statement */
	while (stmt->tail && *stmt->tail) {

	    if (!PrepareStatement(stmt->db, stmt->tail, stmt)) {
	    	/* Failed */
	    	Scm_Error("sqlite3_prepare_v2 failed while handling compound statement.");
	    }

	    do {

	    	rc = sqlite3_step(stmt->core);

	    	if (rc == SQLITE_ROW)
	    	    return MakeRowVector(stmt);

	    	if (rc == SQLITE_DONE)
	    	    break;

	    	Scm_Error("sqlite3_step failed: %d", rc);

	    } while (1);

	}

	stmt->terminated = 1;
	return SCM_FALSE;

    } else {
	/* http://www.sqlite.org/c3ref/c_abort.html */
	Scm_Error("sqlite3_step failed: %d", rc);
    }
}

// TODO remove after canonicalize finalize if can..
int Sqlite3StmtFinish(ScmSqlite3Stmt * stmt)
{
    if (stmt->core == NULL) {
	return 0;
    }

    /* TODO check return value */
    sqlite3_finalize(stmt->core);

    stmt->core = NULL;

    return 1;
}

int Sqlite3DbClose(ScmSqlite3 * db)
{
    if (db->core == NULL) {
	return 0;
    }

    // TODO  check return value
    sqlite3_close(db->core);

    db->core = NULL;
    db->terminated = 1;

    return 1;
}

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

    /* Register classes */
    Sqlite3Class =
	Scm_MakeForeignPointerClass(mod, "<sqlite3-handle>",
				    NULL, Sqlite3Db_finalize, 0);
    Sqlite3StmtClass =
	Scm_MakeForeignPointerClass(mod, "<sqlite3-statement-handle>",
				    NULL, Sqlite3Stmt_finalize, 0);

    /* Register stub-generated procedures */
    Scm_Init_dbd_sqlite3lib(mod);
}

static void Sqlite3Db_finalize(ScmObj obj)
{
    SCM_ASSERT(SCM_FOREIGN_POINTER_P(obj));

    ScmSqlite3 * db = SQLITE3_HANDLE_UNBOX(obj);
    Sqlite3DbClose(db);
}

static void Sqlite3Stmt_finalize(ScmObj obj)
{
    SCM_ASSERT(SCM_FOREIGN_POINTER_P(obj));

    ScmSqlite3Stmt * stmt = SQLITE3_STMT_HANDLE_UNBOX(obj);
    Sqlite3StmtFinish(stmt);
}
