//
//  complex_pricing.pike
//  This file is part of the iVend eCommerce system.
//  Copyright (c) 1999 Bill Welliver
//
#include <ivend.h> 
inherit "roxenlib";

#include <messages.h>

constant module_name = "Complex Pricing Routines";
constant module_type = "addin";

mapping complex_types=([ "Single Price": "single", 
	"Buy X Get Y": "buyxgetx"]);

void start(mapping config){
object db;
if(catch(db=iVend.db(config->general->dbhost, config->general->db,
  config->general->dblogin, config->general->dbpassword)))
  {
    perror("Complex Pricing: Error Connecting to Database.\n");
    return;
  }

if(sizeof(db->list_tables("cp_single"))<1)
  if(catch(db->query("CREATE TABLE cp_single ("
   "product_id varchar(16) not null, "
   "minimum_quantity integer not null default 1, "
   "price decimal(10,2) not null)"))) 
    perror("An error occurred while creating table cp_single.\n");

if(sizeof(db->list_tables("cp_buyxgetx"))<1)
  if(catch(db->query("CREATE TABLE cp_buyxgetx ("
   "product_id varchar(16) not null, "
   "quantity_to_qualify integer not null default 1, "
   "quantity_to_get integer not null default 1, "
   "bonus_product_id varchar(16) not null," 
   "price decimal(10,2) not null," 
   "repeat integer not null default 1, "
   "exclude_others integer default 1)")))
    perror("An error occurred while creating table cp_single.\n");
}


void stop(mapping config){

return;
}

void cpbuyxgetx(string event, object id, mapping args){
// perror("starting buyxgetx...\n");
 string item=args->item;
 int quantity=(int)args->quantity;

 array offers=DB->query("SELECT * FROM cp_buyxgetx WHERE product_id='" + 
  item + "' AND quantity_to_qualify <=" + quantity + " ORDER BY "
  "quantity_to_get DESC");

 if(!offers || sizeof(offers)<1) {
  COMPLEX_ADD_ERROR=NO_ADD;
// perror("exiting buyxgetx...\n");
  return;
 }

int offers_we_took=0;

while(quantity){ // loop through the offers until we have enough
  int accepted_an_offer=0;
  foreach(offers, mapping o){
   if(!o->times_we_accepted) o->times_we_accepted=0;
   if(accepted_an_offer) continue;
   if(((int)quantity>=(int)(o->quantity_to_qualify))
    && ((int)(o->times_we_accepted) < (int)(o->repeat))
    && !(((int)offers_we_took>1) && ((int)(o->exclude_others)==1)))
    {
      // we qualify so we're going to accept this offer.
      o->times_we_accepted++;
      accepted_an_offer=1;
      quantity-=(int)(o->quantity_to_qualify);
      int result=T_O->do_low_additem(id, o->bonus_product_id,
       o->quantity_to_get, o->price, (["autoadd":1]));
      if(!result) perror("an error occurred while adding item " + item
        +".\n");
      offers_we_took++;
    }   
   else quantity-=1;
  }
}
// perror("exiting buyxgetx...\n");
return;

}

void cpsingle(string event, object id, mapping args){

 string item=args->item;
 int quantity=args->quantity;

 array r=DB->query("SELECT * FROM cp_single WHERE product_id='" +
  item + "' AND minimum_quantity <= " + quantity +
  " ORDER BY minimum_quantity DESC");

 if(!r || sizeof(r) < 1)
   perror("Couldn't find a single price rule for " + item + "\n");
 else {
  // add the item.
  float price=(r[0]->price||0.00);
  mapping o=([]);
  if(id->variables->options){
   o=T_O->get_options(id, item);
  }
  if(o->surcharge) price+=(float)(o->surcharge);
  int result=T_O->do_low_additem(id, item, quantity, price, o);
  if(!result) {
   COMPLEX_ADD_ERROR=ADD_FAILED;
   perror("An error occurred adding item: " + item + " price: " +
    price + "\n");
   }
  }
 return;

}

mixed getprice_single(object id, string item)
{
string retval="";

array r=DB->query("SELECT * FROM cp_single WHERE product_id='" + item + "' "
 "ORDER BY minimum_quantity ASC");

if(!r || sizeof(r)<1) return "<!-- no pricing available...-->";

retval+="<table><tr>\n<td bgcolor=black><font color=white>"
"<b>Quantity</b></td>\n";

for(int i=0; i<sizeof(r); i++){
  if(i==sizeof(r)-1)
   retval+="<td align=center>" + r[i]->minimum_quantity + "+</td>\n";
  else
   retval+="<td align=center>" + r[i]->minimum_quantity + "-" +
    ((int)(r[i+1]->minimum_quantity)-1) + "</td>\n";  
}
retval+="</tr>\n<tr><td bgcolor=black><font color=white>"
 "<b>Price Each</b></td>\n";
foreach(r, mapping row){
  retval+="<td> &nbsp; " + MONETARY_UNIT + sprintf("%.2f", (float)(row->price)) +
" &nbsp; </td>\n";  
}

 retval+="</tr></table>\n";

return retval;

}

string tag_complex_pricing(string tag_name, mapping args,
                   object id, mapping defines) {
string retval="";
array r=DB->query("SELECT * FROM complex_pricing WHERE product_id='" + args->item
 + "' GROUP BY priority ASC");

if(!r || sizeof(r)<1)
  return "Sorry, No pricing information is available at this time.";

else foreach(r, mapping row){

if(!catch(this_object()["getprice_"+ row->type]) &&
functionp(this_object()["getprice_"+row->type]) )
 retval+=this_object()["getprice_" + row->type](id, args->item) + "<br>";
else retval+="<!-- Can't get pricing display for type " + row->type + ". -->\n";
 }

return retval;
}

