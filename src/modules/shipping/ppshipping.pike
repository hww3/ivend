#!NOMODULE

#include "../../include/messages.h"

constant module_name = "Per Product Shipping";
constant module_type = "shipping";

int started;

int initialize_db(object db) {

  perror("initializing Per Product Shipping module!\n");
catch(db->query("drop table shipping_pp"));
catch(db->query(
  "CREATE TABLE shipping_pp ("
  " type int(11) DEFAULT '0' NOT NULL,"
  " fieldname char(16) NOT NULL, "
  " id int NOT NULL AUTO_INCREMENT PRIMARY KEY"
  " ) "));

return 0;

}

void start(mapping config){

object db;

if(catch(db=iVend.db(config->general->dbhost, config->general->db,
  config->general->dblogin, config->general->dbpassword))) {
    perror("iVend: PerProductShipping: Error Connecting to Database.\n");
    return;
    }

if(sizeof(db->list_tables("shipping_pp"))==1);
else initialize_db(db);
  started=1;
return;

}

void stop(mapping config){

return;

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

string addlookup(object id, mixed type){

  string retval="<form action=" + id->not_query + ">"
    "<select name=fieldname>";

  array f=id->misc->ivend->db->list_fields("products");
  foreach(f, mapping field)
    if(field->type=="float" || field->type=="decimal")
      retval+="<option>" + field->name + "\n";
  retval+="</select>\n<input type=hidden name=doaddlookup value="+
	id->variables->addlookup + ">"
	"<input type=hidden name=mode value=showtype>" 
	"<input type=hidden name=showtype value=" + type + ">" 
	"<input type=submit value=AddLookupField></form>";

return retval;

}

string addtype(object id, mixed type) {
    string retval="";
    mixed j=id->misc->ivend->db->addentry(id,id->referrer);
    retval+="<br>";
    if(stringp(j))
      return retval+= "The following errors occurred:<p>" + j;

    string type=(id->variables->table/"_"*" ");
    retval+=type+" Added Successfully.<br>\n";
    return retval;
    }


string deletetype(object id, mixed type) {

    mixed j=id->misc->ivend->db->query("DELETE FROM shipping_pp "
                                       "WHERE type=" + 
				       type);
    return "<br>Shipping Type Deleted Successfully.<br>\n";
    }  


mixed showtype(object id, mapping row){
  string retval="";
string retval="<tr><td><b>Method:</b></td><td>Charge based on "
  "product table lookup field.</td></tr></table>\n";  

  if(id->variables->addlookup)
    retval+=addlookup(id, row->type);
  else if(id->variables->doaddlookup)
    retval+=doaddlookup(id, row->type);
  else if(id->variables->addtype) 
    retval+=addtype(id, row->type); 
  else if(id->variables->deletetype) 
    deletetype(id, row->type); 

      array r=id->misc->ivend->db->query("SELECT fieldname FROM "
	"shipping_pp WHERE type=" + row->type );
      if(sizeof(r)==0)
        retval+="No Lookup Field Specified. ( <a href=" + id->not_query +
		"?mode=showtype&showtype=" + row->type + "&addlookup=" +
		row->type + ">Add Lookup Field</a> )\n";
      if(sizeof(r)>0)
        retval+="<p><b>Lookup Field:</b> " + r[0]->fieldname + "\n"
	"( <a href=" + id->not_query + "?mode=showtype&showtype=" +
	row->type + "&deletetype=" + row->type + ">Delete Lookup Field</a> )";
	
return retval;
}

float|string calculate_shippingcost(mixed type, object id){

array r;

r=id->misc->ivend->db->query("SELECT fieldname FROM shipping_pp WHERE "
	"type=" + type);

if(sizeof(r)<1) return -1.00;
string query="SELECT SUM(sessions.quantity*products." +
	r[0]->fieldname + ") AS shipping FROM "
	" products,sessions WHERE sessionid='" +
	id->misc->ivend->SESSIONID + "' and products." +
	id->misc->ivend->keys->products + "=sessions.id";

// perror(query);
r=id->misc->ivend->db->query(query);

if(sizeof(r)!=1) {
  perror("ERROR GETTING SHIPPINGCOST!\n");
  return -1.00;
  }
else return (float)(r[0]->shipping);

}
