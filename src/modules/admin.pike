#include <ivend.h>

inherit "roxenlib";

constant module_name = "Admin Handler Funx";
constant module_type = "handler";

void start(mapping config){

  perror("starting admin handler...\n");
  
}

string return_to_admin_menu(object id){

return "<a href=\""  +     add_pre_state(id->not_query,
             (<"menu=main">))+   "\">"
         "Return to Store Administration</a>.\n";

}

void event_admindelete(string event, object id, mapping args){
if(args->type=="product")
  DB->query("DELETE FROM item_options WHERE product_id='" + args->id + "'");
return;
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

string action_itemoptions(string mode, object id){
string retval="<html><head><title>Item Options</title></head>\n"
	"<body bgcolor=white text=navy>\n"
	"<font face=helvetica>";
mapping v=id->variables;
ADMIN_FLAGS=NO_BORDER;
retval+="Options for " + v->id +"<p>";

if(v->add) {
  if(!catch(DB->query("INSERT INTO item_options VALUES('" + v->id + "','"
+ upper_case(v->option_type) + "','" + upper_case(v->option_code) + "','"
+ DB->quote(v->description)  + "'," + (v->surcharge||0.00) + ")")))
    retval+="<font size=1>Item Option Added Successfully.</font><br>";
  else retval+="<font size=1>An error occurred while adding this option:<br>"
   + DB->error() + "\n<br>";
}

if(v->delete) {
  if(!catch(DB->query("DELETE FROM item_options WHERE product_id='" +
   v->id + "' AND option_type='" + v->option_type + "' AND option_code='"
   + v->option_code + "'"))) 
    retval+="<font size=1>Item Option Deleted Successfully.</font><br>";
}

retval+="<form action=\"./\">\n"
  "<input type=hidden name=id value=\"" + v->id + "\">\n";

array r=DB->query("SELECT * FROM item_options WHERE product_id='" + v->id
+ "' ORDER BY option_type, option_code");

  retval+="<table border=1>\n<tr><th>Option Type</th><th>Option Code</th>"
   "<th>Option Name</th><th>Surcharge</th><td></td></tr>\n";
if(!r || sizeof(r)<1) retval+="<tr><td colspan=5 align=center>No Item "
  "Options Defined.</td></tr>\n";

else {

  foreach(r,mapping row)
   retval+="<tr><td>" + row->option_type + "</td><td>" + row->option_code
    + "</td><td>" + row->description + "</td><td>" + sprintf("%.2f",
    (float)(row->surcharge)) + "</td><td><font size=1><a href=\"./?id=" +
	v->id + "&option_type=" + row->option_type + "&option_code=" +
	row->option_code + "&delete=1\">Delete</a></font></td></tr>\n";
}

retval+="<tr><td><input type=text name=option_type size=10></td><td>"
  "<input type=text name=option_code size=10></td><td>"
  "<input type=text name=description size=30></td><td>"
  "<input type=text name=surcharge size=6</td><td><font size=2><input "
  "type=submit name=add value=add></font></td></tr>\n";
  retval+="</table>";
retval+="</form>";
retval+="<center><font size=-1>"
	"<form><input type=reset onclick=window.close() value=Close></form>"
	"</font></center>";
retval+="</font></body></html>";
return retval;
}

string action_dropdown(string mode, object id){
  string retval="";
  if(!id->variables->edit){
    array f=get_dir(CONFIG->root + "/db");
    if(sizeof(f)>0)
      retval+="You have configured dropdown boxes for the following "
	"Table : Fields:<p><ul>";
    foreach(f, string file){
      retval+="<li><a href=\"./?edit=" + file  + "\">" +
 	replace((file-".val"),"_",":")+"</a>\n";
    }

    if(sizeof(f)>0) retval+="</ul>";
    else retval+="You have not configured any dropdowns yet.<p>";
  }
  else { 
    retval+="Editing " + id->variables->edit + ":<p>";
    retval+="<form action=\"./\">\n"
	"<input type=hidden name=edit value=\"" + id->variables->edit 
	+ "\">\n";
    string f=Stdio.read_file(CONFIG->root + "/db/" + id->variables->edit);
    retval+="<textarea name=contents rows=50 cols=10>" + f +
	"</textarea>\n";
    retval+="<input type=submit name=commit value=\"Commit\"></form>\n";
  }
  return retval;
}

string action_cleansessions(string mode, object id){

          string retval="";

         int r =do_clean_sessions(DB);
         retval+="<p>"+ r+ " Sessions Cleaned Successfully.<p>" +
          return_to_admin_menu(id);

         return retval;
}                    


int saved=1;

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
	 p=MODULES[m]->query_preferences(id);

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

array  p=MODULES[id->variables->_module]->query_preferences(id);
if(sizeof(p)==0) return "";
mapping pton=([]);
foreach(p, array pref){
  pton+=([pref[0]: pref]);
}
if(!CONFIG_ROOT[id->variables->_module])
  CONFIG_ROOT[id->variables->_module]=([]);
if(!id->variables->_varname) {

  retval+="<obox title=\"<font face=helvetica,arial>" +
	id->variables->_module + "</font>\"><font face=helvetica,arial>";
    foreach(p, array pref){

      retval+=(pref[3]!=VARIABLE_UNAVAILABLE?"<a href=\"./?_module=" +
id->variables->_module +
		"&_varname=" + pref[0] + "\">" + pref[1] + "</a>:" :
"<font color=gray>" + pref[0] +"</font>: ")
	+ (CONFIG_ROOT[id->variables->_module]?
(arrayp(CONFIG_ROOT[id->variables->_module][pref[0]])? 
(CONFIG_ROOT[id->variables->_module][pref[0]]*", ")
:CONFIG_ROOT[id->variables->_module][pref[0]]):"")
+ 
	"<br>";

    }

    retval+="</font></obox>";

  }

  else {  // we've got the varname specified.

  if(id->variables->_action=="Cancel") {

  mapping z;
object privs=Privs("iVend: Writing Config File ");
z=Config.read(Stdio.read_file(id->misc->ivend->this_object->query("configdir")+
  CONFIG->config));
privs=0;

CONFIG_ROOT[id->variables->_module][id->variables->_varname]=z[id->variables->_module][id->variables->_varname];
id->variables[id->variables->_varname]=CONFIG_ROOT[id->variables->_module][id->variables->_varname];
  }


if(id->variables[id->variables->_varname])
switch(pton[id->variables->_varname][3]){  
case VARIABLE_INTEGER: 
	int d;
	if(sscanf(id->variables[id->variables->_varname],"%d",d)!=1) {
	  retval+="<b>You must supply an integer value for this preference.</b><p>";
	id->variables[id->variables->_varname]=id->variables["_" + 
		id->variables->_varname];
	}

  break;
case VARIABLE_FLOAT: 
	float d;
	if(sscanf(id->variables[id->variables->_varname],"%f",d)!=1) {
	  retval+="<b>You must supply a float value for this preference.</b><p>";
	id->variables[id->variables->_varname]=id->variables["_" + 
		id->variables->_varname];
	}

  break;

  }

  if(id->variables->_action=="Apply" || id->variables->_action=="Save") {


    if(id->variables[id->variables->_varname]!=
	id->variables["_" + id->variables->_varname]) {
    if(pton[id->variables->_varname][3]==VARIABLE_MULTIPLE) {
m_delete(CONFIG_ROOT[id->variables->_module], id->variables->_varname);
CONFIG_ROOT[id->variables->_module][id->variables->_varname]=id->variables[id->variables->_varname]/"\000";
	}
    else
    CONFIG_ROOT[id->variables->_module][id->variables->_varname]=
	id->variables[id->variables->_varname];
    saved=0;
    }
  }

  if(id->variables->_action=="Save" && !saved) {

  object privs=Privs("iVend: Writing Config File ");
Config.write_section(id->misc->ivend->this_object->query("configdir")+
  CONFIG->config, id->variables->_module,
	CONFIG_ROOT[id->variables->_module]);
privs=0;
  saved=1;

  }

  retval+="<obox title=\"<font face=helvetica,arial><a href='" 
	"?_module="+ id->variables->_module + "'>" +
	id->variables->_module + "</a> : " +
	pton[id->variables->_varname][1]
        + "</font>\"><font face=helvetica,arial>"
	  "<form method=post action=\"./?_module=" +
	  id->variables->_module + 
	  "&_varname=" + id->variables->_varname + "\">\n";

    retval+=(pton[id->variables->_varname][2] ||"") + "<br>";

    switch(pton[id->variables->_varname][3]){
      case VARIABLE_UNAVAILABLE:
        retval+="This option is currently unavailable.";
      break;

      case VARIABLE_INTEGER:
	retval+="<input type=hidden name=\"_" +id->variables->_varname
	  + "\" value=\"" +
	( CONFIG_ROOT[id->variables->_module][id->variables->_varname]
	 || "~BLANK_VALUE~" ) + "\">\n";
	retval+="<input type=text size=20 name=\"" +
	  id->variables->_varname + "\" value=\"" +
	( CONFIG_ROOT[id->variables->_module][id->variables->_varname]
                || pton[id->variables->_varname][4] || "" ) + "\">\n";
	retval+=" <i>(An Integer Value)</i><p>"; 
      break;

      case VARIABLE_FLOAT:
	retval+="<input type=hidden name=\"_" +id->variables->_varname
	  + "\" value=\"" +
	( CONFIG_ROOT[id->variables->_module][id->variables->_varname]
	 || "~BLANK_VALUE~" ) + "\">\n";
	retval+="<input type=text size=20 name=\"" +
	  id->variables->_varname + "\" value=\"" +
	( CONFIG_ROOT[id->variables->_module][id->variables->_varname]
                || pton[id->variables->_varname][4] || "" ) + "\">\n";
	retval+=" <i>(A Float Value)</i><p>"; 
      break;

      case VARIABLE_STRING:
	retval+="<input type=hidden name=\"_" +id->variables->_varname
	  + "\" value=\"" +
	( CONFIG_ROOT[id->variables->_module][id->variables->_varname]
		|| "~BLANK_VALUE~" ) + "\">\n";
	retval+="<input type=text size=40 name=\"" +
	  id->variables->_varname + "\" value=\"" +
	( CONFIG_ROOT[id->variables->_module][id->variables->_varname]
                || pton[id->variables->_varname][4] || "" ) + "\">\n";
	retval+=" <i>(A String)</i><p>"; 
      break;

      case VARIABLE_MULTIPLE:
      case VARIABLE_SELECT:

	retval+="<input type=hidden name=\"_" + id->variables->_varname
	  + "\" value=\"" + ( CONFIG_ROOT[id->variables->_module] && 
CONFIG_ROOT[id->variables->_module][id->variables->_varname]?
(arrayp(CONFIG_ROOT[id->variables->_module][id->variables->_varname])?
	(CONFIG_ROOT[id->variables->_module][id->variables->_varname] *
"\000"):CONFIG_ROOT[id->variables->_module][id->variables->_varname])
               :"~BLANK_VALUE~") + "\">\n";

	retval+="<SELECT " + 
	  (pton[id->variables->_varname][3]==VARIABLE_MULTIPLE? 
		"MULTIPLE SIZE=5":"") +
          " NAME=\"" +
	  id->variables->_varname + "\">";
	array selected_options=({});

if(arrayp(CONFIG_ROOT[id->variables->_module][id->variables->_varname]))
 selected_options=CONFIG_ROOT[id->variables->_module][id->variables->_varname];
else
if(zero_type(CONFIG_ROOT[id->variables->_module][id->variables->_varname])==1)
 selected_options=({pton[id->variables->_varname][4]});
else
selected_options=({CONFIG_ROOT[id->variables->_module][id->variables->_varname]});
	multiset selected=mkmultiset(selected_options);
        foreach(pton[id->variables->_varname][5], string choice){

	  retval+="<option " +(selected[choice]?"SELECTED":"") +">" +
choice
	+ "\n";
	}
	retval+="</select><p>";

      break;    

    }

    retval+="<input type=submit name=_action value=\"Cancel\"> "
	"<input type=submit name=_action value=\"Apply\">\n";
    if(!saved)
      retval+="<input type=submit name=_action value=\"Save\">";
    retval+="</form></font></obox>";

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
	"menu.main.Store_Maintenance.Reload_Store" : action_reloadstore,
	"menu.main.Store_Maintenance.Preferences" : action_preferences,
	"menu.main.Store_Administration.Drop_Down_Menus" : action_dropdown,
	"add.product.Item_Options":action_itemoptions,
	"getmodify.product.Item_Options":action_itemoptions

	]);


}

mapping query_event_callers() {

  return (["admindelete": event_admindelete ]);
}
