#!NOMODULE

constant module_name = "UPS Zone Shipping";
constant module_type = "shipping";

mapping query_tag_callers2();
mapping query_container_callers2();    

object u;	// The ups zone machine.

int initialized;

void start(mapping config){


initialized=0;

object db;

if(catch(db=iVend.db(config->dbhost, config->db,
  config->dblogin, config->dbpassword)))
    perror("iVend: UPSShipping: Error Connecting to Database.\n");

if((sizeof(db->list_tables("shipping_types")))==1)
  initialized=1;

u=Commerce.UPS.zone();

return;

}

void stop(mapping config){

return;

}

int initialize_db(object id) {

  perror("initializing order total shipping module!\n");
catch(id->misc->ivend->db->query("drop table shipping_ot"));
catch(id->misc->ivend->db->query(
  "CREATE TABLE shipping_ups ("
  " type int(11) DEFAULT '0' NOT NULL,"
  " charge float(5,2) DEFAULT '0.00' NOT NULL,"
  " chargetype char(1) DEFAULT 'C' NOT NULL,"
  " zonefile char(12) NOT NULL, "
  " id int NOT NULL AUTO_INCREMENT PRIMARY KEY"
  " ) "));
rm(id->misc->ivend->config->root + "/db/shipping_ups_chargetype.val");
catch(Stdio.write_file(id->misc->ivend->config->root +
  "/db/shipping_ups_chargetype.val","Cash\nPercentage\n")); 
if(sizeof(id->misc->ivend->db->list_tables("shipping_types"))!=1)
  catch(id->misc->ivend->db->query("CREATE TABLE shipping_types ("
  "  type int(11) DEFAULT '0' NOT NULL auto_increment,"
  "  name varchar(32) DEFAULT '' NOT NULL,"
  "  description blob,"
  "  PRIMARY KEY (type)"
  ") "));
return 0;

}

string addtype(object id){

  string retval="<table>\n"+
  id->misc->ivend->db->gentable("shipping_types","shipping",0,id);
  return retval;

}


string addrange(string type, object id){

  string retval="<form action="+id->not_query +"><tr></tr>\n"+
    "<tr><td><font face=helvetica><b>From $</b></font></td>\n"
    "<td><font face=helvetica><b>To $</b></font></td>\n"
    "<td><font face=helvetica><b>Charge</b></font></td></tr>\n"
    "<tr><td><input type=text size=10 name=min></td>\n"
    "<td><input type=text size=10 name=max></td>\n"
    "<td><input type=text size=10 name=charge></td>\n"
    "</tr></table><input type=hidden value="+ type+ " name=type>"
    "<input type=hidden name=doaddrange value=1>"
    "<input type=submit value=Add>";

  foreach(({"viewtype","showall"}), string var)
    retval+="<input type=hidden name=" + var + " value=" + 
	  id->variables[var] + ">\n";

  retval+="</form>";

  return retval;

}



string show_type(string type, object id){

  string retval="";

  array r=id->misc->ivend->db->query("SELECT * FROM shipping_ot WHERE type="
                                     + type + " ORDER BY type");
  if(sizeof(r)<1)
    retval+="<ul><font size=2><b>No Rules exist for this "
      "shipping type.</b></font><table>\n";    
  else {
    retval+="<ul><table><tr><td><font face=helvetica><b>From $</td><td>"
      "<font face=helvetica><b>To $</td><td><font face=helvetica><b>"
      "Charge</td></tr>\n";
    foreach(r, mapping row) {
      retval+="<tr><td>" + row->min + "</td><td>"+ row->max + "</td><td>"
	+ row->charge + " <font size=2 face=helvetica>(<a href=" +
	id->not_query+"?";
      foreach(({"showall", "viewtype"}), string var)
	retval+=var+"="+id->variables[var]+"&";
      retval+="&id=" +row->id + "&dodelete=1>Delete</a>)</font></td></tr>";
    }


  }
  retval+=addrange(type, id) + "</ul>";

  return retval;

}


