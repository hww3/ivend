#include <ivend.h>

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


string action_preferences(string mode, object id){
  string retval="";

  // we haven't selected a module, so show the options.

  if(!id->variables->_module) {
     retval+="<obox title=\"<font face=helvetica,arial>Preferences</font>\">\n"
	"<font face=helvetica,arial>\n"
	"To edit preferences for a particular module, please "
	"select the module from the list below.<p><ul>";
     int have_prefs=0;
     foreach(sort(indices(MODULES)), string m){
       array p=({});
       
       if(MODULES[m]->query_preferences && functionp(MODULES[m]->query_preferences))
	 p=MODULES[m]->query_preferences();

       if(sizeof(p)!=0) {
           retval+="<li><a href=\"./?_module=" + m +
             "\">" + MODULES[m]->module_name + "</a><br>";
           have_prefs=1; 
      }
     }
       if(!have_prefs)
           retval+="Sorry, there are no preference options available.";
       retval+="</ul><p></font></obox>";
  }

else {

// show the preference options for this module.

// each preference should contain the following elements:
//
//
//  0: the variable name (no spaces)
//  1: a short description of the variable
//  2: help text
//  3: variable type
//  4: default value (optional)
//  5: a string or array containing valid values (optional)

array  p=MODULES[id->variables->_module]->query_preferences();

mapping pton=([]);
foreach(p, array pref)
  pton+=([pref[0]: pref]);

if(!id->variables->_varname) {

  retval+="<obox title=\"<font face=helvetica,arial>" +
	id->variables->_module + "</font>\"><font face=helvetica,arial>";
    foreach(p, array pref){

      retval+="<a href=\"./?_module=" + id->variables->_module +
		"&_varname=" + pref[0] + "\">" + pref[1] + "</a>: "
	+ CONFIG_ROOT[id->variables->_module][pref[0]] + 
	"<br>";

    }

    retval+="</font></obox>";

  }

  else {  // we've got the varname specified.

  retval+="<obox title=\"<font face=helvetica,arial>" +
	id->variables->_module + " : " + pton[id->variables->_varname][1]
        + "</font>\"><font face=helvetica,arial>"
	  "<form action=\"./?_module=" + id->variables->_module + 
	  "&_varname=" + id->variables->_varname + "\">\n";

    retval+="<input type=submit name=_action value=\"Cancel\"> "
	"<input type=submit name=_action value=\"Apply\"></form>\n"
	"</font></obox>";

  }

}

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
	"menu.main.Store_Maintenance.Reload_store" : action_reloadstore,
	"menu.main.Store_Maintenance.Preferences" : action_preferences
	]);


}
