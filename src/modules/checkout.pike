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

float calculate_tax(object id) {

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
  if(sizeof(r)==1 && r[0]->salestax)
    return r[0]->salestax;
  else return (0.00);
}

return (0.00);

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
	"<tr><th>Quantity</th><th>Description</th>"
	"<th>Unit Price</th><th>Subtotal</th></tr>"
	"<orderlines>\n";	
  


  retval+="<tr></td></td><td></td><td></td><td>Sales Tax:</td><td>$" +
	 sprintf("%.2f",(float)calculate_tax(id))+"</td></tr>"
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
retval="<ivml>blahblahblah"+retval+"</ivml>";
retval=parse_rxml(retval,id);

return retval;

}

