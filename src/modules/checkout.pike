#!NOMODULE

/*
 * checkout.pike: default checkout module for iVend.
 *
 * Bill Welliver <hww3@riverweb.com>
 *
 */

inherit "caudiumlib";
inherit iVend.error;

#include <ivend.h>
#include <messages.h>

constant module_name="Checkout";
constant module_type="checkout";

int initialized;

array fields=({});

mapping query_tag_callers2();
mapping query_container_callers2();

mixed stop_error(object id){
  if(id->misc->ivend->error && sizeof(id->misc->ivend->error)>0)
    return (id->misc->ivend->error *"\n");
}

void|mixed error_happened(object id){
  if(id->misc->ivend->error && sizeof(id->misc->ivend->error)>0)
    return 1;
  if(id->misc->ivend->error_happened)
    return 1;
}

void|mixed throw_error(string error, object id){
  id->misc->ivend->error+=({error});
  return;
}

void load_lineitems(object id){

id->misc->ivend->lineitems=([]);

  array r=DB->query("SELECT lineitem,value from lineitems "
    "WHERE orderid='" + (id->misc->session_variables->orderid) + "'");

  foreach(r, mapping row)
   id->misc->ivend->lineitems+=([ row->lineitem : (float) row->value ]);

  return;    

}


int initialize_db(object db) {

  perror("initializing sales tax module!\n");
catch(db->query("drop table taxrates"));
if(catch(db->query(
  "CREATE TABLE taxrates ("
  " taxrate float(5,2) DEFAULT '0.00' NOT NULL,"
  " type char(1) DEFAULT 'C' NOT NULL,"
  " field_name char(64) NOT NULL, "
  " value char(24) NOT NULL, "
  " id int NOT NULL AUTO_INCREMENT PRIMARY KEY"
  " ) "))) {
    perror("iVend: taxrate table setup failed. \n");
    return 0;
    }
initialized=1;
return 0;

}

void start(object m, object db){

if((sizeof(db->list_tables("taxrates")))==1)
 initialized=1;
else
  initialize_db(db);

return;

}




/*

  currency_convert

  v is price

*/
/*
mixed currency_convert(mixed v, object id){
  float exchange=3.0;
  float customs=2.0;
  float our_fee=3.0;

  // calculate the exchange rate...
  v=( exchange * (float)v);
  v+=( (customs*(float)v) + (our_fee*(float)v) );
  return v;
}

*/

string tag_shipping(string tag_name, mapping args,
		     object id, mapping defines) {
if(stop_error(id)) 
  return "<!-- skipping shipping because of errors.-->";
if(id->variables["_backup"] || id->misc->ivend->skip_page )
  return "<!-- skipping shipping because of page jump. -->";

string retval;
 if(!id->misc->ivend->lineitems) 
   id->misc->ivend+= (["lineitems":([])]);

return retval;
}

mixed getorderid(object id){

  return DB->reserve_orderid();

}