mixed shipping_admin(object id){
string retval="";     

if(initialized==0 && id->variables->initialize) {
  initialize_db(id);
  start(id->misc->ivend->config);
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

  if(id->variables->doaddrange) {

    mixed j=id->misc->ivend->db->query("INSERT INTO shipping_ot "
				       "values(" + id->variables->type+
				       ","+id->variables->charge + "," +
				       id->variables->min + "," +
				       id->variables->max +",NULL)");

    retval+="<br>Shipping Range Added Successfully.<br>\n";
    }

  if(id->variables->dodelete) {

    mixed j=id->misc->ivend->db->query("DELETE FROM shipping_ot "
				       "WHERE id=" + id->variables->id);

    retval+="<br>Shipping Range Deleted Successfully.<br>\n";
    }

 if(id->variables->dodeletetype) {

    mixed j=id->misc->ivend->db->query("DELETE FROM shipping_types "
                                       "WHERE type=" + 
				       id->variables->dodeletetype);

    mixed j=id->misc->ivend->db->query("DELETE FROM shipping_ot "
                                       "WHERE type=" + 
				       id->variables->dodeletetype);
    retval+="<br>Shipping Type Deleted Successfully.<br>\n";
    }  


  if(id->variables->addtype)
    retval+=addtype(id);
  else {
    retval+="<ul>\n<li>Shipping Types <font size=2>(<a href=shipping"
      + (id->variables->showall=="1" ?">Collapse All":"?showall=1>Expand All") + 
      "</a>)</font>\n<ul>";

    array r=id->misc->ivend->db->query("SELECT * FROM shipping_types");
    foreach(r, mapping row) {
      retval+="<li><a href=shipping?viewtype="+row->type+ ">" + row->name
        +"</a>\n<font size=2>( <a href="+id->not_query+"?dodeletetype="+
	row->type +">Delete"+"</a> )"
        "<dd>"+ row->description+"</font>\n\n";
      if (row->type==id->variables->viewtype || id->variables->showall=="1")
	retval+=show_type(row->type, id);

    }
    retval+="</ul><font size=2><a href=shipping?addtype=1>"
      "Add New Type</font></a>\n</ul>\n";
    }
  }

return "Method: Shipping Cost Based on Order Total\n<br>" + retval;

}

float|string tag_shipping(float amt, mixed type, object id){

if(!initialized) return "Uninitialized shipping module.";

array r=id->misc->ivend->db->query("SELECT value FROM lineitems WHERE "
  "lineitem='shipping' AND orderid='"+ id->misc->ivend->SESSIONID +
  "'");
if(sizeof(r)>0) return r[0]->value;
else  return "";

}

float|string calculate_shippingcost(float amt, mixed type, object id){

if(!initialized) return "Uninitialized shipping module.";

array r;

perror("type: " + type + " amt: " + sprintf("%.2f", amt)+"\n");

r=id->misc->ivend->db->query("SELECT charge FROM shipping_ot WHERE type=" +
  (string)type +  " AND min <= " + 
  sprintf("%.2f",amt) + " AND max >= " +
  sprintf("%.2f",amt) );

if(sizeof(r)!=1) {
  perror("ERROR GETTING SHIPPINGCOST!\n");
  return -1.00;
  }
else return (float)(r[0]->charge);

}

float calculate_shippingtotal(object id){

float subtotal=0.00;
array r;



r=id->misc->ivend->db->query("SELECT "
  "SUM(products.price*sessions.quantity) as "
  "shippingtotal FROM sessions,products WHERE sessions.sessionid='" +
  id->misc->ivend->SESSIONID + "' AND products.id=sessions.id");

if (sizeof(r)!=1) {
  perror( "Unable to calculate Order Subtotal.");
  return -1.00;
  }

return (float)(r[0]->shippingtotal);

}

string tag_calculateshippingcost (string tag_name, mapping args,
                    object id, mapping defines) {  

string retval="";
float shipping=0.00;

if(!initialized) return "Uninitialized shipping module.";

if(!args->type) args->type="1";

mixed amt=calculate_shippingtotal(id);

if(!floatp(amt)) return amt;

else shipping=calculate_shippingcost(amt, args->type, id);

return retval;

}

string tag_showshippingcost (string tag_name, mapping args,
                    object id, mapping defines) {  
mixed total, charge;
string retval;

if(!initialized) return "Uninitialized shipping module.";

total=calculate_shippingtotal(id);

charge=calculate_shippingcost(total, args->type, id);
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

if(!id->variables->type) return "Error: You can't use the addshipping tag outside of checkout!\n";

mixed total, charge;
string retval;

total=calculate_shippingtotal(id);

charge=calculate_shippingcost(total, id->variables->type, id);
string typename=id->misc->ivend->db->query("SELECT name FROM shipping_types "
  "WHERE type=" + id->variables->type )[0]->name;
if(id->variables["_backup"])
   return "<!--Backing up. CalculateShipping skipped.-->\n";
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

foreach(r, mapping row)
retval+="<dt><input type=radio name=type value="
  + row->type + "> <b>"+ row->name +": $<shippingcost type=" + row->type + 
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
