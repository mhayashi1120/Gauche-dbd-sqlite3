#include "gauche_dbd_sqlite3.h"

#include <string.h>
#include <stdlib.h>

extern void Scm_Init_dbd_sqlite3lib(ScmModule*);

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

    /* Register stub-generated procedures */
    Scm_Init_dbd_sqlite3lib(mod);
}

