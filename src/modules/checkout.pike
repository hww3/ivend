/*
 * default.pike: checkout module for iVend.
 *
 * Bill Welliver <hww3@riverweb.com>
 *
 */

inherit "roxenlib";

constant module_name="Default Checkout Module";
constant module_type="checkout";

mixed checkout(object id){

string retval="<title>checkout</title><body bgcolor=white text=navy>"
		"<font face=helvetica>";

  object s=iVend.db(
    id->misc->ivend->config->dbhost,
    id->misc->ivend->config->db,
    id->misc->ivend->config->user,
    id->misc->ivend->config->password
    );

int page;

 if(id->variables["_page"]=="5"){

if(!Commerce.CreditCard.cc_verify(id->variables->Card_Number,id->variables->Card_Type))
{

  retval+="card number okay...<p>";
  string key=Stdio.read_file(id->misc->ivend->config->keyfile+".pub");
  id->variables->Card_Number=
    Commerce.Security.encrypt(id->variables->Card_Number,key);
}

return "You have supplied an ivalid Credit Card Number!";

   if( Commerce.CreditCard.expdate_verify(id->variables->Expiration_Date))
 retval+="expdate okay...<p>";

  {
 //  mixed j=s->addentry(id);
 //  if(j!=1) return retval+ "<font size=+2>Error!</font>\n"
//	   "<br><b>Please correct the following before continuing:<p></b><ul>"
//	+j+"</ul>";

  retval+="yay...";
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
        "<input type=hidden name=table value=customer_info>"
	"<input type=submit value=Continue>"
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
	"<input type=submit value=Continue>"
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
       "<input type=submit value=Continue>"
	"<input type=hidden name=_page value=3></form>\n";
  }

else {
  retval+="<font size=+2>1. Confirm Cart</font>\n";
  retval+="<icart fields=\"qualifier\"></icart>"
	"<form action=checkout><input type=hidden name=_page value=2>"
	"<input type=submit value=\"Continue\"></form>";
  }

retval=parse_rxml(retval,id);

return retval;

}

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
