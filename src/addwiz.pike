
inherit "wizard";

constant name= "Add New Store...";
 

#define ERROR(X) id->misc->wizerr=X;
#define IFERROR (id->misc->wizerr?"<tr><td colspan=2><b>Error: "+id->misc->wizerr+"</b></td></tr>":"")

string|int page_0(object id){

 return "<table width=95%>"
  + IFERROR +
"<tr><td>Store Name &nbsp</td><td> "
" <var type=\"string\" name=\"_name\"></td></tr>"
"<help><tr><td colspan=2>"
"Short Description of Store.</td></tr>"
"</help>"
"<tr><td>Store ID &nbsp </td><td> "
" <var type=\"string\" name=\"config\"></td></tr>"
"<help><tr><td colspan=2>"
"One word used to uniquely identfy this store."
"</td></tr></help></table>"
;
}

string|int verify_1(object id) {

if(catch(Sql.sql(id->variables->dbhost, id->variables->db, 
  id->variables->dblogin, id->variables->dbpassword))) {

  ERROR("Unable to connect to database. Please verify connection setup.");
  return 1;
  }
return 0;

}

string|int verify_0(object id) {

if(search(id->variables->config, " ")!=-1 || id->variables->config=="") {

  ERROR("You may not have spaces in your Store ID.");
  return 1;

  }
if(mappingp(id->misc->ivend->this_object->config[id->variables->config]))
  {
  ERROR("That config name has already been taken.");
  return 1;
  }
return 0;

}

string|int verify_2(object id) {
mixed fs=file_stat(id->variables->root);
if(!fs || fs[1]!=-2) {	// not a directory
  if(id->variables->createdir=="0"){
  ERROR("Unable to find the specified directory. To create this directory, check the 'create directory' checkbox.");
  return 1;
  }
  else
    return 0;


  }

return 0;

}

string|int page_1(object id){
 return "<table width=95%>\n"
   + IFERROR +
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
"<tr><td>DB Name &nbsp "
"</td><td> <var type=\"string\" name=\"db\" value=\"\">"
"</td></tr><help>"
"<tr><td colspan=2>Name of the Database containing Store data.</td>"
"</tr></help></table>"
;
}

string|int page_2(object id){
 return "<table width=95%>\n"
  + IFERROR + "<tr><td>"
"Store Root &nbsp</td><td> "
" <var type=\"string\" name=\"root\" value=\"\"></td></tr>"
"<help><tr><td colspan=2>"
"Location (in real filesystem) of Store Datafiles.</td></tr>"
"</help>"
"<tr><td>"
"Create Directory? &nbsp; </td><td>"
" <var type=\"checkbox\" name=\"createdir\" value=\"yes\"></td></tr>"
"<p><help>"
"<tr><td colspan=2>Create this directory if it doesn't already exist?</td></tr>"
"</table>";
}

string|int page_3(object id){
 return "<table width=95%>"
 + IFERROR +
"<tr><Td>Session Timeout &nbsp</td><td> "
" <var type=\"string\" name=\"session_timeout\" value=\"3600\"></td></tr>"
"<help><tr><td colspan=2>"
"Number of seconds before a session is cleared from database."
"</td></tr></help>"
"</table>"
;
}

array getstyles(object id){

array s=get_dir(id->misc->ivend->this_object->query("root") +
	"/examples");
s=s-({"CVS","README"});
return s;
}

string|int page_4(object id){
 return "<table width=95%>\n" + IFERROR +
  "<tr><td>Store Style &nbsp; </td><td><var name=\"style\" type=\"select\"" 
  " options=\""+ (getstyles(id)*",") + "\"></td></tr>"
  "<help><tr><td colspan=2>Select the store template style you wish to "
  "use for the creation of this store.</td></tr></help>\n"
  "<tr><td>Copy template files? &nbsp;</td><td><var name=copyfiles "
  "type=checkbox value=yes></td></tr>"
  "<help><tr><td colspan=2>Copy files into this store "
  "directory?</td></tr></help>"
  "</table>";
}

