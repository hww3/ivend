#include "../include/ivend.h"

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

if(id->variables->write_config){

Config.write_section(id->misc->ivend->this_object->query("configdir")+
  CONFIG->config, "addins", id->misc->ivend->config->addins);
  saved=1;
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
  "<h2>Add-In Manager</h2>";

retval+="<form action=./>\n"
  "<input type=hidden name=change_settings value=1>\n";

foreach(sort(indices(a)), string m)
  retval+="<input type=checkbox name=" + m + " value=load" +
((id->misc->ivend->config->addins 
&&id->misc->ivend->config->addins[m]=="load")?" checked":"") +
       "> &nbsp; " + a[m] + "<br>";

retval+="<input type=submit value=Update>\n</form>";

if(!saved)
  retval+="<br><a href=./?write_config=1>Save Configuration</a>";
return retval;

}

mixed write_config(){

}

mixed query_tag_callers(){

  return ([  ]);

}

mixed register_admin(){

  return ([ "addins" : addin_handler ]);
}


