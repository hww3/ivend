inherit "wizard";

constant name= "Delete Store...";
 

#define ERROR(X) id->misc->wizerr=X;
#define IFERROR (id->misc->wizerr?"<tr><td colspan=2><b>Error: "+id->misc->wizerr+"</b></td></tr>":"")

string|int page_0(object id){
string retval="";
retval+= "<table width=95%>"
  + IFERROR +
"<tr><td>Store Name &nbsp</td><td> "
" <var type=\"select\" name=\"_name\" options=\"";

array n=({});

foreach(indices(id->misc->ivend->this_object->config), string c)
  if(c=="global") continue;
  else n+=({ id->misc->ivend->this_object->config[c]->general->name});

retval+=(n*",");

retval+="\"></td></tr>"
"<help><tr><td colspan=2>"
"Select the store you would like to delete.</td></tr>"
"</help>"
"</table>"
;
return retval;
}

string|int verify_0(object id) {
if(id->variables->_name=="") {
 ERROR("You must choose a store.");
 return 0;
}
// string c;
foreach(indices(id->misc->ivend->this_object->config), string c){

if(id->misc->ivend->this_object->config[c]->general->name==id->variables->_name) {
    id->variables->__name=c;
  id->variables->dbhost=id->misc->ivend->this_object->config[c]->general->dbhost;
  }
}


return 0;

}

string|int verify_1(object id) {
object s;
if(catch(s=Sql.sql(id->variables->dbhost, id->variables->db, 
  id->variables->dblogin, id->variables->dbpassword))) {

  ERROR("Unable to connect to database. Please verify connection setup.");
  return 1;
  }
else {

  string v=s->server_info();

  if(v[0..4]!="mysql"){
   ERROR("You must be running mySQL to use this Wizard.");
   return 1;
   }
  else {
    int major,minor=0;
    sscanf(v, "%*s/%d.%d.%*s", major, minor);
    if(major<3 || (major=3 && minor<22)) {
      ERROR("You must be running mySQL 3.22 or higher to use this Wizard.");
      return 1;
      }
  }
}
return 0;

}


string|int page_1(object id){

 return "<table width=95%>\n"
   + IFERROR +
"<tr><td colspan=2>Please provide the logon credentials for a "
"user authorized to perform database drops for your database "
"server.</td></tr>"
"<tr><td>DB Host &nbsp</td><td> "
" <var type=\"string\" name=\"dbhost\" value=\"\"></td></tr>"
"<help><tr><td colspan=2>"
"Hostname of SQL Database Server.</td></tr>"
"</help>"
"<tr><td>DB User &nbsp</td><td> "
" <var type=\"string\" name=\"dblogin\" value=\"\"></td></tr>"
"<help><tr><td colspan=2>"
"Username with access permissions to Database."
"</td></tr></help>"
"<tr><td>DB Password &nbsp </td>"
"<td> <var type=\"password\" name=\"dbpassword\" value=\"\"></td></tr>"
"<help><tr><td colspan=2>"
"Password for DB User.</td></tr>"
"</help>"
"</table>"
;
}

string|int page_2(object id){
 return "<table width=95%>\n"
  + IFERROR + "<tr><td>"
"<tr><td>"
"Delete store directory? &nbsp; </td><td>"
" <var type=\"select\" name=\"deletedir\" Options=\"Yes,No\"></td></tr>"
"<p><help>"
"<tr><td colspan=2>Delete this store's directory, and all the files "
"contained therein?</td></tr>"
"</help>"
"</table>";
}

string|int page_3(object id){
 return "<table width=95%>"
 + IFERROR +
"<tr><Td>Delete Store Database? &nbsp</td><td> "
" <var type=\"select\" name=\"deletedb\" options=\"Yes,No\"></td></tr>"
"<help><tr><td colspan=2>"
"Should the Store Database be deleted as well?"
"</td></tr></help>"
"</table>"
;
}

string|int page_4(object id){
mapping v=id->variables;
string retval="Click OK to perform the following tasks:<p>\n<ul>";
retval+="<li>Delete the iVend store <i>" + v->_name + "</i>.\n";
if(v->deletedir=="Yes")
  retval+="<li>Delete the directory <i>" +
id->misc->ivend->this_object->config[v->__name]->general->root + "</i>\n";
if(v->deletedb=="Yes")
  retval+="<li>Delete the Database <i>" + v->__name + "</i>"; 
retval+="</ul>";

return retval;
}


string wizard_done(object id){
mapping v=id->variables;
mapping general=id->misc->ivend->this_object->config[id->variables->__name]->general;
string retval="";
object privs;

object s;

  if(catch(s=Sql.sql(v->dbhost, 0, 
    v->dblogin, v->dbpassword))) {
    return "An error occurred while connecting to the database server "
	"as db administrator.";
    }

if(v->deletedb=="Yes"){

catch(s->select_db(general->db));
catch(s->query("REVOKE ALL ON " + general->db + " FROM " + v->__name));
catch(s->query("REVOKE ALL ON " + general->db + " FROM " + v->__name +
"admin"));
if(catch(s->drop_db(general->db)))
  retval+= "An error occurred while dropping the store database. "
	"This usually means that either 1) the database doesn't exist, "
	"or 2) the db administrator account does not have permission to "
	"drop databases.<p>";
}
retval+="<b><font face=+1>Store Deleted Successfully.</b><p></font>";

if(v->deletedir=="Yes"){
privs=Privs("iVend: Deleting store files ");
mixed result=Process.system("/bin/rm -rf " + general->root);
privs=0;
}

m_delete(id->misc->ivend->this_object->config, v->__name);
if(stringp(id->misc->ivend->this_object->global->configurations->active))
  m_delete(id->misc->ivend->this_object->global->configurations,
"active");
if(arrayp(id->misc->ivend->this_object->global->configurations->active))
id->misc->ivend->this_object->global->configurations->active-=({v->__name});
id->misc->ivend->this_object->save_status=0;


return retval;
}