string tag_confirmorder(string tag_name, mapping args,
		     object id, mapping defines) {

array typer;
string type;

if(id->variables["_backup"] || id->misc->ivend->skip_page )
   return "<!-- ConfirmOrder skipped.-->\n";

  string retval="";

if(sizeof(id->misc->session_variables->cart)==0) {
 throw_error(ERROR_ORDERID_ALREADY_EXISTS, id);
 return "";
  }

if(stop_error(id))
 {
 T_O->ivend_report_error((string)stop_error(id), id->misc->session_variables->orderid ||"NA",
	"checkout", id);
 return "<false><!-- " + stop_error(id) + " -->\n";
}

id->misc->ivend->this_object->trigger_event("preconfirmorder", id,
  (["orderid": id->misc->session_variables->orderid]));

if(stop_error(id))
 {
 T_O->ivend_report_error((string)stop_error(id), id->misc->session_variables->orderid ||"NA",
	"checkout", id);
 return "<false><!-- " + stop_error(id) + " -->\n";
}

catch(typer=DB->query("SELECT shipping_types.type," 
"lineitems.extension FROM shipping_types,lineitems WHERE "
"lineitems.orderid='" + id->misc->session_variables->orderid + "' AND "
"lineitems.lineitem='shipping' "
"and shipping_types.name=lineitems.extension"));

if(!typer || sizeof(typer)<1) type="0";
else type=typer[0]->type;
mixed error=catch(DB->query("INSERT INTO orders VALUES(" +
    id->misc->session_variables->orderid + ",0," +
    type + ",NOW()," + (id->variables->ordernotes?"'" +
DB->make_safe(id->variables->ordernotes) + "'":"NULL") + ",NOW())"));
if(error)
{
 T_O->ivend_report_error(error*"\n", id->misc->session_variables->orderid ||"NA",
	"checkout", id);
  throw_error( UNABLE_TO_CONFIRM + "<br>" 
	+ (error*"<br>"), id);
  return "An error occurred while moving your order to confirmed status.\n";

}
// get the order from sessions

  array r=copy_value(id->misc->session_variables->cart);
  werror("cart: %O\n", r);
  string query;
  error= catch {  
  for(int i=0; i<sizeof(r); i++){
    r[i]->orderid=id->misc->session_variables->orderid;
    r[i]->id = r[i]->item;
    r[i]->status=0;
    query=DB->generate_query(r[i], "orderdata", DB);
werror("query: %s\n", query);
    DB->query(query);
 }
};

if(!error)
  id->misc->session_variables->cart=({});

else {
 T_O->ivend_report_error(error*"\n", id->misc->session_variables->orderid ||"NA",
	"checkout", id);
  throw_error( UNABLE_TO_CONFIRM + "<br>" 
	+ (error*"<br>"), id);
  return "An error occurred while moving your order to confirmed status.\n";
}

id->misc->ivend->this_object->trigger_event("confirmorder", id,
(["orderid": id->misc->session_variables->orderid]));

// do we send a confirmation note? if so, do it.
mixed er;
string note;
note=Stdio.read_file(T_O->query("storeroot")+"/notes/confirm.txt");
if(note) {

  string subject,sender, recipient;
  sscanf(note, "%s\n%s\n%s\n%s", sender, recipient, subject, note);
  sender=parse_rxml(sender, id);
  recipient=parse_rxml(recipient, id);
  subject=parse_rxml(subject, id);
  note=parse_rxml(note, id);
  array r=DB->query("SELECT " + recipient + " from customer_info WHERE "
		   "orderid='"+id->misc->session_variables->orderid+"' AND "
		   "type=0");
  recipient=r[0][recipient];
  note=replace(note,"#orderid#",(string)id->misc->session_variables->orderid);
  
  object message=MIME.Message(note,
				   (["MIME-Version":"1.0",
				     "To":recipient,
				     "X-Mailer":"iVend 1.2 for Caudium",
				     "Subject":subject
				     ]));


 er=catch(T_O->ivend_send_mail(({recipient}), (string)message));
 if(er)
 T_O->ivend_report_error("Unable to send confirmation note to " + recipient +
"." , (string)id->misc->session_variables->orderid ||"NA", "checkout", id);
else
 T_O->ivend_report_status("Order confirmation sent to " + recipient + "." ,
   id->misc->session_variables->orderid ||"NA", "checkout", id);

}

// do we send an order notification? if so, then do it.

note=Stdio.read_file(T_O->query("storeroot")+"/notes/notify.txt");
if(note) {

  string subject,sender, recipient;
  sscanf(note, "%s\n%s\n%s\n%s", sender, recipient, subject, note);
  sender=parse_rxml(sender, id);
  recipient=parse_rxml(recipient, id);
  subject=parse_rxml(subject, id);
  note=parse_rxml(note, id);
  note=replace(note,"#orderid#",(string)id->misc->session_variables->orderid);
  
  object message=MIME.Message(note,
				   (["MIME-Version":"1.0",
				     "To":recipient,
				     "X-Mailer":"iVend 1.2 for Caudium",
				     "Subject":subject
				     ]));
 er=catch(T_O->ivend_send_mail(({recipient}), (string)message));
 if(er)
   T_O->ivend_report_error("Unable to send confirmation note to " + recipient +
     "." , (string)id->misc->session_variables->orderid ||"NA", "checkout", id);
 else
 T_O->ivend_report_status("Order confirmation sent to " + recipient + "." ,
   id->misc->session_variables->orderid ||"NA", "checkout", id);

}

 T_O->ivend_report_status("Order confirmed successfully." ,
   id->misc->session_variables->orderid ||"NA", "checkout", id);

 id->misc->ivend->this_object->trigger_event("postconfirmorder", id,
 (["orderid": id->misc->session_variables->orderid]));

 m_delete(id->misc->session_variables, "orderid");

 return "<TRUE>" + retval;
}

