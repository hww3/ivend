//
//  complex_pricing.pike
//  This file is part of the iVend eCommerce system.
//  Copyright (c) 1999 Bill Welliver
//
#include <ivend.h> 
inherit "roxenlib";

constant module_name = "Complex Pricing Routines";
constant module_type = "addin";

void cpsingle(string event, object id, mapping args){

 return;

}

mapping query_event_callers(){
 return (["cp.single" : cpsingle]);
}
