#!NOMODULE


#include <ivend.h>
#include <messages.h>

inherit "roxenlib";

constant module_name = "Payment";
constant module_type = "payment";

mapping handlers=([]);

mapping query_tag_callers2();
mapping query_container_callers2();    

int initialized;

object|void load_module(string module, mapping config)
{
perror("STARTING PAYMENT HANDLER...");
object m;

string moddir=config->global->general->root + "/src/modules/payment";
 // perror("loading shipping module "  + module + "\n");
mixed x;
mixed xerr;
master()->set_inhibit_compile_errors(0);
xerr=catch(x=compile_file(moddir+"/"+module));
if(xerr) perror(describe_backtrace(xerr));
master()->set_inhibit_compile_errors(1);
if(x)
 m=(object)clone(x);
if(m && objectp(m)) {
  m->start(config);
  perror("DONE\n");
//  perror(sprintf("%O\n", mkmapping(indices(m), values(m))));
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


db=iVend.db(config->general->dbhost);

if((sizeof(db->list_tables("payment_types")))==1)
{  initialized=1;

}

else {initialized=0;  perror("module not initialized.\n"); return; }

perror("module inititalized.\n");

array r=db->query("select * from payment_types");

foreach(r, mapping row){
	// load modules
  if(objectp(handlers[row->module])) // already loaded that one.
    {
    if(!handlers[row->module]->started)
       handlers[row->module]->start(config);
    }
  else handlers[row->module]=load_module(row->module, config);
  }
perror("done in start()\n");
return;

}

void stop(mapping config)
{

return;

}

mapping available_modules(mapping config)
{
object m;


string moddir=config->global->general->root + "/src/modules/payment";
mapping am=([]);

foreach(get_dir(moddir), string name){
  m=0;
  catch(m=(object)clone(compile_file( moddir + "/" + name)));
  
  if(m && objectp(m)) {
  string desc=m->module_name;
  string type=m->module_type;
  if(type=="payment")
    am[name] = desc;
  }

  else perror("iVend: the module " + name + " did not load properly.\n");
  }

return am;
}

int initialize_db(object id)
{

  perror("initializing payment module tables!\n");

if(sizeof(DB->list_tables("payment_types"))!=1)
  DB->query("CREATE TABLE payment_types ("
  "  type int(11) DEFAULT '0' NOT NULL auto_increment,"
  "  name varchar(32) DEFAULT '' NOT NULL,"
  "  description blob,"
  "  module varchar(32),"
  "  availability blob,"
  "  PRIMARY KEY (type)"
  ") ");

start(id->misc->ivend->config);
return 0;

}

string showmainmenu(object id)
{
string retval="";
retval+="<b>Configured Payment Types</b><p>";

catch(array r=DB->query("SELECT * FROM payment_types ORDER BY type"));
if(!r || sizeof(r)==0)
    retval+="No Payment Types Configured.";
else {
  retval+="<table>\n"
	"<tr><th>Name</th><th>Description</th><th>Avail. Query</th>"
	"<th></th></tr>\n";
    foreach(r, mapping row)
      retval+= "<tr><td><A HREF=\"./?mode=showtype&showtype=" + row->type
	+ "\">" +row->name + "</a></td><td><autoformat>" +
row->description + 
	"</autoformat></td><td>" + row->availability + 
"</td><td> ( <A HREF=\"./?mode=deletetype&deletetype=" + row->type + 
	"\">Delete</a> )</td></tr>\n";
retval+="</table>\n";
  }
retval+="<p><a href=\"./?mode=addtypemenu\">Add Payment Type</a>";

return retval;
}

string addtypemenu(object id)
{
  string retval="<form action=\"./\">\n"
    "Payment Type Name: <input type=text size=40 name=name><br>\n"
    "Payment method: <select name=module>\n";
  mapping am=available_modules(id->misc->ivend->config);
  foreach(indices(am),string method)
    retval+="<option value=\"" +method + "\">" + am[method] + "\n";
  retval+="</select><br>\nDescription:" 
    "<textarea name=\"description\" cols=60 rows=6></textarea><br>"
	"\nAvailability:"
    "<textarea name=\"availability\" cols=60 rows=6></textarea><br>"
    "<input type=hidden name=mode value=doaddtype>\n"
    "<input type=submit name=doaddtype value=AddShippingType>\n</form>"
    "<b>Shipping Type</b>: This is the name of the payment type that "
    "will be displayed as an option to the user.<p>"
    "<b>Payment Method</b>: This is the method of payment to use. "
    "<b>Description</b>: A short discription describing the payment "
    "method. This information is displayed to the user when choosing "
    "a payment method.<p>"
    "<b>Availability Query</b>: The Availability Query allows you to "
    "control when a payment type is made available for selection. "
    "The query is a SQL statement that returns zero or more rows "
    "based upon the current Session ID and other criteria such as "
    "shipping or billing addresses. The Session ID is inserted into "
    "the query using <i>#sessionid#</i>. If the query returns one or "
    "more rows, the method will be made available. Otherwise, "
    "the method will not be displayed as an option. If no query is "
    provided, this method will always be available.";

  return retval;
}

mixed showtype(object id, mapping row)
{

string retval="";

if(!objectp(handlers[row->module]))
  return "This payment handler has not been loaded.";
else retval+=handlers[row->module]->showtype(id, row);

return retval;

}

mixed deletetype(object id)
{
string retval="";

if(!id->variables->deletetype)
return "you must select a type to delete.";

else {
  array r=DB->query("SELECT * FROM payment_types WHERE type=" +
    id->variables->deletetype);
  if(handlers[r[0]->module]->deletetype)
    retval+=handlers[r[0]->module]->deletetype(id);
  DB->query("DELETE FROM payment_types WHERE type=" +
    id->variables->deletetype);
  }

retval+="<p><A href=\"./\">Click here to continue</a>.";

return retval;
}
mixed doaddtype(object id)
{

  DB->query("INSERT INTO payment_types VALUES(NULL,'" +
	DB->quote(id->variables->name) + "','" +
	DB->quote(id->variables->description) + "','" +
	id->variables->module + "','" +
	DB->quote(id->variables->availability) + "')");
  
  start(id->misc->ivend->config);

  return showmainmenu(id);
}

mixed payment_admin (string p, object id)
{ 

if(id->variables->initialize)
  initialize_db(id);

string retval=
	"<h2>Payment Administration</h2>\n";

if(!initialized) {
  retval+="This module has not been initialized."
	"<p>Click <a _parsed=1 href=./?initialize=1>here</a> to do this now.";
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
     	 array r=DB->query("SELECT * FROM payment_types WHERE type=" +
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
	([ "mode": "menu.main.Store_Administration.Payment_Administration",
		"handler": payment_admin,
		"security_level": 8 ])
	});

}
/*
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

charge+=calculate_handlingcharge(type, orderid, id);
  
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
charge+=calculate_handlingcharge((string)type, (string)orderid, id);

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


void event_calculateHandlingCharge(string event, object id, mapping args)
{
  float charge=0.00;

  if(DB->local_settings->handling_charge==PER_ITEM) {
	array r=DB->query("SELECT sum(products.handling_charge*sessions.quantity) as hc "
	  "from products,sessions where sessions.sessionid='" 
	  + args->orderid + "' and products." +
	id->misc->ivend->db->keys->products + "=sessions.id");

        if(r && sizeof(r)==1) charge=(float)(r[0]->hc);
   }

  id->misc->ivend->handling_charge=charge;
perror("Handling Charge: " + charge + "\n");
  return;
}

string tag_shippingtypes (string tag_name, mapping args,
                    object id, mapping defines) {  

perror("tag_shippingtypes\n");
string retval="";
array r;
catch(
r=id->misc->ivend->db->query("SELECT * from shipping_types order by type"));
int t=0;
int g=0;
array rw=({});
foreach(r, mapping row){
perror("got a type.\n");
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
perror("checking cost.\n");
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

*/

mapping query_container_callers(){

  return ([]);

}

mapping query_tag_callers(){

return

 ([
  ]);

}

mixed query_event_callers(){

  return ([ ]);

} 
