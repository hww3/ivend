/*

  ivend.h: header for ivend system.

*/

#define MODULES id->misc->ivend->modules
#define STORE id->misc->ivend->st
#define CONFIG id->misc->ivend->config->general
#define DB id->misc->ivend->db
#define KEYS id->misc->ivend->keys
#define T_O id->misc->ivend->this_object

#define ADMIN_FLAGS id->misc->ivend->admin_flags

#define NO_BORDER 1

#if __VERSION__ >= 0.6
import ".";
#endif
#if __VERSION__ < 0.6  
// don't need to add anything...
#endif
