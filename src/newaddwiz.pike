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
"<tr><td colspan=2>Please provide the logon credentials for a "
"user authorized to perform database creation for your database "
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
"</help>"
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
"<tr><Td>Secure DB Permissions? &nbsp</td><td> "
" <var type=\"select\" name=\"secureperms\" options=\"Yes,No\"></td></tr>"
"<help><tr><td colspan=2>"
"Should DB access be secured to the iVend host only? Answer 'No' only if "
"you get db access errors while creating the store."
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
retval+="<li>Create the Database <i>" + v->config + "</i>"; 
retval+="<li>Create a database user, <i>" + v->config + 
  "</i>, which will be used to access the store data."; 
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
object privs=Privs("iVend: Writing Key File");
  if(!f->open(filename,"twc"))
    throw( ({ "Couldn't open file "+filename+".\n", backtrace() }) );
  
  ret=f->write(what);
  f->close();
privs=0;
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
string retval="";
object privs;

object s;

  if(catch(s=Sql.sql(id->variables->dbhost, 0, 
    id->variables->dblogin, id->variables->dbpassword))) {
    return "An error occurred while connecting to the database server "
	"as db administrator.";
    }

if(catch(s->create_db(v->config)))
  return "An error occurred while creating the store database. "
	"This usually means that either 1) the database already exists, "
	"or 2) the db administrator account does not have permission to "
	"create new databases.";
s->select_db(v->config);
string adminuser=(sizeof(v->config + "admin")<=16?(v->config +
  "admin"):(v->config + "admin")[0..15]);

string adminpassword=
makepw->make_password(id->misc->ivend->this_object->query("wordfile"), 8);

if(v->dbhost=="") v->dbhost=="localhost";
v->dblogin=v->config;
v->db=v->config;
string host=(lower_case(v->dbhost)=="localhost"?"localhost":gethostname());
 v->dbpassword=MIME.encode_base64((string)hash(ctime(time())))[0..7];
//perror(v->dbpassword + "\n");

s->query("GRANT SELECT, INSERT, UPDATE, DELETE, DROP, CREATE on " +
	v->config + ".* TO " + v->config + (v->secureperms=="Yes"?("@" +
host):"")); 

s->query("GRANT SELECT, INSERT, UPDATE, DELETE on " +
	v->config + ".* TO " + adminuser + (v->secureperms=="Yes"?("@" +
host):"") ); 

s->query("SET PASSWORD FOR " + v->config + (v->secureperms=="Yes"?("@\"" +
host + "\""):"") +  
	" = PASSWORD(\"" + v->dbpassword + "\")");
s->query("SET PASSWORD FOR " + adminuser + (v->secureperms=="Yes"?("@\"" +
host + "\""):"") + " = PASSWORD(\"" +
	adminpassword + "\")");

retval+="<b><font face=+1>Store Created Successfully.</b><p></font>"
  "Your store has been successfully created. Please make a note of the "
  "following information:<p>";

retval+= "<b>Admin User:</b> " + adminuser + "<br>\n"
  "<b>Admin Password:</b> " + adminpassword + "<br>\n"
  "<b>Data File Location</b>: " + v->root + "<br>\n";

retval+="<p>\nYou may edit $DATALOCATION/store_package "
  "to customize the overall look of your store.";

privs=Privs("iVend: Creating store directory");
if(v->createdir && !file_stat(v->root)) mkdir(v->root);
privs=0;

if(v->copyfiles=="yes"){
perror("copying store files...\n");
privs=Privs("iVend: Copying store files ");
mixed result=Process.system("/bin/cp -rf " +
   id->misc->ivend->this_object->query("root") + "examples/" +
   v->style +"/* " + v->root);
privs=0;
}

if(file_stat(v->root + "/schema.mysql")){

  array ss=Stdio.read_file(v->root +  "/schema.mysql")/"\\g\n";
  if(catch(object s=Sql.sql(id->variables->dbhost, v->config , 
    v->config, v->dbpassword))) {
    return "An error occurred while connecting to the store database" 
	"as " + v->config + " with password " + v->dbpassword + "."
	"<p>This is sometimes due to improper host table setup on "
	"the database host.";
    }
ss=ss[0..sizeof(ss)-2];
  foreach(ss, string statement)
      if(catch(s->query(statement)))
        return "A SQL Error occurred while processing this statement: " +
	  statement + "<p>" + s->error();
}



privs=Privs("iVend: Copying store files ");
mkdir(v->root + "/private");
privs=0;

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
m_delete(v, "secureperms");


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

return retval;
}

