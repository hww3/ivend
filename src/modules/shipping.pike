#!NOMODULE

#define DB id->misc->ivend->db
#define CONFIG id->misc->ivend->config
#define TO id->misc->ivend->this_object
#define STORE id->misc->ivend->st
inherit "roxenlib";

constant module_name = "Shipping Handler";
constant module_type = "shipping";

mapping handlers=([]);

mapping query_tag_callers2();
mapping query_container_callers2();    

int initialized;

object|void load_module(string module, mapping config)
{

object m;

string moddir=config->global->general->root + "/src/modules/shipping";
 // perror("loading shipping module "  + module + "\n");
catch(m=(object)clone(compile_file(moddir+"/"+module)));
if(m && objectp(m)) {
  m->start(config);
  return m;
  }
else perror("iVend: the module " + module + " did not load properly.\n");

return;

}

void start(mapping config)
{

initialized=0;
object db;
handlers=([]);

perror(sprintf("%O\n", config));

if(catch(db=iVend.db(config->general->dbhost, config->general->db,
  config->general->dblogin, config->general->dbpassword)))
  {
    perror("iVend: Shipping: Error Connecting to Database.\n");
    return;
  }

if((sizeof(db->list_tables("shipping_types")))==1)
  initialized=1;
else {initialized=0;  return; }
array r=db->query("select * from shipping_types");

foreach(r, mapping row){
	// load modules
  if(objectp(handlers[row->module])) // already loaded that one.
    {
    if(!handlers[row->module]->started)
       handlers[row->module]->start(config);
    }
  else handlers[row->module]=load_module(row->module, config);
  }

return;

}

void stop(mapping config)
{

return;

}

mapping available_modules(mapping config)
{
object m;
string moddir=config->global->general->root + "/src/modules/shipping";
mapping am=([]);

foreach(get_dir(moddir), string name){
  m=0;
  catch(m=(object)clone(compile_file( moddir + "/" + name)));
  
  if(m && objectp(m)) {
  string desc=m->module_name;
  string type=m->module_type;
  if(type=="shipping")
    am[name] = desc;
  }

  else perror("iVend: the module " + name + " did not load properly.\n");
  }

return am;
}

int initialize_db(object id)
{

  perror("initializing shipping module!\n");

if(sizeof(DB->list_tables("shipping_types"))!=1)
  catch(DB->query("CREATE TABLE shipping_types ("
  "  type int(11) DEFAULT '0' NOT NULL auto_increment,"
  "  name varchar(32) DEFAULT '' NOT NULL,"
  "  description blob,"
  "  module varchar(32),"
  "  PRIMARY KEY (type)"
  ") "));
start(CONFIG);
return 0;

}

string showmainmenu(object id)
{
string retval="";
retval+="<b>Configured Shipping Types</b><p>";

array r=DB->query("SELECT * FROM shipping_types ORDER BY type");
if(sizeof(r)==0)
    retval+="No Shipping Types Configured.";
else {
    foreach(r, mapping row)
      retval+= "<A HREF=\"./?mode=showtype&showtype=" + row->type
	+ "\">" +row->name + "</a>: " + row->description + 
	" ( <A HREF=\"./?mode=deletetype&deletetype=" + row->type + 
	"\">Delete</a> )<br>";

  }
retval+="<p><a href=\"./?mode=addtypemenu\">Add Shipping Type</a>";

return retval;
}

string addtypemenu(object id)
{
  string retval="<form action=\"./\">\n"
    "Shipping Type Name: <input type=text size=40 name=name><br>\n"
    "Calculation method: <select name=module>\n";
  mapping am=available_modules(CONFIG);
  foreach(indices(am),string method)
    retval+="<option value=\"" +method + "\">" + am[method] + "\n";
  retval+="</select><br>\nDescription:" 
    "<textarea name=\"description\" cols=60 rows=6></textarea><br>"
    "<input type=hidden name=mode value=doaddtype>\n"
    "<input type=submit name=doaddtype value=AddShippingType>\n</form>";
  return retval;
}

mixed showtype(object id, mapping row)
{

string retval="";

if(!objectp(handlers[row->module]))
  return "This shipping handler has not been loaded.";
else retval+=handlers[row->module]->showtype(id, row);

return retval;

}

mixed deletetype(object id)
{
string retval="";

if(!id->variables->deletetype)
return "you must select a type to delete.";

else {
  array r=DB->query("SELECT * FROM shipping_types WHERE type=" +
    id->variables->deletetype);
  if(handlers[r[0]->module]->deletetype)
    retval+=handlers[r[0]->module]->deletetype(id);
  DB->query("DELETE FROM shipping_types WHERE type=" +
    id->variables->deletetype);
  }

retval+="<p><A href=\"./\">Click here to continue</a>.";

return retval;
}
mixed doaddtype(object id)
{

  DB->query("INSERT INTO shipping_types VALUES(NULL,'" +
	DB->quote(id->variables->name) + "','" +
	DB->quote(id->variables->description) + "','" +
	id->variables->module + "')");
  
  start(id->misc->ivend->config);

  return showmainmenu(id);
}

