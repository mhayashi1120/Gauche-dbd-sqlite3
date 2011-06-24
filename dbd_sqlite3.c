#include "gauche_dbd_sqlite3.h"

#include <string.h>
#include <stdlib.h>

static void Sqlite_finalize(ScmObj obj, void *data)
{
	ScmSqlite * db = SCM_SQLITE(obj);
	if(db->core != NULL) Sqlite_c_close(obj);
	if(db->dbname != NULL){
		free((char *) db->dbname);
		db->dbname = NULL;
	};
}
static void SqliteStmt_finalize(ScmObj obj, void *data)
{
	ScmSqliteStmt * stmt = SCM_SQLITE_STMT(obj);
	if(stmt->core != NULL) Sqlite_c_stmt_finish(obj);
}

static void db_check(ScmObj obj)
{
	ScmSqlite * db;
	if(!SCM_SQLITE_P(obj)) Scm_Error("<sqlite3-handle> required, but got %S", obj);
	db = SCM_SQLITE(obj);
	if(db->dbname == NULL) Scm_Error("<sqlite3-handle> not opened yet");
	if(db->core == NULL) Scm_Error("<sqlite3-handle> already closed");
}

static void stmt_check(ScmObj obj){
	if(!SCM_SQLITE_STMT_P(obj)) Scm_Error("<sqlite3-stmt> required, but got %S", obj);
}


static ScmObj sqlite_allocate(ScmClass *klass, ScmObj initargs);
static void sqlite_print(ScmObj obj, ScmPort *out, ScmWriteContext *ctx)
{
	ScmSqlite * db = SCM_SQLITE(obj);
	Scm_Printf(out, "#<<sqlite3-handle> %p \"%s\">", db->core, db->dbname);
}
SCM_DEFINE_BUILTIN_CLASS(Scm_SqliteClass,
			 sqlite_print, NULL, NULL,
			 sqlite_allocate,
			 NULL);
static ScmObj sqlite_allocate(ScmClass *klass, ScmObj initargs)
{
	ScmSqlite * db = SCM_NEW(ScmSqlite);
	SCM_SET_CLASS(db, SCM_CLASS_SQLITE);

	Scm_RegisterFinalizer(SCM_OBJ(db), Sqlite_finalize, NULL);

	db->core = NULL;
	db->dbname = NULL;

	return SCM_OBJ(db);
}



static ScmObj sqlite_stmt_allocate(ScmClass *klass, ScmObj initargs);
static void sqlite_stmt_print(ScmObj obj, ScmPort *out, ScmWriteContext *ctx)
{
	ScmSqliteStmt * db = SCM_SQLITE_STMT(obj);
	Scm_Printf(out, "#<<sqlite3-stmt> %p>", db->core);
}



SCM_DEFINE_BUILTIN_CLASS(Scm_SqliteStmtClass,
			 sqlite_stmt_print, NULL, NULL,
			 sqlite_stmt_allocate,
			 NULL
			 );

static ScmObj sqlite_stmt_allocate(ScmClass *klass, ScmObj initargs)
{
	ScmSqliteStmt * stmt = SCM_NEW(ScmSqliteStmt);
	SCM_SET_CLASS(stmt, SCM_CLASS_SQLITE_STMT);

	Scm_RegisterFinalizer(SCM_OBJ(stmt), SqliteStmt_finalize, NULL);

	stmt->core = NULL;

	return SCM_OBJ(stmt);
}














ScmObj Sqlite_c_execute(ScmObj db_obj, ScmObj stmt_obj, ScmString * sql){
	ScmSqlite * db;
	ScmSqliteStmt * stmt = SCM_SQLITE_STMT(stmt_obj);
	sqlite3_stmt * vm = NULL;
	int status;

	db_check(db_obj);
	db = SCM_SQLITE(db_obj);
	if(sqlite3_prepare(db->core, Scm_GetStringConst(sql),
		SCM_STRING_SIZE(sql),
		&vm, 0) != SQLITE_OK)
	{
		return SCM_FALSE;
	}
	
	stmt->tail = NULL;
	stmt->core = vm;
	
	stmt->executed = 1;
	return SCM_OBJ(stmt);
}


ScmObj Sqlite_c_error_message(ScmObj obj){
	ScmSqlite * db = SCM_SQLITE(obj);
	return SCM_MAKE_STR_COPYING(sqlite3_errmsg(db->core));
}


ScmObj Sqlite_c_stmt_step(ScmObj obj)
{
	unsigned int i, num;
	int rc;
	ScmObj result;
	ScmObj value;
	ScmSqliteStmt * stmt;
	
	stmt_check(obj);
	stmt = SCM_SQLITE_STMT(obj);
	if(! stmt->executed) Scm_Error("not executed yet");
	if(stmt->terminated) return SCM_FALSE;

	rc = sqlite3_step(stmt->core);
	if(rc == SQLITE_ROW){
		num = sqlite3_column_count(stmt->core);
		result = Scm_MakeList(0, SCM_FALSE);
		
		for(i = 0; i < num; i++){
			switch (sqlite3_column_type(stmt->core, i))
			{
					case SQLITE_INTEGER:
							value = SCM_MAKE_INT(sqlite3_column_int(stmt->core, i));
							break;
					case SQLITE_FLOAT:
							value = Scm_MakeFlonum(sqlite3_column_double(stmt->core, i));
							break;
					case SQLITE_TEXT:
							value = SCM_MAKE_STR_COPYING(sqlite3_column_text(stmt->core, i));
							break;
					case SQLITE_BLOB:
							Scm_Error("not supported yet: SQLITE_BLOB");
							//value = Scm_MakeU8VectorFromArray(
							//	sqlite3_column_bytes(stmt->core, i),
							//	(unsigned char *)sqlite3_column_blob(stmt->core, i));
							//break;
					case SQLITE_NULL:
							value = SCM_FALSE;
							break;
					default:
							Scm_Error("unknown sqlite3_column_type");
			}

			result = Scm_Cons(value, result);
		}
		return SCM_OBJ(Scm_Reverse(result));
	}else if(rc == SQLITE_DONE){
		stmt->terminated = 1;
		return SCM_FALSE;
	}else{
		Scm_Error("sqlite3_step failed: %d", rc);
	}
	
}


