/*
 * harris.pike: checkout module for iVend.
 *
 * Bill Welliver <hww3@riverweb.com>
 *
 */

mixed checkout(object id){

string retval="";

  object s=iVend.db(
    id->misc->ivend->config->dbhost,
    id->misc->ivend->config->db,
    id->misc->ivend->config->user,
    id->misc->ivend->config->password
    );

retval+="<form action=.><table>\n";
retval+=s->generate_form_from_db("customer_info", ({"id","updated"}));
retval+="</table></form>\n";
return retval;
}