mixed shipping_admin (string p, object id, object this_object)
{ 
 if(id->auth==0)
      return http_auth_required("iVend Store Orders",
                                "Silly user, you need to login!");
   else if(!this_object->admin_auth(id))
      return http_auth_required("iVend Store Orders",
                                "Silly user, you need to login!");
 

if(id->not_query[sizeof(id->not_query)-1..]!="/")
  return http_redirect(id->not_query + "/" + (id->query?("?" +
id->query):""), id);

if(id->variables->initialize)
  initialize_db(id);

string retval="<title>iVend Shipping Administration</title>\n"
	"<body bgcolor=white text=navy>\n"
	"<font face=\"helvetica,arial\">"
	"<h2>Shipping Administration</h2>\n"
	"<a href=../>Storefront</a> &gt; <A href=./>Shipping Admin</a><p>";

if(!initialized) {
  retval+="This module has not been initialized."
	"<p>Click <a href=./shipping/?initialize=1>here</a> to do this now.";
  return retval;
 }

if(id->variables->mode) {

  switch(id->variables->mode) {
    case "doaddtype":
        retval+=doaddtype(id);
    break;
    case "addtypemenu":
	retval+=addtypemenu(id);
    break;

    case "deletetype":
        retval+=deletetype(id);
    break;
    case "showtype":
	if(id->variables->showtype){
     	 array r=DB->query("SELECT * FROM shipping_types WHERE type=" +
      	  id->variables->showtype );
    	 retval+="<table><tr><td><b>Type:</b></td><td>" + r[0]->name +
	"</td></tr>"; 
	 retval+=showtype(id, r[0]);
	}

    break;

    default:
    break;
  }

}


else retval+=showmainmenu(id);

return retval;

}


mapping register_paths()
{

return ([ "shipping" : shipping_admin ]);

}

/*				*/
/*	The shipping tags	*/
/*				*/

float|string tag_shippingcost(float amt, mixed type, object id){


array r=DB->query("SELECT value FROM lineitems WHERE "
  "lineitem='shipping' AND orderid='"+ id->misc->ivend->SESSIONID +
  "'");
if(sizeof(r)>0) return r[0]->value;
else  return "";

}

string tag_shippingcalc (string tag_name, mapping args,
                    object id, mapping defines) {  

string retval="";
float charge;

string type= (args->type || id->variables->type || "1");

array r=DB->query("SELECT * FROM shipping_types WHERE type=" + type);
if(!r){ perror("error getting shipping type " + type + "\n"); return ""; }

else charge=handlers[r[0]->module]->calculate_shippingcost(type, id); 
if(charge>=0.0)
  return sprintf("%.2f", charge);
else return "Error";

}

string tag_shippingtype (string tag_name, mapping args,
                    object id, mapping defines) {  


string retval;
array r;
string query=("SELECT extension FROM lineitems where orderid='" +
  id->misc->ivend->SESSIONID + "' AND lineitem='shipping'");
// perror(query);
r=DB->query(query);

if(sizeof(r)!=1) return "Error Finding Shipping Data for this order.";
else return r[0]->extension;

}

string tag_shippingadd (string tag_name, mapping args,
                    object id, mapping defines) {  

TO->write_config_section(STORE, "shipping", ([ "sessionid" :
  id->misc->ivend->SESSIONID ]));

int type= (args->type || id->variables->type || 0); 
if(! type)
  return "Error.";

mixed total, charge;
string retval;

if(id->variables["_backup"])
   return "<!--Backing up. CalculateShipping skipped.-->\n";
if(!args->charge){
array r=DB->query("SELECT * FROM shipping_types WHERE type=" + type);
if(!r){ perror("error getting shipping type " + type + "\n"); return ""; }
else charge=handlers[r[0]->module]->calculate_shippingcost(type, id); 
if(charge<0.0)
  return "Error.";
}
else charge=args->charge;

string typename=id->misc->ivend->db->query("SELECT name FROM shipping_types "
  "WHERE type=" + id->variables->type )[0]->name;
id->misc->ivend->db->query("DELETE FROM lineitems WHERE orderid='"
	+ id->misc->ivend->SESSIONID + "' AND lineitem='shipping'");
id->misc->ivend->db->query("INSERT INTO lineitems VALUES('" +
  id->misc->ivend->SESSIONID + "', 'shipping', " + charge + ",'" +
  typename + "')");

return "";

}

string tag_shippingtypes (string tag_name, mapping args,
                    object id, mapping defines) {  


string retval="";
array r;
r=id->misc->ivend->db->query("SELECT * from shipping_types order by type");
int t=0;
foreach(r, mapping row){
retval+="<dt><input type=radio name=type " +((t==0)?("CHECKED"):("")) 
  +" value=\"" + row->type + "\"> <b>"+ row->name + 
  ": $<shippingcalc type=" + row->type + 
  "></b><dd>" + row->description;
  t=1;
}
return retval;

}

mapping query_container_callers(){

  return ([]);

}

mapping query_tag_callers(){

return

 ([
  "shippingtype"    : tag_shippingtype,
  "shippingcost"    : tag_shippingcost,
  "shippingtypes" : tag_shippingtypes,
  "shippingadd"     : tag_shippingadd,
  "shippingcost"    : tag_shippingcost,
  "shippingcalc"    : tag_shippingcalc
  ]);

}
