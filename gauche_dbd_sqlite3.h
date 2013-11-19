/*
 * gauche_dbd_sqlite3.h
 */

/* Prologue */
#ifndef GAUCHE_DBD_SQLITE3_H
#define GAUCHE_DBD_SQLITE3_H

#include <gauche.h>
#include <gauche/extend.h>
#include <gauche/class.h>
#include <gauche/uvector.h>

#include <sqlite3.h>

SCM_DECL_BEGIN

ScmClass *Sqlite3DbClass;

#define SCM_SQLITE3_DB_P(obj)	(SCM_XTYPEP(obj, Sqlite3DbClass))
#define SQLITE3_DB_HANDLE_UNBOX(obj) SCM_FOREIGN_POINTER_REF(ScmSqlite3Db *, obj)
#define SQLITE3_DB_HANDLE_BOX(handle) \
	Scm_MakeForeignPointer(Sqlite3DbClass, handle)

typedef struct ScmSqlite3DbRec {
	sqlite3 *core;
	int terminated;
	ScmObj stmts;
} ScmSqlite3Db;

ScmClass *Sqlite3StmtClass;

#define SCM_SQLITE3_STMT_P(obj)	(SCM_XTYPEP(obj, Sqlite3StmtClass))
#define SQLITE3_STMT_HANDLE_UNBOX(obj) SCM_FOREIGN_POINTER_REF(ScmSqlite3Stmt *, obj)
#define SQLITE3_STMT_HANDLE_BOX(handle) \
	Scm_MakeForeignPointer(Sqlite3StmtClass, handle)

typedef struct ScmSqlite3StmtRec {
	ScmSqlite3Db *db;
	sqlite3_stmt *core;
	const char *tail;
	int executed;
	int terminated;
	ScmObj params;
} ScmSqlite3Stmt;

extern void Scm_Init_sqlite3lib(ScmModule *module);

/* Epilogue */
SCM_DECL_END

#endif  /* GAUCHE_DBD_SQLITE3_H */
