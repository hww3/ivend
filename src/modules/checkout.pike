/*
 * default.pike: checkout module for iVend.
 *
 * Bill Welliver <hww3@riverweb.com>
 *
 */

inherit "roxenlib";

constant module_name="Default Checkout Module";
constant module_type="checkout";


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

/*

  calculate tax

*/

string tag_salestax(string tag_name, mapping args,
		     object id, mapping defines) {

array r;		// result from query
string query;		// the query
float totaltax;		// totaltax
string locality;	// fieldname of locality

locality="state";

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
  "select sessions.sessionid, SUM(products.price*sessions.quantity) "
  "as grandtotaltaxable, taxrates.taxrate as taxrate, "
  "SUM(products.price*sessions.quantity)*taxrates.taxrate as "
  "salestax from sessions, products, taxrates where "
  "(sessions.id=products.id and taxrates.locality='"+ r[0][locality]
  +"' and SESSIONID='"+ id->misc->ivend->SESSIONID +"')";
perror(query+"\n");
  r=s->query(query);
  if(sizeof(r)==1 && r[0]->salestax) {
 if(!id->misc->ivend->lineitems) 
   id->misc->ivend+= (["lineitems":([])]);


    id->misc->ivend->lineitems+=(["salestax":(float)r[0]->salestax]);
    if(args->convert && functionp(currency_convert))
      return sprintf("%.2f",currency_convert((float)r[0]->salestax,id));
    else
      return sprintf("%.2f",(float)r[0]->salestax);

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


mixed checkout(object id){

string retval="<title>checkout</title><body bgcolor=white text=navy>"
		"<font face=helvetica>";

  object s=iVend.db(
    id->misc->ivend->config->dbhost,
    id->misc->ivend->config->db,
    id->misc->ivend->config->dblogin,
    id->misc->ivend->config->dbpassword
    );

int page;

 if(id->variables["_page"]=="5"){

/*
if(Commerce.CreditCard.cc_verify(id->variables->Card_Number,id->variables->Payment_Method)
    || !Commerce.CreditCard.expdate_verify(id->variables->Expiration_Date))

return "You have supplied improper credit card information!<p>"
	"Please go back and correct this before continuing.";

else */
 {

  perror("reading "+id->misc->ivend->config->keybase+".pub");
  string key=Stdio.read_file(id->misc->ivend->config->keybase+".pub");
  id->variables->Card_Number=
    Commerce.Security.encrypt(id->variables->Card_Number,key);
}

  {
  mixed j=s->addentry(id);
    if(j!=1) return retval+ "<font size=+2>Error!</font>\n"
	   "<br><b>Please correct the following before continuing:<p></b><ul>"
	+j+"</ul>";

  retval+="<font size=+2>5. Confirm Order</font>\n"
  	"<form action="+id->not_query+"><table>\n"
	"<tr><th align=left>Quantity</th><th align=left>Product Name</th>"
	"<th align=left>Unit Price</th><th align=left>Subtotal</th></tr>"
	"<showorder convert>\n";	
  


  retval+="<tr></td></td><td></td><td></td><td align=right>"
    "Subtotal:</td><td align=right><subtotal convert></td></tr>\n"
    "<tr></td></td><td></td><td></td><td align=right>"
    "Sales Tax:</td><td align=right><salestax convert></td></tr>\n"
    "<tr></td></td><td></td><td></td><td align=right>"
    "Grand Total:</td><td align=right><grandtotal convert>"
	"</table>\n";
  }
}
else if(id->variables["_page"]=="4"){
   if((string)id->variables->shipsame=="1");
   else { mixed j=s->addentry(id);
   if(j!=1) return retval+ "<font size=+2>Error!</font>\n"
	   "<br><b>Please correct the following before continuing:<p></b><ul>"
	+j+"</ul>";
	}
  retval+="<font size=+2>4. Payment Information</font>\n"
  	"<form action="+id->not_query+"><table>";
  retval+=s->generate_form_from_db("payment_info",
    ({"orderid","type"}),id);

  retval+="</table>\n"
        "<input type=hidden name=table value=payment_info>"
	"<input type=submit value=\" >> \">"
        "<input type=hidden name=orderid value="+id->misc->ivend->SESSIONID+">"
	"<input type=hidden name=_page value=5></form>\n";

 }

else if(id->variables["_page"]=="3"){

  mixed j=s->addentry(id);
   if(j!=1) return retval+ "<font size=+2>Error!</font>\n"
	   "<br><b>Please fix the following before continuing:<p></b><ul>"+
	j+"</ul>";
  retval+="<font size=+2>3. Shipping Address</font>\n"
  	"<form action="+id->not_query+">";
  retval+="Is this order to be shipped to the Billing address?\n"
	"<select name=shipsame>"
	"<option value=1>Yes\n<option value=0>No\n</select>"
	"<p>If not, complete the following information:<br><table>\n";
  retval+=s->generate_form_from_db("customer_info",
    ({"orderid","type","updated", "fax","daytime_phone",
	"evening_phone", "email_address"}),id);
  retval+="</table>"
        "<input type=hidden name=orderid value="+id->misc->ivend->SESSIONID+">"
	"<input type=hidden name=type value=1>"
        "<input type=hidden name=table value=customer_info>"
	"<input type=submit value=\"  >> \">"
	"<input type=hidden name=_page value=4></form>\n";

  }

else if(id->variables["_page"]=="2"){
  retval+="<font size=+2>2. Billing Address</font>\n";
  retval+="<form action="+id->not_query+"><table>\n";
  retval+=s->generate_form_from_db("customer_info",
({"orderid","type","updated"}),id);
  retval+="</table>"
	"<input type=hidden name=type value=0>"	
        "<input type=hidden name=orderid value="+id->misc->ivend->SESSIONID+">"
       "<input type=hidden name=table value=customer_info>" 
       "<input type=submit value=\" >> \">"
	"<input type=hidden name=_page value=3></form>\n";
  }

else {
  retval+="<font size=+2>1. Confirm Cart</font>\n";
  retval+="<icart fields=\"qualifier\"></icart>"
	"<form action=checkout><input type=hidden name=_page value=2>"
	"<input type=submit value=\" >> \"></form>";
  }
retval="<ivml>"+retval+"</ivml>";
retval=parse_rxml(retval,id);

return retval;

}


string tag_subtotal(string tag_name, mapping args,
		     object id, mapping defines) {

   if(args->convert && functionp(currency_convert) ) {
     perror("converting currency...\n");
  return(sprintf("%.2f",
    (float)currency_convert(id->misc->ivend->lineitems->subtotal,id))) ;
   }
else return sprintf("%.2f",
    (float)id->misc->ivend->lineitems->subtotal);



}

string tag_grandtotal(string tag_name, mapping args,
		     object id, mapping defines) {

float grandtotal=0.00;
string item;
 foreach(indices(id->misc->ivend->lineitems), item)
   grandtotal+=id->misc->ivend->lineitems[item];


   if(args->convert && functionp(currency_convert) ) {
     perror("converting currency...\n");
  return(sprintf("%.2f",(float)currency_convert(grandtotal,id))) ;
   }
else return sprintf("%.2f",(float)grandtotal);

}

string tag_showorder(string tag_name, mapping args,
		     object id, mapping defines) {
float subtotal=0.00;
string retval="";

 object s=Sql.sql(
    id->misc->ivend->config->dbhost,
    id->misc->ivend->config->db,
    id->misc->ivend->config->dblogin,
    id->misc->ivend->config->dbpassword
    );

string query="SELECT sessions.quantity, "
  "products.name, products.price, "
  "sessions.quantity*products.price AS linetotal FROM "
  "sessions,products WHERE products.id=sessions.id AND "
  "sessions.sessionid='" + id->misc->ivend->SESSIONID + "'";

perror("QUERY:\n\n"+query+"\n\n");

array r=s->query(query);
perror("sizeof result: "+sizeof(r)+"\n");
 for(int i=0; i < sizeof(r); i++) {
   retval+="<tr><td align=right>" + r[i]->quantity + "</td>\n"
     "<td>"+ r[i]->name + "</td>\n"
     "<td align=right>";

   if(args->convert && functionp(currency_convert) ) {
     perror("converting currency...\n");
  retval+=sprintf("%.2f",(float)currency_convert(r[i]->price,id)) ;
   }
else retval+=r[i]->price;
   retval+= "</td>\n"
     "<td align=right>";
   if(args->convert && functionp(currency_convert) ) {
     perror("converting currency...\n");
  retval+=sprintf("%.2f",(float)currency_convert(r[i]->linetotal,id)) ;
   }
else retval+=r[i]->linetotal;
subtotal+=(float)r[i]->linetotal;
retval+= "</td></tr>\n"; 
 }


 if(!id->misc->ivend->lineitems) id->misc->ivend+=(["lineitems":([])]);
id->misc->ivend->lineitems+=(["subtotal":(float)subtotal]);


return retval;

}





mapping query_tag_callers() {

return (["showorder" : tag_showorder,
	"grandtotal" : tag_grandtotal,
	"subtotal" : tag_subtotal,
	  "salestax" : tag_salestax 
	]);

}

mapping query_container_callers() {

return ([]);

}



















