#include <ivend.h>

inherit "roxenlib";

constant module_name = "Addin Handler";
constant module_type = "handler";    

int saved=1;

mixed addin_handler (string mode, object id){
string retval="";

if(!id->misc->ivend->config->addins) {
  id->misc->ivend->config->addins=([]);
  saved=0;
  }

mapping a=iVend.config()->scan_modules("addin",
id->misc->ivend->this_object->query("root") +
"src/modules");
a+=iVend.config()->scan_modules("addin",
CONFIG->root + "/modules");

if(id->variables->write_config){
object privs=Privs("Writing config section...");
Config.write_section(id->misc->ivend->this_object->query("configdir")+
  CONFIG->config, "addins", id->misc->ivend->config->addins);
  saved=1;
privs=0;
id->misc->ivend->this_object->start_store(STORE);
  }

if(id->variables->change_settings){ 
  id->misc->ivend->config->addins=([]);
  
  foreach(indices(id->variables), string m){
   if(id->variables[m]=="load") {
      id->misc->ivend->config->addins[m]="load";
      }
      saved=0;
  }

}
if(!a) return "No Addins available at this time.";

retval+="<body bgcolor=white text=navy>\n"
  "<font face=helvetica,arial>\n"
  "<obox title=\"<font face=helvetica,arial>Add-In Manager</font>\">"
"<font face=\"helvetica,arial\">"
"Below are Add-Ins which are available for use with this store. "
"You may choose which Add-Ins to load by checking the box next to "
"each option. Click on the Update button below to confirm your "
"selections. <p>"
"<i>NOTE: Some changes may not take effect until the iVend module "
"is reloaded.</i><p>";

retval+="<form action=./>\n"
  "<input type=hidden name=\"change_settings\" value=1>\n";

foreach(sort(indices(a)), string m)
  retval+="<input type=checkbox name=\"" + m + "\" value=\"load\"" +
((id->misc->ivend->config->addins 
&&id->misc->ivend->config->addins[m]=="load")?" checked":"") +
       "> &nbsp; " + a[m] + "<br>";

retval+="<p><input type=\"submit\" value=\"Update Settings\">\n</form>";

if(!saved)
  retval+="<br><a href=\"./?write_config=1\">Save Configuration</a>";

retval+="</font></obox>";
return retval;

}

mixed write_config(){

}

mixed query_tag_callers(){

  return ([  ]);

}

mixed 
register_admin(){

  return ([ "menu.main.Store_Administration.Add-ins_Manager" :
    addin_handler ]);
}


