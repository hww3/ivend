#include "../include/ivend.h"

inherit "roxenlib";

constant module_name = "Admin Handler Funx";
constant module_type = "handler";

string return_to_admin_menu(object id){

return "<a href=\""  +     add_pre_state(id->not_query,
             (<"menu=main">))+   "\">"
         "Return to Store Administration</a>.\n";

}

int do_clean_sessions(object db){

   string query="SELECT sessionid FROM sessions WHERE timeout < "+time(0);
   array r=db->query(query);
   foreach(r,mapping record){
      foreach(({"customer_info","payment_info","orderdata","lineitems"}),
              string table)
      db->query("DELETE FROM " + table + " WHERE orderid='"
                + record->sessionid + "'");

   }
   string query="DELETE FROM sessions WHERE timeout < "+time(0);

   db->query(query);

   return sizeof(r);
}     

string action_cleansessions(string mode, object id){

          string retval="";

         int r =do_clean_sessions(DB);
         retval+="<p>"+ r+ " Sessions Cleaned Successfully.<p>" +
          return_to_admin_menu(id);

         return retval;
}                    


string action_reloadstore(string mode, object id){

	string retval="";
	id->misc->ivend->this_object->start_store(STORE);
         retval+="Store Restarted Successfully.<p>" +
                return_to_admin_menu(id); 
//	ADMIN_FLAGS=NO_BORDER;
	return retval;

}

mapping register_admin(){

return ([
	"menu.main.Store_Maintenance.Clean_Stale_Sessions" : action_cleansessions,
	"menu.main.Store_Maintenance.Reload_store" : action_reloadstore
	]);


}
