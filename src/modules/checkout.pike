/*
 * checkout.pike: default checkout module for iVend.
 *
 * Bill Welliver <hww3@riverweb.com>
 *
 */

inherit "roxenlib";

constant module_name="Default Checkout Module";
constant module_type="checkout";


mapping query_tag_callers2();
mapping query_container_callers2();

/*

  currency_convert

  v is price

*/

mixed currency_convert(mixed v, object id){
  float exchange=3.0;
  float customs=2.0;
  float our_fee=3.0;

  // calculate the exchange rate...
  v=( exchange * (float)v);
  v+=( (customs*(float)v) + (our_fee*(float)v) );
  return v;
}


string tag_shipping(string tag_name, mapping args,
		     object id, mapping defines) {
string retval;
 if(!id->misc->ivend->lineitems) 
   id->misc->ivend+= (["lineitems":([])]);

return retval;
}


string tag_confirmemail(string tag_name, mapping args,
		     object id, mapping defines) {
if(!args->field) 
  return "";
else if(Commerce.Sendmail.check_address(id->variables[lower_case(args->field)]))
  return "";
else id->misc->ivend->error+=
	"You have provided an invalid email address.";

return "";

}

string tag_confirmorder(string tag_name, mapping args,
		     object id, mapping defines) {

  string retval="";

  object s=Sql.sql(
    id->misc->ivend->config->dbhost,
    id->misc->ivend->config->db,
    id->misc->ivend->config->dblogin,
    id->misc->ivend->config->dbpassword
    );   

// reserve the next order for me please...

  s->query("INSERT INTO orders VALUES(NULL,0,NULL,0,NULL,NULL,NOW())");
  id->misc->ivend->orderid=s->master_sql->insert_id(); // mysql only


// get the order from sessions

  array r=s->query("SELECT sessions.*,products.price, products.taxable from sessions,products  WHERE sessionid='"
	+id->misc->ivend->SESSIONID+ "' and products.id=sessions.id");

// replace sessionid with orderid
string query;

mixed error= catch{  for(int i=0; i<sizeof(r); i++){

    r[i]->orderid=id->misc->ivend->orderid;
    r[i]->status=0;
    if(args->currency_convert && functionp(currency_convert))
       r[i]->price=currency_convert((float)r[i]->price, id);
    m_delete(r[i], "sessionid");    
    m_delete(r[i], "timeout");
    query=iVend.db()->generate_query(r[i], "orderdata", s);
    s->query(query);
  }
} ;
if(!error)
s->query("DELETE FROM sessions WHERE sessionid='"+id->misc->ivend->SESSIONID+"'");

else {
  id->misc->ivend->error+="ERROR MOVING ORDER TO CONFIRMED STATUS!";
  return "An error occurred while moving your order to confirmed status.\n";
}
// update customer info and payment info with new orderid
    
  s->query("UPDATE customer_info SET orderid='"+
	id->misc->ivend->orderid+"' WHERE orderid='"
	+id->misc->ivend->SESSIONID+"'");

  s->query("UPDATE payment_info SET orderid='"+
	id->misc->ivend->orderid+"' WHERE orderid='"
	+id->misc->ivend->SESSIONID+"'");

  s->query("UPDATE lineitems SET orderid='" +
	id->misc->ivend->orderid+"' WHERE orderid='"
	+id->misc->ivend->SESSIONID+"'");

// do we send a confirmation note? if so, do it.

string note;
note=Stdio.read_file(id->misc->ivend->config->root+"/notes/confirm.txt");
if(note) {

  string subject,sender, recipient;
  sscanf(note, "%s\n%s\n%s\n%s", sender, recipient, subject, note);
  array r=s->query("SELECT " + recipient + " from customer_info WHERE "
		   "orderid='"+id->misc->ivend->orderid+"' AND "
		   "type=0");
  recipient=r[0][recipient];
  note=replace(note,"#orderid#",(string)id->misc->ivend->orderid);
  
  object message=MIME.Message(note, (["MIME-Version":"1.0",
				     "To":recipient,
				     "Subject":subject
				     ]));


  if(!Commerce.Sendmail.sendmail(sender, recipient, (string)message))
   perror("Error sending confirmation note for " +
	id->misc->ivend->st + "!\n");

}

// do we send an order notification? if so, then do it.

note=Stdio.read_file(id->misc->ivend->config->root+"/notes/notify.txt");
if(note) {

  string subject,sender, recipient;
  sscanf(note, "%s\n%s\n%s\n%s", sender, recipient, subject, note);

  note=replace(note,"#orderid#",(string)id->misc->ivend->orderid);
  
  object message=MIME.Message(note, (["MIME-Version":"1.0",
				     "To":recipient,
				     "Subject":subject
				     ]));


  if(!Commerce.Sendmail.sendmail(sender, recipient, (string)message))
   perror("iVend: Error sending order notification for " 
	+ id->misc->ivend->st + "!\n");

}


return retval;
}


