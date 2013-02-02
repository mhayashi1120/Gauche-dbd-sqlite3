#ifndef DBD_SQLITE3_H
#define DBD_SQLITE3_H

#include <gauche.h>
#include <gauche/extend.h>
#include <gauche/class.h>
#include <gauche/uvector.h>

#include <sqlite3.h>

extern ScmClass *Sqlite3Class;

#define SCM_SQLITE3_P(obj)	(SCM_XTYPEP(obj, Sqlite3Class))
#define SQLITE3_HANDLE_UNBOX(obj) SCM_FOREIGN_POINTER_REF(ScmSqlite3 *, obj)
#define SQLITE3_HANDLE_BOX(handle) \
	Scm_MakeForeignPointer(Sqlite3Class, handle)

typedef struct ScmSqlite3Rec {
	sqlite3 *core;
	int terminated;
} ScmSqlite3;

extern ScmClass *Sqlite3StmtClass;

#define SCM_SQLITE3_STMT_P(obj)	(SCM_XTYPEP(obj, Sqlite3StmtClass))
#define SQLITE3_STMT_HANDLE_UNBOX(obj) SCM_FOREIGN_POINTER_REF(ScmSqlite3Stmt *, obj)
#define SQLITE3_STMT_HANDLE_BOX(handle) \
	Scm_MakeForeignPointer(Sqlite3StmtClass, handle)

typedef struct ScmSqlite3StmtRec {
	ScmSqlite3 *db;
	sqlite3_stmt *core;
	const char *tail;
	int executed;
	int terminated;
} ScmSqlite3Stmt;

extern void Scm_Init_sqlite3lib(ScmModule *module);

extern int Sqlite3DbClose(ScmSqlite3 * db);

extern ScmObj Sqlite3StmtStep(ScmSqlite3Stmt * scm_stmt);
extern int Sqlite3StmtFinish(ScmSqlite3Stmt * scm_stmt);

/* Epilogue */
SCM_DECL_END

#endif  /* DBD_SQLITE3_H */
