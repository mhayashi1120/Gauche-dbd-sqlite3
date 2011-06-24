#include "gauche_dbd_sqlite3.h"

#include <string.h>
#include <stdlib.h>




ScmClass * ScmSqlite3Class;
ScmClass * ScmSqlite3StmtClass;
static ScmObj sym_closed;

static void Sqlite3_finalize(ScmObj obj)
{
	SCM_ASSERT(SCM_FOREIGN_POINTER_P(obj));
	Sqlite_c_close(obj);
}




static void Sqlite3Stmt_finalize(ScmObj obj)
{
	SCM_ASSERT(SCM_FOREIGN_POINTER_P(obj));
	
	scm_sqlite3_stmt * stmt = SQLITE3_STMT_HANDLE_UNBOX(obj);
	if(stmt->core != NULL) Sqlite_c_stmt_finish(stmt);
}



static void db_check(ScmObj obj)
{
	if(Sqlite_c_closed_p(obj)) Scm_Error("<sqlite3-handle> already closed");
}





static void stmt_check(scm_sqlite3_stmt * stmt){
	if(! stmt->executed) Scm_Error("<sqlite3-stmt-handle> not executed yet");
	if(stmt->terminated) Scm_Error("<sqlite3-stmt-handle> already closed");
}









scm_sqlite3_stmt * Sqlite_c_stmt_make()
{
	scm_sqlite3_stmt * stmt = malloc(sizeof(scm_sqlite3_stmt));

	stmt->tail = NULL;
	stmt->core = NULL;
	
	stmt->executed = 0;
	stmt->terminated = 0;
	
	return stmt;
}









int Sqlite_c_execute(ScmObj db_obj, scm_sqlite3_stmt * stmt, ScmString * sql){
	sqlite3_stmt * vm = NULL;
	sqlite3 * db;
	int status;

	db_check(db_obj);
	db = SQLITE3_HANDLE_UNBOX(db_obj);

	if(sqlite3_prepare(db, Scm_GetStringConst(sql),
		SCM_STRING_SIZE(sql),
		&vm, 0) != SQLITE_OK)
	{
		return 0;
	}
	
	stmt->tail = NULL;
	stmt->core = vm;
	
	stmt->executed = 1;
	stmt->terminated = 0;
	return 1;
}




ScmObj Sqlite_c_stmt_step(scm_sqlite3_stmt * stmt)
{
	unsigned int i, num;
	int rc;
	ScmObj result;
	ScmObj value;

	stmt_check(stmt);

	rc = sqlite3_step(stmt->core);
	if(rc == SQLITE_ROW){
		num = sqlite3_column_count(stmt->core);
		result = Scm_MakeVector(num, SCM_FALSE);
		
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

			Scm_VectorSet(SCM_VECTOR(result), i, value);
		}
		return SCM_OBJ(result);
	}else if(rc == SQLITE_DONE){
		stmt->terminated = 1;
		return SCM_FALSE;
	}else{
		Scm_Error("sqlite3_step failed: %d", rc);
	}
	
}


ScmObj Sqlite_c_stmt_column_names(scm_sqlite3_stmt * stmt){
	int i, num;
	ScmObj value;
	ScmObj result;
	
	num = sqlite3_column_count(stmt->core);
	result = Scm_MakeList(0, SCM_FALSE);

	for(i = 0; i < num; i++){
		value = SCM_MAKE_STR_COPYING(sqlite3_column_name(stmt->core, i));
		result = Scm_Cons(value, result);
	}
	return SCM_OBJ(Scm_Reverse(result));
}


int Sqlite_c_stmt_end_p(scm_sqlite3_stmt * stmt){
	return ((stmt->terminated) ? 1 : 0);
}

ScmObj Sqlite_c_stmt_tail_get(scm_sqlite3_stmt * stmt){
	return ((stmt->tail == NULL ) ? SCM_FALSE : SCM_MAKE_STR_COPYING(stmt->tail));
}




sqlite3 * Sqlite_c_open(ScmString * path)
{
	sqlite3 * db;

	if(sqlite3_open(Scm_GetString(path) , &db) != SQLITE_OK) Scm_Error("OPEN ERROR");

	return db;
}


ScmObj Sqlite_c_escape_string(ScmString * value){
	char * tmp;
	ScmObj result;
	
	tmp = sqlite3_mprintf("%q", Scm_GetStringConst(value));
	result = SCM_MAKE_STR_COPYING(tmp);
	sqlite3_free(tmp);
	return result;
}



int Sqlite_c_stmt_finish(scm_sqlite3_stmt * stmt){
	if(stmt->core){
		sqlite3_finalize(stmt->core);
		stmt->core = NULL;
		return 1;
	}else{
		return 0;
	}
}











int Sqlite_c_close(ScmObj obj)
{
	sqlite3 * db;

	SCM_ASSERT(SCM_FOREIGN_POINTER_P(obj));


	if(Sqlite_c_closed_p(obj)){
		return 0;
	}else{
		Scm_ForeignPointerAttrSet(
			SCM_FOREIGN_POINTER(obj),
			sym_closed,
			SCM_TRUE
			);

		db = SQLITE3_HANDLE_UNBOX(obj);
		sqlite3_close(db);
		return 1;
	}
}



int Sqlite_c_p(ScmObj obj)
{
	return (SCM_SQLITE3_P(obj) ? 1 : 0);
}

int Sqlite_c_stmt_p(ScmObj obj)
{
	return (SCM_SQLITE3_STMT_P(obj) ? 1 : 1);
}


int Sqlite_c_closed_p(ScmObj obj)
{
	SCM_ASSERT(SCM_FOREIGN_POINTER_P(obj));

	return SCM_TRUEP(
	 	Scm_ForeignPointerAttrGet(
			SCM_FOREIGN_POINTER(obj),
	 		sym_closed,
			SCM_FALSE
			)
		);
}





ScmObj Scm_Init_dbd_sqlite3(void)
{
	ScmModule *mod;

	SCM_INIT_EXTENSION(dbd_sqlite3);
	mod = SCM_MODULE(SCM_FIND_MODULE("dbd.sqlite3", TRUE));
	
	
	//Scm_InitBuiltinClass(&Scm_SqliteStmtClass, "<sqlite3-stmt>", NULL, sizeof(ScmSqliteStmt), mod);

	ScmSqlite3Class = Scm_MakeForeignPointerClass(mod, "<sqlite3-handle>", NULL, Sqlite3_finalize, 0);
	ScmSqlite3StmtClass = Scm_MakeForeignPointerClass(mod, "<sqlite3-stmt-handle>", NULL, Sqlite3Stmt_finalize, 0);
	
	
	Scm_Init_dbd_sqlite3lib(mod);
}

