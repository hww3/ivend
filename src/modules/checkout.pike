#!NOMODULE

/*
 * checkout.pike: default checkout module for iVend.
 *
 * Bill Welliver <hww3@riverweb.com>
 *
 */

inherit "roxenlib";

#include <ivend.h>
#include <messages.h>

constant module_name="Default Checkout Module";
constant module_type="checkout";

int initialized;

array fields=({});

mapping query_tag_callers2();
mapping query_container_callers2();

mixed stop_error(object id){
  if(id->misc->ivend->error && sizeof(id->misc->ivend->error)>0)
    return (id->misc->ivend->error *"\n");
}


mixed throw_error(string error, object id){
  id->misc->ivend->error+=({error});
  return;
}

void load_lineitems(object id){

id->misc->ivend->lineitems=([]);

  array r=id->misc->ivend->db->query("SELECT lineitem,value from lineitems "
    "WHERE orderid='" + (id->misc->ivend->orderid ||
	id->misc->ivend->SESSIONID) + "'");

  foreach(r, mapping row)
   id->misc->ivend->lineitems+=([ row->lineitem : (float) row->value ]);

  return;    

}


int initialize_db(object db, mapping config) {

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

void start(mapping config){

object db;

if(catch(db=iVend.db(config->general->dbhost, config->general->db,
  config->general->dblogin, config->general->dbpassword))) {
    perror("iVend: Checkout: Error Connecting to Database.\n");
    return;
  }
if((sizeof(db->list_tables("taxrates")))==1)
 initialized=1;
else
  initialize_db(db, config);

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

string retval;
 if(!id->misc->ivend->lineitems) 
   id->misc->ivend+= (["lineitems":([])]);

return retval;
}


string tag_confirmemail(string tag_name, mapping args,
		     object id, mapping defines) {
if(stop_error(id)) 
  return "<!-- skipping confirmemail because of errors.-->";
int good_email;
if(!args->field) 
  return "";
mixed err;
err=catch(good_email=Commerce.Sendmail.check_address(id->variables[lower_case(args->field)]));
if(err) {
 T_O->report_error("Error Running Check Address" + (err*"\n"),
id->misc->ivend->orderid ||"NA",
        "checkout", id); 
  return "<!-- An error occurred while checking the email address.-->";
}
else if(good_email)
  return "";
 else 
	throw_error(INVALID_EMAIL_ADDRESS, id);

return "";

}

mixed getorderid(object id){
int orderid;
// perror("doing getorderid.\n");
if(sizeof(DB->list_tables("orderid_list"))!=1) {
  perror("adding table orderid_list...\n");
  if(catch(DB->query("CREATE TABLE orderid_list ("
    "orderid CHAR(16) NOT NULL PRIMARY KEY, "
    "timestmp timestamp )"))) {
      throw_error("An error occurred while reserving your order id.", id);
      return -1;
    }
  }
if(catch(DB->query("LOCK TABLES orderid_list WRITE")))
  perror(STORE + ": Our DB doesn't support LOCK TABLES...\n");
array r=DB->query("SELECT MAX(orderid) AS max FROM orderid_list");
if(r && sizeof(r)>0)
  orderid=(int)(r[0]->max) + 1;
else orderid=1;
perror(orderid + "\n");
DB->query("INSERT INTO orderid_list VALUES('" + orderid + "',NOW())");
catch(DB->query("UNLOCK TABLES"));


return orderid;

}

string tag_confirmorder(string tag_name, mapping args,
		     object id, mapping defines) {

if(id->variables["_backup"] )
   return "<!-- Backing up. ConfirmOrder skipped.-->\n";

  string retval="";


// reserve the next order for me please...
array typer;
string type;
array s;


s=id->misc->ivend->db->query("SELECT * FROM sessions WHERE sessionid='"
	+ id->misc->ivend->SESSIONID + "'");

if(sizeof(s)==0) {
 throw_error("Your order appears to have been confirmed already, "
		"or your shopping session has expired." , id);
 return "";
  }

id->misc->ivend->orderid=getorderid(id);
if(stop_error(id))
 {
 T_O->report_error((string)stop_error(id), id->misc->ivend->orderid ||"NA",
	"checkout", id);
// id->misc->ivend->error+=({stop_error(id)});
 return "<false><!-- " + stop_error(id) + " -->\n";
}

id->misc->ivend->this_object->trigger_event("preconfirmorder", id,
(["orderid": id->misc->ivend->orderid]));

if(stop_error(id))
 {
 T_O->report_error((string)stop_error(id), id->misc->ivend->orderid ||"NA",
	"checkout", id);
// id->misc->ivend->error+=({stop_error(id)});
 return "<false><!-- " + stop_error(id) + " -->\n";
}

catch(typer=id->misc->ivend->db->query("SELECT shipping_types.type," 
"lineitems.extension FROM shipping_types,lineitems WHERE "
"lineitems.orderid='" + id->misc->ivend->SESSIONID + "' AND "
"lineitems.lineitem='shipping' "
"and shipping_types.name=lineitems.extension"));

if(!typer || sizeof(typer)<1) type="0";
else type=typer[0]->type;
  id->misc->ivend->db->query("INSERT INTO orders VALUES(" +
    id->misc->ivend->orderid + ",0," +
    type + ",NOW(),NULL,NOW())");

// get the order from sessions

  array r=id->misc->ivend->db->query(
	"SELECT sessions.*,sessions.price, products.taxable from sessions,products  WHERE sessionid='"
	+id->misc->ivend->SESSIONID+ "' and products." +
	id->misc->ivend->keys->products + "=sessions.id");

// replace sessionid with orderid
string query;
mixed error; 
error= catch{  
for(int i=0; i<sizeof(r); i++){

    r[i]->orderid=id->misc->ivend->orderid;
    r[i]->status=0;
    m_delete(r[i], "sessionid");    
    m_delete(r[i], "timeout");
    query=id->misc->ivend->db->generate_query(r[i], "orderdata",
id->misc->ivend->db);
    id->misc->ivend->db->query(query);
  }
 } ;
if(!error)
id->misc->ivend->db->query(
  "DELETE FROM sessions WHERE sessionid='"+id->misc->ivend->SESSIONID+"'");

else {
 T_O->report_error(error*"\n", id->misc->ivend->orderid ||"NA",
	"checkout", id);
  throw_error( UNABLE_TO_CONFIRM + "<br>" 
	+ (error*"<br>"), id);
  return "An error occurred while moving your order to confirmed status.\n";
}
// update customer info and payment info with new orderid

foreach(({"customer_info","payment_info","lineitems"}), string t)
  id->misc->ivend->db->query("UPDATE " + t + " SET orderid='"+
	id->misc->ivend->orderid+"' WHERE orderid='"
	+id->misc->ivend->SESSIONID+"'");

id->misc->ivend->this_object->trigger_event("confirmorder", id,
(["orderid": id->misc->ivend->orderid]));

// do we send a confirmation note? if so, do it.

string note;
note=Stdio.read_file(id->misc->ivend->config->general->root+"/notes/confirm.txt");
if(note) {

  string subject,sender, recipient;
  sscanf(note, "%s\n%s\n%s\n%s", sender, recipient, subject, note);
  sender=parse_rxml(sender, id);
  recipient=parse_rxml(recipient, id);
  subject=parse_rxml(subject, id);
  note=parse_rxml(note, id);
  array r=id->misc->ivend->db->query("SELECT " + recipient + " from customer_info WHERE "
		   "orderid='"+id->misc->ivend->orderid+"' AND "
		   "type=0");
  recipient=r[0][recipient];
  note=replace(note,"#orderid#",(string)id->misc->ivend->orderid);
  
  object message=MIME.Message(note,
				   (["MIME-Version":"1.0",
				     "To":recipient,
				     "X-Mailer":"iVend 1.0 for Roxen",
				     "Subject":subject
				     ]));

  perror("Sending confirmation note for " + id->misc->ivend->st + ".\n");

  if(!Commerce.Sendmail.sendmail(sender, recipient, (string)message))
 T_O->report_error("Unable to send confirmation note to " + recipient +
"." , (string)id->misc->ivend->orderid ||"NA", "checkout", id);

}

// do we send an order notification? if so, then do it.

note=Stdio.read_file(id->misc->ivend->config->general->root+"/notes/notify.txt");
if(note) {

  string subject,sender, recipient;
  sscanf(note, "%s\n%s\n%s\n%s", sender, recipient, subject, note);
  sender=parse_rxml(sender, id);
  recipient=parse_rxml(recipient, id);
  subject=parse_rxml(subject, id);
  note=parse_rxml(note, id);
  note=replace(note,"#orderid#",(string)id->misc->ivend->orderid);
  
  object message=MIME.Message(note,
				   (["MIME-Version":"1.0",
				     "To":recipient,
				     "X-Mailer":"iVend 1.0 for Roxen",
				     "Subject":subject
				     ]));


  if(!Commerce.Sendmail.sendmail(sender, recipient, (string)message))
 T_O->report_error("Unable to send order notification to " + recipient +
"." , (string)id->misc->ivend->orderid ||"NA", "checkout", id);

}

 T_O->report_status("Order confirmed successfully." ,
   id->misc->ivend->orderid ||"NA", "checkout", id);

return retval;
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


/*

  calculate tax

*/

string tag_salestax(string tag_name, mapping args,
		     object id, mapping defines) {
if(stop_error(id)) 
  return "<!-- skipping salestax because of errors.-->";

array r;		// result from query
string query;		// the query
float totaltax;		// totaltax
string locality;	// fieldname of locality
float taxrate=0.00;
mapping lookup=([]);

query="SELECT field_name FROM taxrates GROUP BY field_name";

r=DB->query(query);

if(sizeof(r)==0)
  return "0.00";

array fields=({});
mapping tables=([]);

foreach(r, mapping row)
  fields += ({row->field_name});
foreach(fields, string f)
  if(!tables[(f/".")[0]]) {
    tables += ([(f/".")[0]:({})]);
    tables[(f/".")[0]] += ({f});
    }
  else tables[(f/".")[0]] +=({f});

foreach(indices(tables), string tname){

 query="SELECT " + (tables[tname]*", ") + " FROM " + tname + 
  " WHERE " + tname + ".orderid='" + id->misc->ivend->SESSIONID + "'"; 

// perror(query + "\n");

 r=DB->query(query);

 if(sizeof(r)!=0)
  foreach(indices(r[0]), string fname) 
    lookup+=([tname + "." + fname: r[0][fname]]);
 } 

if(sizeof(lookup)==0) {
  perror("iVend: Unable to find order info for tax calculation!\n");
  return "0.00";
  }


else { 		// calculate the tax rate as sum of all matches.

  foreach(indices(lookup), string fname) {
    query="SELECT * FROM taxrates WHERE field_name='" + fname + "' AND "
      "value='" + lookup[fname] + "'";

//    perror(query + "\n");
    r=DB->query(query);

    if(sizeof(r)!=0) taxrate+=(float)r[0]->taxrate;
  
    } 

  r=DB->query(query);
  if(sizeof(r)==1) {
    if(CONFIG_ROOT[module_name]->shipping_taxable=="Yes")
      totaltax=(float)taxrate *
        (float)((id->misc->ivend->lineitems->taxable +
         id->misc->ivend->lineitems->shipping) || 0.00);
    else totaltax=(float)taxrate *
	(float)(id->misc->ivend->lineitems->taxable || 0.00);
	totaltax=(float)sprintf("%.2f", (float)totaltax);
    id->misc->ivend->lineitems+=(["salestax":(float)totaltax]);
      return sprintf("%.2f",totaltax);
    }

  else return ("0.00");
  }

id->misc->ivend->lineitems+=(["salestax":0.00]);
return ("ERROR");

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
	"orderid='" + id->misc->ivend->SESSIONID + "'" +
 (args->type?" AND type='"+ args->type + "'":"") ) ;

 if(r && sizeof(r)==1){
  record=r[0];
 foreach(indices(record), string f)  // remove all encrypted fields...
  if(record[f][0..3]=="iVEn")
   record[f]="";

//  perror("got a record...");
  }
}

 retval+=id->misc->ivend->db->generate_form_from_db(args->table,
    ((
 
      (( (args->exclude||" ")-" ")/",")
       ||({}))
        + 
     ( (
      ((args->hide||" ")-" ") /",")
      ||({})) 
     ),id,(( ((args->pulldown||" ")-" ")/",")||({})), record)+
        "<input type=hidden name=table value=\""+args->table+"\">";
retval+="<input type=hidden name=aeexclude value=\""+((args->exclude||" ")-" ")
  + "\">\n";
return retval;
}