string tag_discount(string tag_name, mapping args,
		     object id, mapping defines) {
if(stop_error(id)) 
  return "<!-- skipping discount because of errors.-->";

float tdiscount, ntdiscount;

float tsubtotal=id->misc->ivend->lineitems->taxable;
float ntsubtotal=id->misc->ivend->lineitems->nontaxable;

if(args->percent) { 


	tdiscount= (tsubtotal *
	((float)args->percent / 100));
	ntdiscount= (ntsubtotal *
	((float)args->percent / 100));

}


id->misc->ivend->lineitems->taxable= 
	(float)id->misc->ivend->lineitems->taxable - (float)tdiscount;
id->misc->ivend->lineitems->nontaxable=
	(float)id->misc->ivend->lineitems->nontaxable - (float)ntdiscount;


return sprintf("%.2f", tdiscount + ntdiscount);

}


string tag_salestax(string tag_name, mapping args,
		     object id, mapping defines) {
if(stop_error(id)) 
  return "<!-- skipping salestax because of errors.-->";


return (string)(sprintf("%.2f",T_O->get_tax(id, (args->orderid ||
id->misc->session_variables->orderid))));

}

string tag_generateform(string tag_name, mapping args,
		     object id, mapping defines) {
if(stop_error(id)) 
  return "<!-- skipping generateform because of errors.-->";
mapping record;
string retval="";
if(!args->table) return "";

if(args->autofill) {
 array r;
 r=DB->query("SELECT * FROM " + lower_case(args->table) + " WHERE "
	"orderid='" + (args->orderid || id->misc->session_variables->orderid) 
        + "'" + (args->type?" AND type='" + args->type + "'":"") ) ;

 if(r && sizeof(r)==1){
  record=r[0];
 foreach(indices(record), string f)  // remove all encrypted fields...
  if(record[f] && sizeof(record[f])>4 && record[f][0..3]=="iVEn")
   record[f]="";

//  perror("got a record...");
  }
}

 retval+=DB->generate_form_from_db(args->table,
    ((
 
      (( (args->exclude||" ")-" ")/",")
       ||({}))
        + 
     ( (
      ((args->hide||" ")-" ") /",")
      ||({})) 
     ),id,(( ((args->pulldown||" ")-" ")/",")||({})), record)+
        "<input type=\"hidden\" name=\"table\" value=\""+args->table+"\">";
retval+="<input type=\"hidden\" name=\"aeexclude\" value=\""+((args->exclude||" ")-" ")
  + "\">\n";
return retval;
}

