/*
 * harris.pike: checkout module for iVend.
 *
 * Bill Welliver <hww3@riverweb.com>
 *
 */

inherit "roxenlib";

constant module_name="Harris Checkout Module";
constant module_type="checkout";

mixed checkout(object id){

string retval="";

  object s=iVend.db(
    id->misc->ivend->config->dbhost,
    id->misc->ivend->config->db,
    id->misc->ivend->config->user,
    id->misc->ivend->config->password
    );

int page;

if(id->variables["_page"]=="3"){

  

  retval+="<font size=+2>3. Shipping Address</font>\n"
  	"<form action="+id->not_query+">";
  retval+="Is this order to be shipped to the Billing address?\n"
	"<select name=shipsame>"
	"<option value=1>Yes\n<option value=0>No\n</select>"
	"<p>If not, complete the following information:<br><table>\n";
  retval+=s->generate_form_from_db("customer_info", ({"id","updated"}));
  retval+="</table>"
	"<input type=submit value=Continue>"
	"<input type=hidden name=_page value=4></form>\n";

  }

else if(id->variables["_page"]=="2"){
  retval+="<font size=+2>2. Billing Address</font>\n";
  retval+="<form action="+id->not_query+"><table>\n";
  retval+=s->generate_form_from_db("customer_info", ({"id","updated"}));
  retval+="</table>"
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
