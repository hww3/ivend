#!NOMODULE


#include <ivend.h>
#include <messages.h>

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

// perror(sprintf("%O\n", config));

//if(catch(
db=iVend.db(config->general->dbhost, config->general->db,
  config->general->dblogin, config->general->dbpassword);
//))
//  {
//    perror("iVend: Shipping: Error Connecting to Database.\n");
//    return;
//  }

if((sizeof(db->list_tables("shipping_types")))==1)
{  initialized=1;
if(sizeof(db->list_fields("shipping_types","availability"))!=1)
  db->query("alter table shipping_types add availability char(254) default ''");

}

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
  DB->query("CREATE TABLE shipping_types ("
  "  type int(11) DEFAULT '0' NOT NULL auto_increment,"
  "  name varchar(32) DEFAULT '' NOT NULL,"
  "  description blob,"
  "  module varchar(32),"
  "  PRIMARY KEY (type)"
  ") ");

start(id->misc->ivend->config);
return 0;

}

string showmainmenu(object id)
{
string retval="";
retval+="<b>Configured Shipping Types</b><p>";

catch(array r=DB->query("SELECT * FROM shipping_types ORDER BY type"));
if(!r || sizeof(r)==0)
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
  mapping am=available_modules(id->misc->ivend->config);
  foreach(indices(am),string method)
    retval+="<option value=\"" +method + "\">" + am[method] + "\n";
  retval+="</select><br>\nDescription:" 
    "<textarea name=\"description\" cols=60 rows=6></textarea><br>"
	"\nAvailability:"
    "<textarea name=\"availability\" cols=60 rows=6></textarea><br>"
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
	id->variables->module + "','" +
	DB->quote(id->variables->availability) + "')");
  
  start(id->misc->ivend->config);

  return showmainmenu(id);
}

mixed shipping_admin (string p, object id)
{ 

// perror(sprintf("%O", config));


if(id->variables->initialize)
  initialize_db(id);

string retval=
	"<h2>Shipping Administration</h2>\n";

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



mixed register_admin()
{

return ({
	([ "mode": "menu.main.Store_Administration.Shipping_Administration",
		"handler": shipping_admin,
		"security_level": 8 ])
	});

}

/*				*/
/*	The shipping tags	*/
/*				*/

float|string tag_shippingcost (string tag_name, mapping args,
                    object id, mapping defines) {  


array r=DB->query("SELECT value FROM lineitems WHERE "
  "lineitem='shipping' AND orderid='"+
(args->orderid || id->misc->ivend->orderid || id->misc->ivend->SESSIONID)
+
  "'");
if(sizeof(r)>0) return sprintf("%.2f", (float)(r[0]->value));
else  return "0.00";

}

float|string tag_shippingcalc (string tag_name, mapping args,
                    object id, mapping defines) {  

string retval="";
float charge=0.00;

string type= (args->type || id->variables->type || "1");
string orderid=(args->orderid || id->misc->ivend->orderid ||
  id->misc->ivend->SESSIONID);

array r=DB->query("SELECT * FROM shipping_types WHERE type=" + type);
if(!r){ perror("error getting shipping type " + type + "\n"); 
 return
 -1.00; }

else charge=handlers[r[0]->module]->calculate_shippingcost(type, orderid, id); 
  
return sprintf("%.2f", ((float)(charge)));

}

string tag_shippingtype (string tag_name, mapping args,
                    object id, mapping defines) {  


string retval;
array r;
string query=("SELECT extension FROM lineitems where orderid='" +
  (id->misc->ivend->orderid || id->misc->ivend->SESSIONID)
  + "' AND lineitem='shipping'");
// perror(query);
r=DB->query(query);

if(sizeof(r)!=1) return "Error Finding Shipping Data for this order.";
else return r[0]->extension;

}

string tag_shippingadd (string tag_name, mapping args,
                    object id, mapping defines) {  
if(id->variables["_backup"] || id->misc->ivend->skip_page ||
id->misc->ivend->error_happened)
  return "<!-- skipping cardcheck because of page jump. -->";

if(id->variables->no_shipping_options)
return "<!-- No shipping options were available. -->";
int type= (args->type || id->variables->type || 0); 

if(! type)
  return "Error.";

mixed total, charge;
string retval;

if(id->variables["_backup"])
   return "<!--Backing up. CalculateShipping skipped.-->\n";
string orderid=(args->orderid || id->misc->ivend->orderid ||
id->misc->ivend->SESSIONID);
if(!args->charge){
array r=DB->query("SELECT * FROM shipping_types WHERE type=" + type);
if(!r){ perror("error getting shipping type " + type + "\n"); return ""; }
else charge=handlers[r[0]->module]->calculate_shippingcost(type, orderid, 
id); 
if(charge==-1.0)
  return "Error.";
}
else charge=args->charge;
string typename=id->misc->ivend->db->query("SELECT name FROM shipping_types "
  "WHERE type=" + id->variables->type )[0]->name;
if((float)(charge)==-2.00) {
  charge=0.00; 
  typename+=" (" + ACTUAL_CHARGES + ")";
  }
id->misc->ivend->db->query("DELETE FROM lineitems WHERE orderid='"
	+ id->misc->ivend->SESSIONID + "' AND lineitem='shipping'");
id->misc->ivend->db->query("INSERT INTO lineitems VALUES('" +
  id->misc->ivend->SESSIONID + "', 'shipping', " + charge + ",'" +
  typename + "','" + T_O->is_lineitem_taxable(id, "shipping", "") + "')");

return "";

}

string tag_shippingtypes (string tag_name, mapping args,
                    object id, mapping defines) {  


string retval="";
array r;
catch(
r=id->misc->ivend->db->query("SELECT * from shipping_types order by type"));
int t=0;
int g=0;
array rw=({});
foreach(r, mapping row){
  if(search(lower_case(row->availability), "select")!=-1){
    row->availability=replace(row->availability, "#sessionid#",
	id->misc->ivend->SESSIONID);
    array m=id->misc->ivend->db->query(row->availability);
    if(sizeof(m)>0) rw+=({row});
  }
  else rw+=({row});
}

if(!rw || sizeof(rw)==0)
  return "No shipping options are currently available.<input type=hidden name=no_shipping_options value=1>";

foreach(rw, mapping row){
args->type=row->type;
string price=tag_shippingcalc ("shippingcalc", args,
                    id, defines);
                     
if((float)price!=-1.00){                           
if((float)price==-2.00){
  retval+="<dt><input type=radio name=type " + ((t==0)?("CHECKED"):(""))
      +" value=\"" + row->type + "\"> <b>" + row->name + 
      ": " + ACTUAL_CHARGES + " </b><dd>" + row->description;
  }
  else
    retval+="<dt><input type=radio name=type " +((t==0)?("CHECKED"):("")) 
      +" value=\"" + row->type + "\"> <b>"+ row->name + 
      ": $ " + price +
      "</b><dd>" + row->description;
  g=1;
}
  t=1;
}
if(g==1)
  return retval;
else return "We were unable to find a suitable shipping option for your order. "
	"We may not be able to deliver your order if you continue. "
	"Please go back and double check your address(es), and try again. "
	;
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
  "shippingcalc"    : tag_shippingcalc
  ]);

}
