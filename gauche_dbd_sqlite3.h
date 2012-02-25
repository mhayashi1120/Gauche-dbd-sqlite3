#ifndef DBD_SQLITE3_H
#define DBD_SQLITE3_H

#include <gauche.h>
#include <gauche/extend.h>
#include <gauche/class.h>
#include <gauche/uvector.h>

#include <sqlite3.h>

extern ScmClass *Sqlite3Class;

#define SCM_SQLITE3_P(obj)	(SCM_XTYPEP(obj, Sqlite3Class))
#define SQLITE3_HANDLE_UNBOX(obj) SCM_FOREIGN_POINTER_REF(sqlite3*, obj)
#define SQLITE3_HANDLE_BOX(handle) \
	Scm_MakeForeignPointer(Sqlite3Class, handle)

extern ScmClass *Sqlite3StmtClass;

#define SCM_SQLITE3_STMT_P(obj)	(SCM_XTYPEP(obj, Sqlite3StmtClass))
#define SQLITE3_STMT_HANDLE_UNBOX(obj) SCM_FOREIGN_POINTER_REF(ScmSqlite3Stmt *, obj)
#define SQLITE3_STMT_HANDLE_BOX(handle) \
	Scm_MakeForeignPointer(Sqlite3StmtClass, handle)

typedef struct ScmSqlite3StmtRec {
	sqlite3 *db;
	sqlite3_stmt *core;
	const char * tail;
	int executed;
	int terminated;
} ScmSqlite3Stmt;

extern void Scm_Init_sqlite3lib(ScmModule *module);

extern int Sqlite3DbClose(ScmObj obj);
extern int Sqlite3DbIsClosed(ScmObj obj);


extern sqlite3 * Sqlite3OpenDb(ScmString * path);

extern ScmSqlite3Stmt * Sqlite3StmtMake();

extern int Sqlite3IsStmt(ScmObj obj);
extern ScmObj Sqlite3EscapeString(ScmString * value);
extern int Sqlite3PrepareStmt(ScmObj db_obj, ScmSqlite3Stmt * stmt, ScmString * sql);

extern ScmObj Sqlite3StmtStep(ScmSqlite3Stmt * scm_stmt);
extern int Sqlite3StmtFinish(ScmSqlite3Stmt * scm_stmt);
extern ScmObj Sqlite3StmtColumnNames(ScmSqlite3Stmt * scm_stmt);
extern int Sqlite3StmtIsEnd(ScmSqlite3Stmt * stmt);
extern int Sqlite3StmtIsClosed(ScmSqlite3Stmt * stmt);

/* Epilogue */
SCM_DECL_END

#endif  /* DBD_SQLITE3_H */
