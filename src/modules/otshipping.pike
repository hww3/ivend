constant module_name = "Order Total Shipping";
constant module_type = "shipping";

mapping query_tag_callers2();
mapping query_container_callers2();    

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
