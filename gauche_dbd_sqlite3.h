#ifndef DBD_SQLITE3_H
#define DBD_SQLITE3_H

#include <gauche.h>
#include <gauche/extend.h>
#include <gauche/class.h>
#include <gauche/uvector.h>

#include <sqlite3.h>

extern ScmClass * ScmSqlite3Class;
typedef ScmForeignPointer ScmSqlite3;

#define SCM_SQLITE3_P(obj)	(SCM_XTYPEP(obj, ScmSqlite3Class))
#define SQLITE3_HANDLE_UNBOX(obj) SCM_FOREIGN_POINTER_REF(sqlite3*, obj)
#define SQLITE3_HANDLE_BOX(handle) \
	Scm_MakeForeignPointer(ScmSqlite3Class, handle)

extern ScmClass * ScmSqlite3StmtClass;
typedef ScmForeignPointer ScmSqliteStmt3;

#define SCM_SQLITE3_STMT_P(obj)	(SCM_XTYPEP(obj, ScmSqlite3StmtClass))
#define SQLITE3_STMT_HANDLE_UNBOX(obj) SCM_FOREIGN_POINTER_REF(scm_sqlite3_stmt *, obj)
#define SQLITE3_STMT_HANDLE_BOX(handle) \
	Scm_MakeForeignPointer(ScmSqlite3StmtClass, handle)

typedef struct scm_sqlite3_stmt_rec {
	sqlite3_stmt *core;
	const char * tail;
	int executed;
	int terminated;
} scm_sqlite3_stmt;

extern void Scm_Init_sqlite3lib(ScmModule *module);

extern ScmObj Sqlite3Close(ScmObj obj);
extern int Sqlite3ClosedP(ScmObj obj);


extern sqlite3 * Sqlite3Open(ScmString * path);

extern scm_sqlite3_stmt * Sqlite3StmtMake();

extern ScmObj Sqlite3StmtP(ScmObj obj);
extern ScmObj Sqlite3EscapeString(ScmString * value);
extern ScmObj Sqlite3Prepare(ScmObj db_obj, scm_sqlite3_stmt * stmt, ScmString * sql);

extern ScmObj Sqlite3StmtStep(scm_sqlite3_stmt * scm_stmt);
extern ScmObj Sqlite3StmtFinish(scm_sqlite3_stmt * scm_stmt);
extern ScmObj Sqlite3StmtColumnNames(scm_sqlite3_stmt * scm_stmt);


/* Epilogue */
SCM_DECL_END

#endif  /* DBD_SQLITE3_H */
