/*

  ivend.h: header for ivend system.

*/

#define MODULES id->misc->ivend->modules
#define STORE id->misc->ivend->st
#define CONFIG id->misc->ivend->config->general
#define DB id->misc->ivend->db
#define KEYS id->misc->ivend->keys

#if __VERSION__ >= 0.6
import ".";
#endif
#if __VERSION__ < 0.6  
// don't need to add anything...
#endif
