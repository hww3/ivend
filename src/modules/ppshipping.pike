#!NOMODULE

#include "../include/messages.h"

constant module_name = "Per Product Shipping";
constant module_type = "shipping";

mapping query_tag_callers2();
mapping query_container_callers2();    

int initialized;

void start(mapping config){


initialized=0;

object db;

if(catch(db=iVend.db(config->dbhost, config->db,
  config->dblogin, config->dbpassword))) {
    perror("iVend: PerProductShipping: Error Connecting to Database.\n");
    return;
    }

if(sizeof(db->list_tables("shipping_types"))==1
    && sizeof(db->list_tables("shipping_pp"))==1)
  initialized=1;

return;

}

void stop(mapping config){

return;

}

int initialize_db(object id) {

  perror("initializing Per Product Shipping module!\n");
catch(id->misc->ivend->db->query("drop table shipping_pp"));
catch(id->misc->ivend->db->query(
  "CREATE TABLE shipping_pp ("
  " type int(11) DEFAULT '0' NOT NULL,"
  " fieldname char(16) NOT NULL, "
  " id int NOT NULL AUTO_INCREMENT PRIMARY KEY"
  " ) "));
if(sizeof(id->misc->ivend->db->list_tables("shipping_types"))!=1)
  catch(id->misc->ivend->db->query("CREATE TABLE shipping_types ("
  "  type int(11) DEFAULT '0' NOT NULL auto_increment,"
  "  name varchar(32) DEFAULT '' NOT NULL,"
  "  description blob,"
  "  PRIMARY KEY (type)"
  ") "));
return 0;

}

string doaddlookup(object id){

string retval="";

if(!(id->variables->fieldname && id->variables->doaddlookup))
  return "You must properly add a lookup field.";

else {
  id->misc->ivend->db->query("DELETE FROM shipping_pp WHERE type=" +
    id->variables->doaddlookup);
  id->misc->ivend->db->query("INSERT INTO shipping_pp VALUES(" +
    id->variables->doaddlookup + ",'" + id->variables->fieldname + "',NULL)"); 
  retval="Lookup Field added Successfully.";
  return retval;
  }
}

string addlookup(object id){

  string retval="<form action=" + id->not_query + ">"
    "<select name=fieldname>";

  array f=id->misc->ivend->db->list_fields("products");
  foreach(f, mapping field)
    if(field->type=="float" || field->type=="decimal")
      retval+="<option>" + field->name + "\n";
  retval+="</select>\n<input type=hidden name=doaddlookup value="+
	id->variables->addlookup + ">"
	"<input type=submit value=AddLookupField></form>";

return retval;

}

string addtype(object id){

  string retval="<table>" +
  id->misc->ivend->db->gentable("shipping_types","shipping",0,id);
  return retval;

}


mixed shipping_admin(object id){
string retval="";     

if(initialized==0 && id->variables->initialize) {
  initialize_db(id);
  start(id->misc->ivend->config->general);
  }
if(initialized==0)
  return "This module has not been initialized yet.<br>"
    "Click <a href=shipping?initialize=goodtogo>Here</a> to do this.<p>\n";
else {

  if(id->variables->mode=="doadd") {

    mixed j=id->misc->ivend->db->addentry(id,id->referrer);
    retval+="<br>";
    if(stringp(j))
      return retval+= "The following errors occurred:<p>" + j;

    string type=(id->variables->table/"_"*" ");
    retval+=type+" Added Successfully.<br>\n";
    }


 if(id->variables->dodeletetype) {

    mixed j=id->misc->ivend->db->query("DELETE FROM shipping_types "
                                       "WHERE type=" + 
				       id->variables->dodeletetype);

    mixed j=id->misc->ivend->db->query("DELETE FROM shipping_pp "
                                       "WHERE type=" + 
				       id->variables->dodeletetype);
    retval+="<br>Shipping Type Deleted Successfully.<br>\n";
    }  


  if(id->variables->addlookup)
    retval+=addlookup(id);
  else if(id->variables->doaddlookup)
    retval+=doaddlookup(id);
  else if(id->variables->addtype)
    retval+=addtype(id);
  else {
    retval+="<ul>\n<li>Shipping Types\n<ul>";

    array r=id->misc->ivend->db->query("SELECT * FROM shipping_types");
    foreach(r, mapping row) {
      retval+="<li>" + row->name + "<font size=-1> (<a href="+
	id->not_query +"?dodeletetype=" + row->type +">Delete Type</a> )\n";
      array r=id->misc->ivend->db->query("SELECT fieldname FROM "
	"shipping_pp WHERE type=" + row->type );
      if(sizeof(r)==0)
        retval+="( <a href=" + id->not_query + "?addlookup=" + row->type + 
		">Add Lookup Field</a> )\n";
        retval+="</font>\n<dd>"+ row->description+"</font>\n\n";
      if(sizeof(r)>0)
        retval+="<p><b>Lookup Field:</b> " + r[0]->fieldname + "\n";

    }
    retval+="</ul><font size=2><a href=shipping?addtype=1>"
      "Add New Type</font></a>\n</ul>\n";
    }
  }

return "Method: Shipping Cost based on product.\n<br>" + retval;

}

