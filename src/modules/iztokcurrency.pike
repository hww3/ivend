/*
 * iztokcurrency.pike: iztok's currency module for iVend.
 *
 * Bill Welliver <hww3@riverweb.com>
 *
 */

inherit "roxenlib";

constant module_name="Iztok's Currency Module";
constant module_type="currency";



/*

  currency_convert

  v is price

*/

mixed currency_convert(mixed v, object id){
  float exchange=1.0;
  float customs=0.0;
  float our_fee=0.0;

  // calculate the exchange rate...
  v=( exchange * (float)v);
  v+=( (customs*(float)v) + (our_fee*(float)v) );
  return v;
}