string tag_addentry(string tag_name, mapping args,
		     object id, mapping defines) {
if(id->variables["_backup"])
   return "<!-- Backing up. addentry skipped. -->\n";
if(stop_error(id)) return "<!-- Not adding data because of errors.-->";
if((int)id->variables->shipsame==1) return "";
if(!args->noflush)
  id->misc->ivend->clear_oldrecord=1;

// handle encrypting of records...
  mixed toencrypt=CONFIG_ROOT[module_name]->encryptfields;
  if(!arrayp(toencrypt)) toencrypt=({toencrypt});
  string key;
object privs=Privs("Reading public Key");
  catch(key=Stdio.read_file(id->misc->ivend->config->general->publickey));
privs=0;
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

 if(id->variables->aeexclude){
   array aeexclude=(lower_case(id->variables->aeexclude)-" ") /",";
   string exclude;
   foreach(aeexclude, exclude) {
     id->variables[exclude]="N/A";
   }
   m_delete(id->variables, "aeexclude");
 }

  j=id->misc->ivend->db->addentry(id);
    
if(arrayp(j)) id->misc->ivend->error+=j;

return "";


}

string tag_cardcheck(string tag_name, mapping args,
		     object id, mapping defines) {
if(stop_error(id)) 
  return "<!-- skipping cardcheck because of errors.-->";

string card_number;
string exp_date;
string card_type;

card_number=id->variables[args->card_number] || id->variables->card_number;
exp_date=id->variables[args->expdate] || id->variables->expiration_date;
card_type=id->variables[args->cardtype] || id->variables->payment_method;

perror("card_type: " + card_type + "\ncard_number: "+ card_number +
"\nexp_date: " + exp_date + "\n");

if(Commerce.CreditCard.cc_verify(card_number, card_type)!=0)
  {
    throw_error(INVALID_CREDIT_CARD, id);
  return "<!-- bad card number -->";
  }
else if(Commerce.CreditCard.expdate_verify(exp_date)!=0)
 {
   throw_error(INVALID_CREDIT_CARD, id);
  return "<!-- bad date -->";
 }
return "<!-- successful card check -->";

}