ScmObj Sqlite_c_stmt_column_names(ScmObj obj){
	ScmSqliteStmt * stmt;
	int i, num;
	ScmObj value;
	ScmObj result;
	stmt_check(obj);
	stmt = SCM_SQLITE_STMT(obj);
	num = sqlite3_column_count(stmt->core);
	result = Scm_MakeList(0, SCM_FALSE);

	for(i = 0; i < num; i++){
		value = SCM_MAKE_STR_COPYING(sqlite3_column_name(stmt->core, i));
		result = Scm_Cons(value, result);
	}
	return SCM_OBJ(Scm_Reverse(result));
}


ScmObj Sqlite_c_stmt_end_p(ScmObj obj){
	ScmSqliteStmt * stmt;
	stmt_check(obj);
	stmt = SCM_SQLITE_STMT(obj);
	return ((stmt->terminated) ? SCM_TRUE : SCM_FALSE);
}

ScmObj Sqlite_c_stmt_tail_get(ScmObj obj){
	ScmSqliteStmt * stmt;
	stmt_check(obj);
	stmt = SCM_SQLITE_STMT(obj);
	return ((stmt->tail == NULL ) ? SCM_FALSE : SCM_MAKE_STR_COPYING(stmt->tail));
}




ScmObj Sqlite_c_open(ScmObj obj, ScmString * dbpath)
{
	sqlite3 * dbt;
	ScmSqlite * db;
	char * dbname;

	db = SCM_SQLITE(obj);

	if(sqlite3_open(Scm_GetString(dbpath) , &dbt) != SQLITE_OK) return SCM_FALSE;

	dbname = malloc((sizeof(char) * SCM_STRING_SIZE(dbpath)) + 1);
	strncpy(dbname, Scm_GetStringConst(dbpath), SCM_STRING_SIZE(dbpath));
	dbname[SCM_STRING_SIZE(dbpath)] = '\0';

	db->core = dbt;
	db->dbname = (const char *) dbname;
	return SCM_OBJ(db);


}


ScmObj Sqlite_c_escape_string(ScmObj obj, ScmString * value){
	char * tmp;
	ScmObj result;
	tmp = sqlite3_mprintf("%q", Scm_GetStringConst(value));
	result = SCM_MAKE_STR_COPYING(tmp);
	sqlite3_free(tmp);
	return result;
}



ScmObj Sqlite_c_stmt_finish(ScmObj obj){
	ScmSqliteStmt * stmt = SCM_SQLITE_STMT(obj);
	if(stmt->core){
		sqlite3_finalize(stmt->core);
		stmt->core = NULL;
		return SCM_TRUE;
	}else{
		return SCM_FALSE;
	}
}












ScmObj Sqlite_c_close(ScmObj obj)
{
	ScmSqlite *db;
	db_check(obj);
	
	db = SCM_SQLITE(obj);
	if(db->core != NULL){
		sqlite3_close(db->core);
		db->core = NULL;
		return SCM_TRUE;
	}else{
		return SCM_FALSE;
	}
}


ScmObj Sqlite_c_p(ScmObj obj)
{
	return (SCM_SQLITE_P(obj) ? SCM_TRUE : SCM_FALSE);
}

ScmObj Sqlite_c_stmt_p(ScmObj obj)
{
	return (SCM_SQLITE_STMT_P(obj) ? SCM_TRUE : SCM_FALSE);
}


ScmObj Sqlite_c_closed_p(ScmObj obj)
{
	ScmSqlite *db;
	if(!SCM_SQLITE_P(obj)) Scm_Error("<sqlite3-handle> required, but got %S", obj);
	db = SCM_SQLITE(obj);
	if((db->core == NULL) && (db->dbname != NULL)){
		return SCM_TRUE;
	}else{
		return SCM_FALSE;
	}
}





ScmObj Scm_Init_dbd_sqlite3(void)
{
	ScmModule *mod;

	SCM_INIT_EXTENSION(dbd_sqlite3);
	mod = SCM_MODULE(SCM_FIND_MODULE("dbd.sqlite3", TRUE));
	
	Scm_InitBuiltinClass(&Scm_SqliteClass, "<sqlite3-handle>", NULL, sizeof(ScmSqlite), mod);
	Scm_InitBuiltinClass(&Scm_SqliteStmtClass, "<sqlite3-stmt>", NULL, sizeof(ScmSqliteStmt), mod);
	Scm_Init_dbd_sqlite3lib(mod);
}

