#ifndef DBD_SQLITE3_H
#define DBD_SQLITE3_H

#include <gauche.h>
#include <gauche/extend.h>
#include <gauche/class.h>
#include <gauche/uvector.h>

#include <sqlite3.h>

extern ScmClass *Sqlite3Class;
typedef ScmForeignPointer ScmSqlite3;

#define SCM_SQLITE3_P(obj)	(SCM_XTYPEP(obj, Sqlite3Class))
#define SQLITE3_HANDLE_UNBOX(obj) SCM_FOREIGN_POINTER_REF(sqlite3*, obj)
#define SQLITE3_HANDLE_BOX(handle) \
	Scm_MakeForeignPointer(Sqlite3Class, handle)

extern ScmClass *Sqlite3StmtClass;
typedef ScmForeignPointer ScmSqliteStmt3;

#define SCM_SQLITE3_STMT_P(obj)	(SCM_XTYPEP(obj, Sqlite3StmtClass))
#define SQLITE3_STMT_HANDLE_UNBOX(obj) SCM_FOREIGN_POINTER_REF(ScmSqlite3Stmt *, obj)
#define SQLITE3_STMT_HANDLE_BOX(handle) \
	Scm_MakeForeignPointer(Sqlite3StmtClass, handle)

typedef struct ScmSqlite3StmtRec {
	sqlite3_stmt *core;
	int executed;
	int terminated;
} ScmSqlite3Stmt;

extern void Scm_Init_sqlite3lib(ScmModule *module);

extern int Sqlite3Close(ScmObj obj);
extern int Sqlite3ClosedP(ScmObj obj);


extern sqlite3 * Sqlite3Open(ScmString * path);

extern ScmSqlite3Stmt * Sqlite3StmtMake();

extern int Sqlite3StmtP(ScmObj obj);
extern ScmObj Sqlite3EscapeString(ScmString * value);
extern int Sqlite3Prepare(ScmObj db_obj, ScmSqlite3Stmt * stmt, ScmString * sql);

extern ScmObj Sqlite3StmtStep(ScmSqlite3Stmt * scm_stmt);
extern int Sqlite3StmtFinish(ScmSqlite3Stmt * scm_stmt);
extern ScmObj Sqlite3StmtColumnNames(ScmSqlite3Stmt * scm_stmt);
extern int Sqlite3StmtEndP(ScmSqlite3Stmt * stmt);
extern int Sqlite3StmtClosedP(ScmSqlite3Stmt * stmt);

/* Epilogue */
SCM_DECL_END

#endif  /* DBD_SQLITE3_H */