mixed checkout(string p, object id){
//if(p!="") return;
perror("checkout: "+ p + "\n");

id->misc->ivend->checkout=1;
if(id->variables->_backup  && id->variables->_page)
  id->variables->_page=(int)(id->variables->_page)-2;
  if((int)(id->variables->_page) < 1) id->variables->_page=1;
string retval=
  Stdio.read_file(id->misc->ivend->config->general->root +
    "/html/checkout/checkout_"+ (id->variables["_page"] || "1") +
    ".html");

if(!retval) return "error loading " +
id->misc->ivend->config->general->root +
  "/html/checkout/checkout_"+ (id->variables["_page"] || "1") + 
  ".html" ;    

retval=parse_rxml(retval,id);

return retval;

}


string tag_subtotal(string tag_name, mapping args,
		     object id, mapping defines) {
if(stop_error(id)) 
  return "<!-- skipping subtotal because of errors.-->";

float subtotal;

subtotal=(float)id->misc->ivend->lineitems->taxable + 
	(float)id->misc->ivend->lineitems->nontaxable;


return sprintf("%.2f", subtotal);



}

string tag_grandtotal(string tag_name, mapping args,
		     object id, mapping defines) {

if(stop_error(id)) 
  return "<!-- skipping grandtotal because of errors.-->";

float grandtotal=0.00;
string item;
 foreach(indices(id->misc->ivend->lineitems), item) {
   float i= id->misc->ivend->lineitems[item];
   grandtotal+=i;
   if(item=="shipping");
   else {
     id->misc->ivend->db->query("DELETE FROM lineitems WHERE orderid='"
				+id->variables->orderid+"' AND lineitem='"
				+item +"'");
     id->misc->ivend->db->query("REPLACE INTO lineitems VALUES('"+ 
			   id->variables->orderid + 
			   "','" + item + "',"+ i + ",NULL)");
   }
 }

 return sprintf("%.2f",(float)grandtotal);

}

