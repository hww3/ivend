constant module_name = "Order Total Shipping";
constant module_type = "shipping";

mapping query_tag_callers2();
mapping query_container_callers2();    

int initialized;

void start(mapping config){

initialized=0;

object db=iVend.db(config->dbhost, config->db,
  config->dbuser, config->bpassword);

if((sizeof(db->list_tables("shipping_types")))==1 && 
  (sizeof(db->list_tables("shipping_ot")))==1)
  initialized=1;
return;

}

void stop(mapping config){

return;

}

int initialize_db(object id) {

  perror("initializing order total shipping module!\n");
catch(id->misc->ivend->db->query("drop table shipping_ot"));
catch(id->misc->ivend->db->query(
  "CREATE TABLE shipping_ot ("
  " type int(11) DEFAULT '0' NOT NULL,"
  " charge float(5,2) DEFAULT '0.00' NOT NULL,"
  " min float(5,2) DEFAULT '0.00' NOT NULL, "
  " max float(5,2) DEFAULT '0.00'"
  " NOT NULL ) "));

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

mixed shipping_admin(object id){
string retval="";
if(!initialized && id->variables->initialize) {
  initialize_db(id);
  start(id->misc->ivend->config);
  }
if(!initialized)
  retval+="This module has not been initialized yet.<br>"
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

  if(id->variables->addtype)
    retval+=addtype(id);
  else {
    retval+="<ul>\n<li>Shipping Types\n<ul>";

    array r=id->misc->ivend->db->query("SELECT * FROM shipping_types");
    foreach(r, mapping row)
      retval+="<li><a href=shipping?viewtype="+row->type+ ">" + row->name
        +"</a>\n<font size=2>"
        "<dd>"+ row->description+"</font>\n\n";
    retval+="</ul><font size=2><a href=shipping?addtype=1>"
      "Add New Type</font></a>\n</ul>\n";
    }
  }

return "Method: Shipping Cost Based on Order Total\n<br>" + retval;

}

float|string tag_shipping(float amt, mixed type, object id){

return id->misc->ivend->s->query("SELECT value FROM lineitems WHERE "
  "lineitem='shipping' AND orderid='"+ id->misc->ivend->SESSIONID +
  "'")[0]->value;

}

float|string calculate_shippingcost(float amt, mixed type, object id){

array r;

perror("type: " + type + " amt: " + sprintf("%.2f", amt)+"\n");

r=id->misc->ivend->s->query("SELECT charge FROM shipping_ot WHERE type=" +
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

r=id->misc->ivend->s->query("SELECT "
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

total=calculate_shippingtotal(id);

charge=calculate_shippingcost(total, args->type, id);
return sprintf("%.2f", charge);

}

string tag_showshippingtype (string tag_name, mapping args,
                    object id, mapping defines) {  

string retval;
array r;
string query=("SELECT extension FROM lineitems where orderid='" +
  id->misc->ivend->SESSIONID + "' AND lineitem='shipping'");
perror(query);
r=id->misc->ivend->s->query(query);

if(sizeof(r)!=1) return "Error Finding Shipping Data.";
else return r[0]->extension;

}

string tag_addshipping (string tag_name, mapping args,
                    object id, mapping defines) {  

if(!id->variables->type) return "Error: You can't use the addshipping tag outside of checkout!\n";

mixed total, charge;
string retval;

total=calculate_shippingtotal(id);

charge=calculate_shippingcost(total, id->variables->type, id);
string typename=id->misc->ivend->s->query("SELECT name FROM shipping_types "
  "WHERE type=" + id->variables->type )[0]->name;

id->misc->ivend->s->query("INSERT INTO lineitems VALUES('" +
  id->misc->ivend->SESSIONID + "', 'shipping', " + charge + ",'" +
  typename + "')");

return "";

}

string tag_showalltypes (string tag_name, mapping args,
                    object id, mapping defines) {  

string retval="";
array r;
r=id->misc->ivend->s->query("SELECT * from shipping_types");

foreach(r, mapping row)
retval+="<dt><input type=radio name=type value="
  + row->type + "> <b>"+ row->name +": $<shippingcost type=" + row->type + 
  " convert></b><dd>" + row->description;


return retval;
}

string tag_showshippingtypes (string tag_name, mapping args,
                    object id, mapping defines) {  

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