string tag_addentry(string tag_name, mapping args,
		     object id, mapping defines) {
if(id->variables["_backup"] || id->misc->ivend->skip_page)
   return "<!-- addentry skipped. -->\n";
if(stop_error(id)) return "<!-- Not adding data because of errors.-->";
if((int)id->variables->shipsame==1) {
 array q=DB->query("SELECT * FROM customer_info WHERE orderid='" +
   id->misc->session_variables->orderid + "' AND type=0");
 if(q && sizeof(q)) 
   foreach(indices(q[0]), string f)
     id->variables[lower_case(f)]=q[0][f];
   id->variables->type=1;
 }
if(!args->noflush)
  id->misc->ivend->clear_oldrecord=1;

// handle encrypting of records...
  mixed toencrypt=CONFIG_ROOT[module_name]->encryptfields;
  if(!arrayp(toencrypt)) toencrypt=({toencrypt});

string key="";
string keyloc="";

keyloc = T_O->query("storeroot");
if(keyloc && file_stat(combine_path(keyloc, "private/key.pub")))
{
  object privs=Privs("Reading Key File");
  key=Stdio.read_file(combine_path(keyloc, "private/key.pub"));
  privs=0;
}

  if(key && toencrypt)
  foreach(toencrypt, string encrypt){
    encrypt=lower_case(encrypt);
    if(id->variables[encrypt])
	id->variables[encrypt]=
	  Commerce.Security.encrypt(id->variables[encrypt],key)||
	id->variables[encrypt];
    }
  else perror("Can't load public key.\n");

mixed j;
id->variables->orderid = id->misc->session_variables->orderid;
 if(id->variables->aeexclude){
   array aeexclude=(lower_case(id->variables->aeexclude)-" ") /",";
   string exclude;
   foreach(aeexclude, exclude) {
     id->variables[exclude]="N/A";
   }
   m_delete(id->variables, "aeexclude");
 }

  j=DB->addentry(id);
    
if(arrayp(j)) id->misc->ivend->error+=j;

return "";


}

string tag_checkouterror(string tag_name, mapping args,
		     object id, mapping defines) {
  if(id->misc->ivend->error_happened &&
sizeof(id->misc->ivend->error_happened)>0)
    return ("<checkout_error>"+(id->misc->ivend->error_happened *"\n")
+"</checkout_error><false>");
else return "<true>";
}

string tag_cardcheck(string tag_name, mapping args,
		     object id, mapping defines) {
if(stop_error(id)) 
  return "<!-- skipping cardcheck because of errors.-->";
if(id->variables["_backup"] || id->misc->ivend->skip_page )
  return "<!-- skipping cardcheck because of page jump. -->";
string card_number;
string exp_date;
string card_type;

card_number=id->variables[args->card_number] || id->variables->card_number;
exp_date=id->variables[args->expdate] || id->variables->expiration_date;
card_type=id->variables[args->cardtype] || id->variables->payment_method;

//perror("card_type: " + card_type + "\ncard_number: "+ card_number +
//"\nexp_date: " + exp_date + "\n");

return "<!-- successful card check -->";

}

mixed checkout(string p, object id){

id->misc->ivend->checkout=1;
if(id->variables->_backup  && id->variables->_page)
  id->variables->_page=(int)(id->variables->_page)-2;
  if((int)(id->variables->_page) < 1) id->variables->_page=1;
string retval=
  Stdio.read_file(T_O->query("storeroot") +
    "/html/checkout/checkout_"+ (id->variables["_page"] || "1") +
    ".html");

if(!retval) return "error loading " +
  T_O->query("storeroot") +
  "/html/checkout/checkout_"+ (id->variables["_page"] || "1") + 
  ".html" ;    

catch(retval=parse_rxml(retval,id,0,id->misc->defines));

if(stop_error(id)){
if(id->variables->_backup  && id->variables->_page)
  id->variables->_page=(int)(id->variables->_page)+1;
else id->variables->_page=(int)(id->variables->_page)-1;
  if((int)(id->variables->_page) < 1) id->variables->_page=1;
  id->misc->ivend->error_happened=id->misc->ivend->error;
  m_delete(id->misc->ivend, "error");
  return checkout(p, id);
  }

if(id->misc->ivend->skip_page) {
  m_delete(id->misc->ivend, "skip_page");
  return checkout(p, id);
  }
else
  return retval;

}

string tag_subtotal(string tag_name, mapping args,
		     object id, mapping defines) {
if(stop_error(id)) 
  return "<!-- skipping subtotal because of errors.-->";



return sprintf("%.2f", T_O->get_subtotal(id, args->orderid ||
id->misc->session_variables->orderid));



}

string tag_grandtotal(string tag_name, mapping args,
		     object id, mapping defines) {

if(stop_error(id)) 
  return "<!-- skipping grandtotal because of errors.-->";

float gt=T_O->get_grandtotal(id, args->orderid || id->misc->session_variables->orderid);

return sprintf("%.2f", (float)(gt));


}