string tag_discount(string tag_name, mapping args,
		     object id, mapping defines) {

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

if(args->convert && functionp(currency_convert) ) {
    tdiscount=currency_convert(tdiscount,id) ;
    ntdiscount=currency_convert(ntdiscount,id) ;
    }


return sprintf("%.2f", tdiscount + ntdiscount);

}


/*

  calculate tax

*/

string tag_salestax(string tag_name, mapping args,
		     object id, mapping defines) {

array r;		// result from query
string query;		// the query
float totaltax;		// totaltax
string locality;	// fieldname of locality

locality=(args->locality||"state");

  object s=Sql.sql(
    id->misc->ivend->config->dbhost,
    id->misc->ivend->config->db,
    id->misc->ivend->config->dblogin,
    id->misc->ivend->config->dbpassword
    );

query=
"select " + locality + " from customer_info where orderid='"+
	id->misc->ivend->SESSIONID +"'";
r=s->query(query);

if(!r) perror("iVend: ERROR locating customerinfo!\n");

else { 

  query=
  "select taxrate from taxrates where locality='"+ r[0][locality] + "'";

  r=s->query(query);
  if(sizeof(r)==1) {
    totaltax=(float)r[0]->taxrate *
      (id->misc->ivend->lineitems->taxable || 0.00);
 if(!id->misc->ivend->lineitems) 
   id->misc->ivend+= (["lineitems":([])]);
    id->misc->ivend->lineitems+=(["salestax":(float)totaltax]);
if(args->convert && functionp(currency_convert) ) {
    totaltax=currency_convert(totaltax,id) ;
    }
	
      return sprintf("%.2f",(float)totaltax);

  }
  else {
 if(!id->misc->ivend->lineitems) id->misc->ivend+=(["lineitems":([])]);
    id->misc->ivend->lineitems+=(["salestax":0.00]);
    return ("0.00");
  }
}
 if(!id->misc->ivend->lineitems) id->misc->ivend+=(["lineitems":([])]);
id->misc->ivend->lineitems+=(["salestax":0.00]);
return ("0.00");

}

string tag_generateform(string tag_name, mapping args,
		     object id, mapping defines) {
 object s=(object)iVend.db(
    id->misc->ivend->config->dbhost,
    id->misc->ivend->config->db,
    id->misc->ivend->config->dblogin,
    id->misc->ivend->config->dbpassword
    );

string retval="";
if(!args->table) return "";

 retval+=s->generate_form_from_db(args->table,
    ((
 
      (( (args->exclude||" ")-" ")/",")
       ||({}))
        + 
     ( (
      ((args->hide||" ")-" ") /",")
      ||({})) 
     ),id)+
        "<input type=hidden name=table value=\""+args->table+"\">";
retval+="<input type=hidden name=aeexclude value=\""+((args->exclude||" ")-" ")
  + "\">\n";
return retval;
}

string tag_addentry(string tag_name, mapping args,
		     object id, mapping defines) {

if(id->misc->ivend->error) return "";
if((int)id->variables->shipsame==1) return "";

 object s=iVend.db(
    id->misc->ivend->config->dbhost,
    id->misc->ivend->config->db,
    id->misc->ivend->config->dblogin,
    id->misc->ivend->config->dbpassword
    );

mixed j;

 if(id->variables->aeexclude){
   array aeexclude=id->variables->aeexclude /",";
   string exclude;
   foreach(aeexclude, exclude) {
     id->variables[exclude]="N/A";
   }
   m_delete(id->variables, "aeexclude");
 }

 if(args->encrypt){
object encryptedid = id;

  string key=Stdio.read_file(id->misc->ivend->config->keybase+".pub");

array e=(args->encrypt-" ")/",";
 for(int i=0; i<sizeof(e); i++){

  encryptedid->variables[lower_case(e[i])]=
    Commerce.Security.encrypt(id->variables[lower_case(e[i])],key);
 }

 j=s->addentry(encryptedid);

 }

else
  j=s->addentry(id);
    
if(j!=1) id->misc->ivend->error+= "<font size=+2>Error!</font>\n"
	   "<br><b>Please correct the following before continuing:<p></b><ul>"
	+j+"</ul>";

return "";


}

