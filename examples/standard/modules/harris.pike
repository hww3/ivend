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

if(id->variables["_page"]=="2"){
  retval+="<form action=.><table>\n";
  retval+=s->generate_form_from_db("customer_info", ({"id","updated"}));
  retval+="</table></form>\n";

  }

else
  retval+="<icart fields=\"qualifier\"></icart>"
	"<form action=checkout><input type=hidden name=\"_page\" value=2>"
	"<input type=hidden name=SESSIONID value=\""+id->variables->SESSIONID+"\">"
	"<input type=submit value=\"Continue\"></form>";

retval=parse_rxml(retval,id);

return retval;

}
