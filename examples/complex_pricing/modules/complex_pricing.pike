//
//  complex_pricing.pike
//  This file is part of the iVend eCommerce system.
//  Copyright (c) 1999 Bill Welliver
//
#include <ivend.h> 
inherit "roxenlib";

constant module_name = "Complex Pricing Routines";
constant module_type = "addin";

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
perror("starting buyxgetx...\n");
 string item=args->item;
 int quantity=(int)args->quantity;

 array offers=DB->query("SELECT * FROM cp_buyxgetx WHERE product_id='" + 
  item + "' AND quantity_to_qualify <=" + quantity + " ORDER BY "
  "quantity_to_get DESC");

 if(!offers || sizeof(offers)<1) {
  COMPLEX_ADD_ERROR=NO_ADD;
perror("exiting buyxgetx...\n");
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
perror("exiting buyxgetx...\n");
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
  int result=T_O->do_low_additem(id, item, quantity, price);
  if(!result) {
   COMPLEX_ADD_ERROR=ADD_FAILED;
   perror("An error occurred adding item: " + item + " price: " +
    price + "\n");
   }
  }
 return;

}

mapping query_event_callers(){
 return (["cp.single" : cpsingle,
          "cp.buyxgetx" : cpbuyxgetx ]);
}


