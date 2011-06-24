#include <gauche.h>
#include <gauche/extend.h>
#include <gauche/class.h>
#include <gauche/uvector.h>

#include <sqlite3.h>


SCM_CLASS_DECL(Scm_SqliteClass);
#define SCM_CLASS_SQLITE (&Scm_SqliteClass)

typedef struct ScmSqliteRec {
	SCM_HEADER;
	sqlite3 *core;
	const char * dbname;
} ScmSqlite;

#define SCM_SQLITE(obj)		((ScmSqlite *)(obj))
#define SCM_SQLITE_P(obj)	(SCM_XTYPEP(obj, SCM_CLASS_SQLITE))



SCM_CLASS_DECL(Scm_SqliteStmtClass);
#define SCM_CLASS_SQLITE_STMT (&Scm_SqliteStmtClass)

typedef struct ScmSqliteStmtRec {
	SCM_HEADER;
	sqlite3_stmt *core;
	const char * tail;
	int executed;
	int terminated;
} ScmSqliteStmt;
#define SCM_SQLITE_STMT(obj)		((ScmSqliteStmt *)(obj))
#define SCM_SQLITE_STMT_P(obj)	(SCM_XTYPEP(obj, SCM_CLASS_SQLITE_STMT))



extern void Scm_Init_sqlite3lib(ScmModule *module);


extern ScmObj Sqlite_c_close(ScmObj obj);
extern ScmObj Sqlite_c_open(ScmObj obj, ScmString * arg_path);
extern ScmObj Sqlite_c_p(ScmObj obj);
extern ScmObj Sqlite_c_stmt_p(ScmObj obj);
extern ScmObj Sqlite_c_closed_p(ScmObj obj);
extern ScmObj Sqlite_c_escape_string(ScmObj obj, ScmString * value);
extern ScmObj Sqlite_c_execute(ScmObj db_obj, ScmObj stmt_obj, ScmString * sql);
extern ScmObj Sqlite_c_error_message(ScmObj obj);
extern ScmObj Sqlite_c_stmt_tail_get(ScmObj obj);
extern ScmObj Sqlite_c_stmt_step(ScmObj obj);
extern ScmObj Sqlite_c_stmt_end_p(ScmObj obj);
extern ScmObj Sqlite_c_stmt_finish(ScmObj obj);
extern ScmObj Sqlite_c_stmt_column_names(ScmObj obj);


