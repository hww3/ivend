/*

  ivend.h: header for ivend system.

*/

#define MODULES id->misc->ivend->modules
#define STORE id->misc->ivend->st
#define CONFIG id->misc->ivend->config->general
#define CONFIG_ROOT id->misc->ivend->config
#define DB id->misc->ivend->db
#define KEYS id->misc->ivend->keys
#define T_O id->misc->ivend->this_object

#define ADMIN_FLAGS id->misc->ivend->admin_flags

#define COMPLEX_ADD_ERROR id->misc->ivend->complex_add_error

#define HAVE_ERRORS sizeof(id->misc->ivend->error)>0

#define ADD_FAILED 1
#define NO_ADD 2
#define ADD_SUCCESSFUL 0

#define NO_BORDER 1
#define NO_ACTIONS 2

#if __VERSION__ >= 0.6
import ".";
#endif
#if __VERSION__ < 0.6  
// don't need to add anything...
#endif


#define VARIABLE_SELECT    0
#define VARIABLE_INTEGER   1
#define VARIABLE_FLOAT     2
#define VARIABLE_STRING    3
#define VARIABLE_MULTIPLE  4
#define VARIABLE_UNAVAILABLE -1

#define SIMPLE_PRICING	0
#define COMPLEX_PRICING 1

#define _extra_heads id->misc->defines[" _extra_heads"]