string tag_skippage(string tag_name, mapping args,
		     object id, mapping defines) {
id->misc->ivend->skip_page=1;
if(id->variables->_backup  && id->variables->_page)
  id->variables->_page=(int)(id->variables->_page)-1;
else id->variables->_page=(int)(id->variables->_page)+1;
  if((int)(id->variables->_page) < 1) id->variables->_page=1;

return "";
}

string tag_showorder(string tag_name, mapping args,
		     object id, mapping defines) {
if(stop_error(id)) 
  return "<!-- skipping showorder because of errors.-->";

float taxable=0.00;
float nontaxable=0.00;
string retval="";

string extrafields="";
array ef=({});
array en=({});

 if(args->fields){
   ef=args->fields/",";
 if(args->names)
   en=args->names/",";
 else en=ef;

 array x1=({});
 foreach(ef; int i; string fn)
     x1+=({ fn + " AS " + "'" + en[i] + "'"});

 extrafields = (x1*", ");

 }

 foreach(id->misc->session_variables->cart, mapping row)
 {

   string q = "SELECT " + extrafields + 
     " FROM products WHERE " + DB->keys->products + "='" + row->item + "'";
   array rx=DB->query(q);
   retval+="<tr><td align=\"right\">" + row->quantity + "</td>\n";
   foreach(en, string name)
     retval+="<td>" + rx[0][name] + "</td>\n";
   retval+="<td align=\"right\">";

   retval+=sprintf("%.2f", (float)(row->price));
   retval+= "</td>\n"
     "<td align=\"right\">";
   float linetotal = ((float)(row->quantity) * (float)(row->price));
   retval+=sprintf("%.2f", linetotal);
   if(row->taxable=="N") nontaxable+=linetotal;
   else taxable+=linetotal;
   retval+= "</td></tr>\n"; 
 }


 if(!id->misc->ivend->lineitems) id->misc->ivend+=(["lineitems":([])]);
 id->misc->ivend->lineitems+=(["taxable":(float)taxable]);
 id->misc->ivend->lineitems+=(["nontaxable":(float)nontaxable]);
return retval;

}


string|void container_checkout(string name, mapping args,
                      string contents, object id)
{
// perror("doing container_checkout.\n");
werror("checkout request: %O\n\n", id->raw);
if(stop_error(id)) {
  perror("<!-- skipping checkout because of errors -->\n");
  return "<!-- skipping checkout because of errors -->";
  }
if(!id->misc->session_variables->orderid)
  id->misc->session_variables->orderid=getorderid(id);

if(args->orderid)
  id->misc->session_variables->orderid=args->orderid;

mapping tags,containers;
if(functionp(query_tag_callers2))
 tags=query_tag_callers2();
if(functionp(query_container_callers2))
  containers=query_container_callers2();
string h;

 id->misc->ivend->error=({});

if(id->variables["_page"])
    id->misc->ivend->next_page= (int)id->variables["_page"]+1;
if(!args->quiet)
contents="<form name=\"checkoutform\" method=\"post\" action=\"" + id->not_query +"\">\n<input type=\"hidden\" name=\"_page\" "
  "value=\"" + (id->misc->ivend->next_page || "2") + "\">\n"
  +contents+ "</form>\n";

load_lineitems(id);
contents=Caudium.parse_html(contents,
		  tags,
		  containers,
		  id);
return contents;

}