float|string tag_shipping(string tag_name, mapping args,
                    object id, mapping defines){

if(!initialized) return "Uninitialized shipping module.";
if(sizeof(id->misc->ivend->error)>0)
  return "";
array r=id->misc->ivend->db->query("SELECT value FROM lineitems WHERE "
  "lineitem='shipping' AND orderid='"+ id->misc->ivend->SESSIONID +
  "'");
if(sizeof(r)>0) return r[0]->value;
else  return "";

}

float|string calculate_shippingcost(mixed type, object id){

if(!initialized) return "Uninitialized shipping module.";

array r;

r=id->misc->ivend->db->query("SELECT fieldname FROM shipping_pp WHERE "
	"type=" + type);

if(sizeof(r)<1) return -1.00;
string query="SELECT SUM(sessions.quantity*products." +
	r[0]->fieldname + ") AS shipping FROM "
	" products,sessions WHERE sessionid='" +
	id->misc->ivend->SESSIONID + "' and products." +
	id->misc->ivend->keys->products + "=sessions.id";

perror(query);
r=id->misc->ivend->db->query(query);

if(sizeof(r)!=1) {
  perror("ERROR GETTING SHIPPINGCOST!\n");
  return -1.00;
  }
else return (float)(r[0]->shipping);

}

string tag_calculateshippingcost (string tag_name, mapping args,
                    object id, mapping defines) {  

string retval="";
float shipping=0.00;

if(!initialized) return "Uninitialized shipping module.";

if(!args->type) args->type="1";

shipping=calculate_shippingcost(args->type, id);

return retval;

}

string tag_showshippingcost (string tag_name, mapping args,
                    object id, mapping defines) {  
mixed total, charge;
string retval;

if(!initialized) return "Uninitialized shipping module.";

charge=calculate_shippingcost(args->type, id);
return sprintf("%.2f", charge);

}

string tag_showshippingtype (string tag_name, mapping args,
                    object id, mapping defines) {  

if(!initialized) return "Uninitialized shipping module.";

string retval;
array r;
string query=("SELECT extension FROM lineitems where orderid='" +
  id->misc->ivend->SESSIONID + "' AND lineitem='shipping'");
perror(query);
r=id->misc->ivend->db->query(query);

if(sizeof(r)!=1) return "Error Finding Shipping Data.";
else return r[0]->extension;

}

string tag_addshipping (string tag_name, mapping args,
                    object id, mapping defines) {  

if(!initialized) return "Uninitialized shipping module.";

if(!id->variables->type) {
  id->misc->ivend->error+=({MUST_SELECT_SHIPPING_TYPE});
  return "ERROR";
  }
mixed total, charge;
string retval;


charge=calculate_shippingcost(id->variables->type, id);
string typename=id->misc->ivend->db->query("SELECT name FROM shipping_types "
  "WHERE type=" + id->variables->type )[0]->name;
if(id->variables["_backup"])
   return "<!--Backing up. CalculateShipping skipped.-->\n";
id->misc->ivend->db->query("DELETE FROM lineitems WHERE "
	"orderid='" + id->misc->ivend->SESSIONID + "' AND "
	"lineitem='shipping'");
id->misc->ivend->db->query("INSERT INTO lineitems VALUES('" +
  id->misc->ivend->SESSIONID + "', 'shipping', " + charge + ",'" +
  typename + "')");

return "";

}

string tag_showalltypes (string tag_name, mapping args,
                    object id, mapping defines) {  

if(!initialized) return "Uninitialized shipping module.";

string retval="";
array r;
r=id->misc->ivend->db->query("SELECT * from shipping_types");

int t=0;
foreach(r, mapping row)
retval+="<dt><input type=radio name=type " + ((t==0)?"CHECKED":("",t=1))
  +" value=\"" + row->type + "\"> <b>"+ row->name +
  ": $<shippingcost type=" + row->type +
  " convert></b><dd>" + row->description;      

return retval;
}

string tag_showshippingtypes (string tag_name, mapping args,
                    object id, mapping defines) {  

if(!initialized) return "Uninitialized shipping module.";
string retval;


return retval;

}

mapping query_container_callers(){

  return ([]);

}

mapping query_tag_callers(){

return

 ([
  "shippingtype" : tag_showshippingtype,
  "shippingcost" : tag_showshippingcost,
  "allshippingtypes" : tag_showalltypes,
  "addshipping" : tag_addshipping,
  "shipping"    : tag_shipping
  ]);

}