string tag_showorder(string tag_name, mapping args,
		     object id, mapping defines) {
if(stop_error(id)) 
  return "<!-- skipping showorder because of errors.-->";

float taxable=0.00;
float nontaxable=0.00;
string retval="";
/*
 object s=Sql.sql(
    id->misc->ivend->config->dbhost,
    id->misc->ivend->config->db,
    id->misc->ivend->config->dblogin,
    id->misc->ivend->config->dbpassword
    );
*/
string extrafields="";
array ef=({});
array en=({});

 if(args->fields){
   ef=args->fields/",";
   if(args->names)
   en=args->names/",";
   else en=({});
   for(int i=0; i<sizeof(ef); i++) {
     if(catch(en[i]) || !en[i])  en+=({ef[i]});
     extrafields+=", " + ef[i] + " AS " + "'" + en[i] + "'";
   }
 }     

string query="SELECT sessions.quantity, "
  "products.price, " 
  "sessions.quantity*products.price AS linetotal, taxable " + extrafields +
  " FROM sessions,products WHERE products." +
id->misc->ivend->keys->products + "=sessions.id AND "
  "sessions.sessionid='" + id->misc->ivend->SESSIONID + "'";

array r=id->misc->ivend->db->query(query);
 for(int i=0; i < sizeof(r); i++) {
   retval+="<tr><td align=right>" + r[i]->quantity + "</td>\n";
   foreach(en, string name)
     retval+="<td>" + r[i][name] + "</td>\n";
   retval+="<td align=right>";

retval+=r[i]->price;
   retval+= "</td>\n"
     "<td align=right>";
retval+=r[i]->linetotal;
if(r[i]->taxable=="N") nontaxable+=(float)r[i]->linetotal;
  else taxable+=(float)r[i]->linetotal;
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
if(stop_error(id)) {
  perror("<!-- skipping checkout because of errors -->\n");
  return "<!-- skipping checkout because of errors -->";
  }
if(args->orderid)
  id->misc->ivend->orderid=args->orderid;
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
contents="<form method=post action=\"" + id->not_query + "\">\n<input type=hidden name=_page "
  "value=" + (id->misc->ivend->next_page || "2") + ">\n"
  +contents+ "</form>\n";

load_lineitems(id);

contents=parse_html(contents,
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
 
string retval="<font size=+1><b>Sales Tax Setup</b></font><p>";
array r=DB->query("SELECT * FROM taxrates");
if(sizeof(r)==0){
  retval+="You have not set any tax rules yet.<p>";
  }

else {
  retval+="<b>Current Tax Rules:</b><p>"
    "<table>\n"
    "<tr><th><font face=helvetica,arial>Table.Field Name</font></th>"
    "<th><font face=helvetica,arial>Match Value</th>"
    "<th><font face=helvetica,arial>Tax Rate</th><th>&nbsp;</th></tr>\n";
  
  foreach(r, mapping row){
    retval+="<tr><td><font face=helvetica,arial>" + 
	row->field_name + "</font></td><td><font face=helvetica,arial>" + 
	row->value + "</font></td><td><font face=helvetica,arial>" + 
        sprintf("%.2f",(((float)row->taxrate)*100)) + 
      "%</font></td><td><font face=helvetica,arial>"
      " &nbsp; <a href=\"./?deleterule=" +
      row->id  + "\">DeleteRule</a></font></td></tr>\n";
    }
  retval+="</table>";
  }
retval+="<p>\n";
retval+="<form action=\"./\" method=post>"
  "<table>"
  "<tr><th><font face=helvetica,arial>Table.Field</font></th>"
  "<th><font face=helvetica,arial>Match Value</font></th>"
  "<th><font face=helvetica,arial>Tax Rate (%)</font></th></tr>";

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
      "confirmemail" : tag_confirmemail,
	  "shipping" : tag_shipping,
	"grandtotal" : tag_grandtotal,
  	  "subtotal" : tag_subtotal,
	  "salestax" : tag_salestax, 
	  "discount" : tag_discount, 
	 "cardcheck" : tag_cardcheck,
	  "addentry" : tag_addentry,
	"generateform": tag_generateform
	]);

}

mapping query_container_callers2(){

  return ([]);

}

mapping query_tag_callers(){

  return ([]);

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
  })
});

}

