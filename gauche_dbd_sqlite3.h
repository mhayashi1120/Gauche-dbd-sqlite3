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


extern int Sqlite_c_close(ScmObj obj);
extern int Sqlite_c_closed_p(ScmObj obj);


extern sqlite3 * Sqlite_c_open(ScmString * path);

extern int Sqlite_c_p(ScmObj db_obj);

extern scm_sqlite3_stmt * Sqlite_c_stmt_make();

extern int Sqlite_c_stmt_p(ScmObj obj);
extern ScmObj Sqlite_c_escape_string(ScmString * value);
extern int Sqlite_c_execute(ScmObj db_obj, scm_sqlite3_stmt * stmt, ScmString * sql);

extern ScmObj Sqlite_c_stmt_tail_get(scm_sqlite3_stmt * scm_stmt);
extern ScmObj Sqlite_c_stmt_step(scm_sqlite3_stmt * scm_stmt);
extern int Sqlite_c_stmt_end_p(scm_sqlite3_stmt * scm_stmt);
extern int Sqlite_c_stmt_finish(scm_sqlite3_stmt * scm_stmt);
extern ScmObj Sqlite_c_stmt_column_names(scm_sqlite3_stmt * scm_stmt);