string|int page_5(object id){
mapping v=id->variables;
string retval="Click OK to perform the following tasks:<p>\n<ul>";
retval+="<li>Create the iVend store <i>" + v->_name + "</i>.\n";
mixed fs=file_stat(v->root);
if(!fs || fs[1]!=-2)	// not a directory
  retval+="<li>Create the directory <i>" + v->root + "</i>\n";
v->copyfiles-="\0000";
if(v->copyfiles=="yes")
  retval+="<li>Install store  templates for " + capitalize(v->style) +", overwriting existing files.\n";
// if((int)v->overwrite)
// else retval+=" preserving existing files.\n";
if(file_stat(v->root + "/schema.mysql"))
  retval+="<li>Setup Database tables for this store.\n";
if(!file_stat(v->root +"/private/key.pub"))
  retval+="<li>Generate 2048 bit RSA Keypair.\n";
retval+="</ul>";

return retval;
}

int write_file(string filename,string what)
{
  int ret;
  object f = Stdio.File();

  if(!f->open(filename,"twc"))
    throw( ({ "Couldn't open file "+filename+".\n", backtrace() }) );
  
  ret=f->write(what);
  f->close();
  return ret;
}


string * generate_keys(int key_size){

 object rsa = Crypto.rsa();
  rsa->generate_key(key_size,
Crypto.randomness.reasonably_random()->read);

  string privkey = Tools.PEM.simple_build_pem
    ("RSA PRIVATE KEY",
     Standards.PKCS.RSA.rsa_private_key(rsa));

  string pubkey = Tools.PEM.simple_build_pem
    ("RSA PUBLIC KEY",
     Standards.PKCS.RSA.rsa_public_key(rsa));



//  werror(privkey);
//  werror(pubkey);

return ({privkey, pubkey});

}

void write_keys(string name)

{


  string * key = generate_keys(2048);

  write_file(name + ".priv", key[0]);
  write_file(name + ".pub", key[1]);

  return;
}


string wizard_done(object id){
mapping v=id->variables;
v->copyfiles-="\0000";

if(v->createdir && !file_stat(v->root)) mkdir(v->root);
// if((int)v->overwrite) 
if(v->copyfiles=="yes")
mixed result=Process.system("/bin/cp -rf " +
   id->misc->ivend->this_object->query("root") + "examples/" +
   v->style +"/* " + v->root);
// else mixed result=Process.system("/bin/cp -r  " +
//   id->misc->ivend->this_object->query("root") + "examples/" +
//   v->style + "/* " + v->root);

if(file_stat(v->root + "/schema.mysql")){

  array ss=Stdio.read_file(v->root +  "/schema.mysql")/";\n";
  if(catch(object s=Sql.sql(id->variables->dbhost, id->variables->db, 
    id->variables->dblogin, id->variables->dbpassword))) {
    return "An error occurred while connecting to the store database.";
    }

  foreach(ss, string statement)
      if(catch(s->query(statement)))
  //      return statement
  ;
}

mkdir(v->root + "/private");

if(!file_stat(v->root +"/private/key.pub"))
  write_keys(v->root + "/private/key");

v->publickey=v->root+ "/private/key.pub";
v->privatekey=v->root + "/private/key.priv";
v->name=v->_name;

m_delete(v, "_page");
m_delete(v, "_state");
m_delete(v, "ok");
m_delete(v, "action");
m_delete(v, "_name");
m_delete(v, "createdir");
m_delete(v, "copyfiles");
m_delete(v, "style");


    array(string) variables= indices(v);

           v->config=lower_case(v->config);
      id->misc->ivend->this_object->config[v->config]= (["general":([])]);

    for(int i=0; i<sizeof(variables); i++)
id->misc->ivend->this_object->config[v->config]["general"]+=([variables[i]:v[variables[i]]]);

   if(!id->misc->ivend->this_object->global->configurations){
       id->misc->ivend->this_object->global->configurations=([]);
       id->misc->ivend->this_object->global->configurations->active=({});
                                 }
 else if(!arrayp(id->misc->ivend->this_object->global->configurations->active))
   id->misc->ivend->this_object->global->configurations->active=({id->misc->ivend->this_object->global->configurations->active});

id->misc->ivend->this_object->global->configurations->active+=({v->config});

                              id->misc->ivend->this_object->save_status=0;

// return sprintf("%O\n", result);

return 0;
}

