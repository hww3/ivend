#!NOMODULE

constant module_name = "No Shipping Charges";
constant module_type = "shipping";

mapping query_tag_callers2();
mapping query_container_callers2();    

int initialized;

void start(object mo, object db){


initialized=1;

}

void stop(object mo, object db){

return;

}



mixed shipping_admin(object id){
string retval="";     

retval="There are no configurable options for this module.";
return "Method: No Shipping Charges Calculated\n<p>" + retval;

}

float|string tag_shipping(float amt, mixed type, object id){

if(!initialized) return "Uninitialized shipping module.";

else  return "0.00";

}

float|string calculate_shippingcost(mixed type, mixed orderid, object id){

if(!initialized) return "Uninitialized shipping module.";

else return (0.00);

}


string tag_calculateshippingcost (string tag_name, mapping args,
                    object id, mapping defines) {  

return "0.00";

}

string tag_showshippingcost (string tag_name, mapping args,
                    object id, mapping defines) {  

return sprintf("%.2f", 0.00);

}

string tag_showshippingtype (string tag_name, mapping args,
                    object id, mapping defines) {  

return "No Shipping Charge";

}

string tag_addshipping (string tag_name, mapping args,
                    object id, mapping defines) {  


return "";

}

string tag_showalltypes (string tag_name, mapping args,
                    object id, mapping defines) {  

return "";

}

string tag_showshippingtypes (string tag_name, mapping args,
                    object id, mapping defines) {  

return "";

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
