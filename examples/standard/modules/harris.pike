/*
 * harris.pike: checkout module for iVend.
 *
 * Bill Welliver <hww3@riverweb.com>
 *
 */

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
if(id->variables->page) page=id->variables->page+1;
else page=1;
if(!id->variables->page){

  retval+="<icart fields=\"qualifier\"></icart>";
  }
else if(id->variables->page==2){
  retval+="<form action=.><table>\n";
  retval+=s->generate_form_from_db("customer_info", ({"id","updated"}));
  retval+="</table></form>\n";
  return retval;
  }

retval=parse_rxml(retval,id);
retval=replace(retval,({"</form>","</FORM>"}),
  ({
  "<input type=hidden name=page value="+page+"</form>",
  "<input type=hidden name=page value="+page+"</form>"
  }));

return retval;

}