string tax_setup(string mode, object id){

if(id->variables->deleterule)
  DB->query("DELETE FROM taxrates WHERE id=" + id->variables->deleterule);
if(id->variables->addrule)
  DB->query("INSERT INTO taxrates VALUES(" +
  ((float)id->variables->taxrate/100) + 
  ",'C','" + id->variables->field_name +
  "','" + upper_case(id->variables->value) + "',NULL)");
 
string retval="<font size=\"+1\"><b>Sales Tax Setup</b></font><p>";
array r=DB->query("SELECT * FROM taxrates");
if(sizeof(r)==0){
  retval+="You have not set any tax rules yet.<p>";
  }

else {
  retval+="<b>Current Tax Rules:</b><p>"
    "<table>\n"
    "<tr><th><font face=\"helvetica,arial\">Table.Field Name</font></th>"
    "<th><font face=\"helvetica,arial\">Match Value</th>"
    "<th><font face=\"helvetica,arial\">Tax Rate</th><th>&nbsp;</th></tr>\n";
  
  foreach(r, mapping row){
    retval+="<tr><td><font face=\"helvetica,arial\">" + 
	row->field_name + "</font></td><td><font face=\"helvetica,arial\">" + 
	row->value + "</font></td><td><font face=\"helvetica,arial\">" + 
        sprintf("%.2f",(((float)row->taxrate)*100)) + 
      "%</font></td><td><font face=\"helvetica,arial\">"
      " &nbsp; <a href=\"./?deleterule=" +
      row->id  + "\">DeleteRule</a></font></td></tr>\n";
    }
  retval+="</table>";
  }
retval+="<p>\n";
retval+="<form action=\"./\" method=\"post\">"
  "<table>"
  "<tr><th><font face=\"helvetica,arial\">Table.Field</font></th>"
  "<th><font face=\"helvetica,arial\">Match Value</font></th>"
  "<th><font face=\"helvetica,arial\">Tax Rate (%)</font></th></tr>";

retval+="<tr><td><select name=\"field_name\">";

r=DB->list_fields("customer_info");
foreach(r, mapping f)
  retval+="<option>customer_info." + f->name + "\n";

r=DB->list_fields("payment_info");
foreach(r, mapping f)
  retval+="<option>payment_info." + f->name + "\n";

retval+="</select></td><td><input type=text size=15 name=\"value\">"
  "</td><td><input type=text size=5 name=taxrate></td><td>\n"
  "<input type=submit value=\"Add Rule\" name=\"addrule\"></td></tr>"
   "</table></form>";

retval+="<b>How Tax is Calculated:</b><p>"
  "Tax is calculated by adding the tax percentage of all taxable "
  "items in the purchase transaction shipping (if applicable) to the "
  "previous subtotal. "
  "<p>The tax percentage is taken by adding all of the percentages for "
  "fields in the order data that match rules listed in the rules table above.";
return retval;

}


mapping query_tag_callers2() {

return (["showorder" : tag_showorder,
      "confirmorder" : tag_confirmorder,
	  "discount" : tag_discount, 
	 "cardcheck" : tag_cardcheck,
	  "addentry" : tag_addentry,
	"generateform": tag_generateform,
	"checkouterror": tag_checkouterror,
	"skippage": tag_skippage
	]);

}

mapping query_container_callers2(){

  return ([]);

}

mapping query_tag_callers(){

  return ([
	"grandtotal" : tag_grandtotal,
  	  "subtotal" : tag_subtotal,
	  "salestax" : tag_salestax

]);

}

mapping query_container_callers() {

return ([ "checkout" : container_checkout]);

}

mapping register_paths() {

return ([ "checkout" : checkout ]);

}

mixed register_admin(){
        
return ({
	([ "mode": "menu.main.Store_Administration.Sales_Tax_Setup",
		"handler": tax_setup,
		"security_level": 9        
        ])
	}); 
}

array query_preferences(object id){

  if(!catch(DB) && sizeof(fields)<=0) {

     array f2=DB->list_fields("payment_info");
     foreach(f2, mapping m)
        fields +=({m->name});
    }


return ({

        ({"encryptfields", "Encrypt Fields",
        "Payment fields to be encrypted.",
        VARIABLE_MULTIPLE,
        "Card_Number",
        fields
        }) ,

  ({
  "shipping_taxable", "Tax Shipping?", "Some governments require "
  "that shipping charges be included in sales tax calculations. If your "
  "government requires this, this should be set to 'Yes.'", 
  VARIABLE_SELECT, "No", ({"Yes", "No"})
  }) ,

  ({"checkouturl", "Checkout URL", "Your checkout might be located "
  "in a different instance of iVend. Enter the url of the checkout "
  "step here.", VARIABLE_STRING, ""})
});

}