string tag_cardcheck(string tag_name, mapping args,
		     object id, mapping defines) {

if(Commerce.CreditCard.cc_verify(
    id->variables[args->cardnumber] ||
    id->variables->Card_Number,
    id->variables[args->cartype] ||
    id->variables->Payment_Method)
    || !Commerce.CreditCard.expdate_verify(id->variables[args->expdate]
	      || id->variables->Expiration_Date))

id->misc->ivend->error+=
  "You have supplied improper credit card information!<p>"
  "Please go back and correct this before continuing.";

return "";
}

mixed checkout(object id){

string retval=
  Stdio.read_file(id->misc->ivend->config->root +
    "/checkout/checkout_"+ (id->variables["_page"] || "1") +
    ".html");

if(!retval) return "error loading " + id->misc->ivend->config->root +
  "/checkout/checkout_"+ (id->variables["_page"] || "1") + 
  ".html" ;    

retval=parse_rxml(retval,id);

return retval;

}


string tag_subtotal(string tag_name, mapping args,
		     object id, mapping defines) {

float subtotal;

subtotal=(float)id->misc->ivend->lineitems->taxable + 
	(float)id->misc->ivend->lineitems->nontaxable;

if(args->convert && functionp(currency_convert) ) {
    subtotal=currency_convert(subtotal,id) ;
    }


return sprintf("%.2f", subtotal);



}

string tag_grandtotal(string tag_name, mapping args,
		     object id, mapping defines) {

 object s=(object)Sql.sql(
    id->misc->ivend->config->dbhost,
    id->misc->ivend->config->db,
    id->misc->ivend->config->dblogin,
    id->misc->ivend->config->dbpassword
    );


float grandtotal=0.00;
string item;
 foreach(indices(id->misc->ivend->lineitems), item) {
   grandtotal+=id->misc->ivend->lineitems[item];
   float i= id->misc->ivend->lineitems[item];
   if(args->convert && functionp(currency_convert) ) {
	i=currency_convert(i, id);
	}
   s->query("INSERT INTO lineitems VALUES('"+ id->variables->orderid + 
	"','" + item + "',"+ i + ")");
  }
   if(args->convert && functionp(currency_convert) ) {
  return(sprintf("%.2f",(float)currency_convert(grandtotal,id))) ;
   }
else return sprintf("%.2f",(float)grandtotal);

}

string tag_showorder(string tag_name, mapping args,
		     object id, mapping defines) {
float taxable=0.00;
float nontaxable=0.00;
string retval="";

 object s=Sql.sql(
    id->misc->ivend->config->dbhost,
    id->misc->ivend->config->db,
    id->misc->ivend->config->dblogin,
    id->misc->ivend->config->dbpassword
    );

string query="SELECT sessions.quantity, "
  "products.name, products.price, "
  "sessions.quantity*products.price AS linetotal, taxable FROM "
  "sessions,products WHERE products.id=sessions.id AND "
  "sessions.sessionid='" + id->misc->ivend->SESSIONID + "'";

array r=s->query(query);
 for(int i=0; i < sizeof(r); i++) {
   retval+="<tr><td align=right>" + r[i]->quantity + "</td>\n"
     "<td>"+ r[i]->name + "</td>\n"
     "<td align=right>";

   if(args->convert && functionp(currency_convert) ) {
  retval+=sprintf("%.2f",(float)currency_convert(r[i]->price,id)) ;
   }
else retval+=r[i]->price;
   retval+= "</td>\n"
     "<td align=right>";
   if(args->convert && functionp(currency_convert) ) {
  retval+=sprintf("%.2f",(float)currency_convert(r[i]->linetotal,id)) ;
   }
else retval+=r[i]->linetotal;
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
mapping tags,containers;
if(functionp(query_tag_callers2))
 tags=query_tag_callers2();
if(functionp(query_container_callers2))
  containers=query_container_callers2();
string h;

if(id->variables["_page"])
    id->misc->ivend->next_page= (int)id->variables["_page"]+1;

contents="<form action=\"" + id->not_query + "\">\n<input type=hidden name=_page "
  "value=" + (id->misc->ivend->next_page || "2") + ">\n"
  +contents+ "</form>\n";

contents=parse_html(contents,
		  tags,
		  containers,
		  id);

 if(id->misc->ivend->error) return 
	"<b>An error occurred while processing your request.</b><p>" 
	"Please review the cause of this error and go back to correct it:<p>" 
	+ (id->misc->ivend->error[1..]);
else return contents;
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