string action_complexpricing(string mode, object id){
string retval="<html><head><title>Item Options</title></head>\n"
        "<body bgcolor=white text=navy>\n"
        "<font face=helvetica>";
mapping v=id->variables;
ADMIN_FLAGS=NO_BORDER;
retval+="Complex Pricing for " + v->id +"<p>";

if(!v->cptype){

array r=DB->query("SELECT * FROM complex_pricing WHERE product_id='"
  + v->id + "'");

  retval+="<table border=1>\n<tr><th>Rule Type</th><th>Priority</th>"
   "<th>Number of Rules</th><td></td></tr>\n";
if(!r || sizeof(r)<1) retval+="<tr><td colspan=3 align=center>No Complex "
  "Rules Defined.</td></tr>\n";

foreach(r, mapping row){

  retval+="<tr><td>" + row->type + "</td><td>" + row->priority +
    "</td><td>" + DB->query("SELECT COUNT(*) AS c FROM cp_" +
    lower_case(row->type) + " WHERE product_id='" + row->product_id
    +"'")[0]->c + "</td></tr>\n"; 

}
retval+="</table>\n";

retval+="<form action=./>Add New Rule: "
  "<input type=hidden name=addnew value=1>\n"
  "<input type=hidden name=id value=\"" + v->id + "\">\n"
  "<input type=hidden name=type value=\"" + v->type + "\">\n"
  "<select name=\"cptype\">\n"; 

foreach(sort(indices(complex_types)), string t)
  retval+="<option value=\"" + complex_types[t] + "\">" + t + "\n";

retval+="</select> <input type=submit value=\"Add\">\n"
  "</form>";
}
else { // we should be putting type handlers here.

if(v->delete){
  switch(v->cptype){
   case "single":
   DB->query("DELETE FROM cp_single WHERE product_id='" + v->id + "' AND "
    "minimum_quantity=" + v->minimum_quantity );
   if(sizeof(DB->query("SELECT * FROM cp_single WHERE product_id='" +
v->id + "'"))<1) DB->query("DELETE FROM complex_pricing WHERE product_id='" + v->id + "' AND type='" + v->cptype + "'");
   retval+="Rule Deleted.<br>\n";
   break; 
  }

}
if(v->addnew){
 if(v->addnew=="2"){
  switch(v->cptype){
   case "single":
   if(sizeof(DB->query("SELECT * FROM complex_pricing WHERE product_id='"
+ v->id + "' AND type='" + v->cptype + "'"))<1)
   DB->query("INSERT INTO complex_pricing VALUES('" + v->id + "','single',1)");
   DB->query("INSERT INTO cp_single VALUES('" + v->id + "'," +
    v->minimum_quantity + "," + v->price + ")");
   retval+="Rule Added Successfully.<br>\n";
   break;

   case "buyxgetx":
   if(v->minimum_quantity!="" && v->price!=""){
   DB->query("INSERT INTO complex_pricing VALUES('" + v->id + "','buyxgetx',2)");
   DB->query("INSERT INTO cp_buyxgetx VALUES('" + v->id + "'," +
    v->quantity_to_qualify + "," + v->quantity_to_get + ",'" +
    v->bonus_product_id + "'," + v->price + "," + v->repeat + "," +
    v->exclude_others + ")");
   retval+="Rule Added Successfully.<br>\n";
   } else retval+="You must supply a Minimum Quantity and Price!<br>\n";
   break;
   }
  }
}
 retval+="<form action=./>"
  "<input type=hidden name=type value=\"" + v->type + "\">\n"
  "<input type=hidden name=cptype value=\"" + v->cptype + "\">\n"
  "<input type=hidden name=addnew value=2>\n"
  "<input type=hidden name=id value=\"" + v->id + "\">\n";

 switch(v->cptype){
  case "single":
  array r=DB->query("SELECT * FROM cp_single WHERE product_id='" + v->id +
   "' ORDER BY minimum_quantity ASC");
  retval+="<table><tr><th>Minimum Quantity</th><th>Price Ea.</th></tr>\n";
  if(!r || sizeof(r)<1)
   retval+="<tr><td colspan=3>No Rules Defined.</td></tr>\n";
  else foreach(r, mapping row)
   retval+="<tr><td>" + row->minimum_quantity + "</td><td>" +
    sprintf("%.2f",(float)(row->price)) + "</td><td><font size=1>"
    "<a href=\"./?id=" + v->id + "&type=" + v->type + "&cptype=" +
    v->cptype + "&minimum_quantity=" + row->minimum_quantity +
    "&delete=1\">Delete</a></font></td></tr>\n";
   retval+="<tr><td><input type=text size=5 name=minimum_quantity>"
    "</td><td><input type=text size=6 name=price></td><td>"
    "<font size=1><input type=submit value=Add></font></td></tr></table>\n";
  break;

  case "buyxgetx":
  break;
  }
 retval+="</form>\n";

}

retval+="<center><font size=-1>"
        "<form><input type=reset onclick=window.close() value=Close></form>"
        "</font></center>";
retval+="</font></body></html>";
return retval;
}

mapping query_event_callers(){
 return (["cp.single" : cpsingle,
          "cp.buyxgetx" : cpbuyxgetx ]);
}


mapping query_tag_callers(){
 return (["complex_pricing" : tag_complex_pricing ]);

}

mapping register_admin(){

return ([
	"add.product.Complex_Pricing":action_complexpricing,
	"getmodify.product.Complex_Pricing":action_complexpricing

	]);

}
