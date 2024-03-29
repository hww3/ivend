#!NOMODULE
inherit "wizard";

constant name= "Add New Store...";


#if __VERSION__ >= 0.6
import ".";
#endif 

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

string|int verify_2(object id) {
object s;
if(id->variables->create_db=="No" && id->variables->db==""){
  ERROR("You must supply a database name if you don't want to have one created.");
return 1;
}
 if(catch(s=Sql.sql(id->variables->dbhost)
))
 {

  ERROR("Unable to connect to database" + id->variables->dbhost + 
	". Please verify your connection setup.");
  return 1;
  }
else 
{
// perror( sprintf("<pre>%O</pre>", mkmapping(indices(s), values(s))));
if(functionp(s->server_info))
 {
  string v=s->server_info();
perror(v + "\n");
  if(v[0..4]!="mysql" && v[0..4]!="postg"){
   ERROR("You must be running mySQL or Postgres to use this Wizard.");
   return 1;
   }
  else if(v[0..4]=="mysql"){
    int major,minor=0;
    sscanf(v, "%*s/%d.%d.%*s", major, minor);
    if(major<3 || (major=3 && minor<22)) {
      ERROR("You must be running mySQL 3.22 or higher to use this Wizard.");
      return 1;
      }
   }
  }
}
return 0;

}

string|int verify_3(object id) {
mixed fs=file_stat(id->variables->root);
if(!fs || fs[1]!=-2) {	// not a directory
  if(id->variables->createdir=="No"){
  ERROR("Unable to find the specified directory. To create this directory, "
    "select 'Yes' for the 'create directory' option.");
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
"<tr><td colspan=2>This wizard can create a database for your store. "
"If you already have a database created, iVend can use that instead. "
"user authorized to perform database creation for your database "
"</td></tr>"
"<tr><td>Create Database? &nbsp</td><td> "
" <var type=\"select\" name=\"create_db\" options=\"Yes,No\"></td></tr>"
"<help><tr><td colspan=2>"
"Choose Yes if you want the wizard to create a database for you."
"Otherwise, choose no. You must have access to a database "
"administrator account in order to have iVend create the "
"database.</td></tr>"
"</help>"
"</table>";

}
string|int page_2(object id){
string retval= "<table width=95%>\n"
   + IFERROR;
if(id->variables->create_db=="Yes") retval+=
"<tr><td colspan=2>Please provide the logon credentials for a "
"user authorized to perform database creation for your database "
"server.</td></tr>"
"<tr><td>DB Host URL &nbsp</td><td> "
" <var type=\"string\" name=\"dbhost\" value=\"\"></td></tr>"
"<help><tr><td colspan=2>"
"SQL URL for Database server (do not specify a database).</td></tr>"
"</help>"
"</table>"
;

else retval+=
"<tr><td colspan=2>Please provide the logon and database information"
" for your store database.</td></tr>"
"<tr><td>DB URL &nbsp</td><td> "
" <var type=\"string\" name=\"dbhost\" value=\"\"></td></tr>"
"<help><tr><td colspan=2>"
"SQL URL for Database.</td></tr>"
"</help>"
"</table>"
;

return retval;

}

string|int page_3(object id){
 return "<table width=95%>\n"
  + IFERROR + "<tr><td>"
"Store Root &nbsp</td><td> "
" <var type=\"string\" name=\"root\" value=\"\"></td></tr>"
"<help><tr><td colspan=2>"
"Location (in real filesystem) of Store Datafiles.</td></tr>"
"</help>"
"<tr><td>"
"Create Directory? &nbsp; </td><td>"
" <var type=\"select\" name=\"createdir\" options=\"Yes,No\"></td></tr>"
"<p><help>"
"<tr><td colspan=2>Create this directory if it doesn't already exist?</td></tr>"
"</help>"
"</table>";
}

string|int page_4(object id){
 return "<table width=95%>"
 + IFERROR +
"<tr><Td>Session Timeout &nbsp</td><td> "
" <var type=\"string\" name=\"session_timeout\" value=\"3600\"></td></tr>"
"<help><tr><td colspan=2>"
"Number of seconds before a session is cleared from database."
"</td></tr></help>"
"<tr><Td>Secure DB Permissions? &nbsp</td><td> "
" <var type=\"select\" name=\"secureperms\" options=\"No,Yes\"></td></tr>"
"<help><tr><td colspan=2>"
"Should DB access be secured to the iVend host only? Answer 'No' only if "
"you get db access errors while creating the store. This option only "
"affects mySQL users."
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

string|int page_5(object id){
 return "<table width=95%>\n" + IFERROR +
  "<tr><td>Store Style &nbsp; </td><td><var name=\"style\" type=\"select\"" 
  " options=\""+ (getstyles(id)*",") + "\"></td></tr>"
  "<help><tr><td colspan=2>Select the store template style you wish to "
  "use for the creation of this store.</td></tr></help>\n"
  "<tr><td>Copy template files? &nbsp;</td><td><var name=copyfiles "
  "type=select options=\"Yes,No\"></td></tr>"
  "<help><tr><td colspan=2>Copy files into this store "
  "directory?</td></tr></help>"
  "<tr><td>Populate Database? &nbsp;</td><td><var name=populatedb "
  "type=select options=\"Yes,No\"></td></tr>"
  "<help><tr><td colspan=2>If a store database schema is available, "
  "should the wizard use it to populate your store's "
  "database?</td></tr></help>"
  "<tr><td>Administrator Email &nbsp;</td><td><var name=adminemail "
  "type=string></td></tr>"
  "<help><tr><td colspan=2>This is an email address for this store's administrator. "
  "</td></tr></help>"
  "</table>";
}

string|int page_6(object id){
mapping v=id->variables;
string retval="Click OK to perform the following tasks:<p>\n<ul>";
retval+="<li>Create the iVend store <i>" + v->_name + "</i>.\n";
mixed fs=file_stat(v->root);
if(!fs || fs[1]!=-2)	// not a directory
  retval+="<li>Create the directory <i>" + v->root + "</i>\n";
v->copyfiles-="\0000";
if(v->copyfiles=="Yes")
  retval+="<li>Install store  templates for " + capitalize(v->style) +", overwriting existing files.\n";
// if((int)v->overwrite)
// else retval+=" preserving existing files.\n";
if(v->create_db=="Yes") {
  retval+="<li>Create the Database <i>" + v->config + "</i>"; 
  retval+="<li>Create a database user, <i>" + v->config + 
    "</i>, which will be used to access the store data."; 
}
if(file_stat(id->misc->ivend->this_object->query("root") +
	"examples/" + v->style +
	"/schema.mysql") && v->populatedb=="Yes")
  retval+="<li>Setup and populate database tables for this store.\n";
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

string adminpassword=
  makepw->make_password(id->misc->ivend->this_object->query("wordfile"),
  8);

if(v->create_db=="Yes"){

  s=Sql.sql(id->variables->dbhost);

  catch(s->query("CREATE DATABASE " + v->config));
  if(catch(s->select_db(v->config)))
    return "An error occurred while creating the store database. "
  	"This usually means that either 1) the database already exists, "
	"or 2) the db administrator account does not have permission to "
	"create new databases.";
  string adminuser=(sizeof(v->config + "admin")<=16?(v->config +
    "admin"):(v->config + "admin")[0..15]);
  string dt,dn,du,dh,dp;
  perror("Old Database URL: " + v->dbhost + "\n");
  sscanf(v->dbhost, "%s://%s@%s", dt, du, dh);
  array tmps=dh/"/";
  if(sizeof(tmps)>1) { dh=tmps[0]; dn=tmps[1]; }
  dp=MIME.encode_base64((string)hash(ctime(time())))[0..7];  
  du=v->config;
  dn=v->config;
  du+=":"+dp;
  v->dbhost=dt + "://" + du + "@" + dh + "/" + dn;
  perror("New Database URL: " + v->dbhost + "\n");
  string vsr;
  if(functionp(s->server_info))
  catch(vsr=s->server_info());

  s->query("GRANT SELECT, INSERT, UPDATE, DELETE, DROP, ALTER, CREATE on "
     + dn + ".* TO " + dn
     + " IDENTIFIED BY '" + dp + "'"); 

}

else {  // We have our own database...

  s=Sql.sql(v->dbhost);

}

retval+="<b><font face=+1>Store Created Successfully.</b><p></font>"
    "Your store has been successfully created. Please make a note of the "
    "following information:<p>";
retval+= "<b>Admin User:</b> admin<br>\n"
  "<b>Admin Password:</b> " + adminpassword + "<br>\n"
  "<b>Data File Location</b>: " + v->root + "<br>\n";

retval+="<p>\nYou may edit $DATALOCATION/store_package "
  "to customize the overall look of your store.\n"
  "<p><b>Be sure to save your store configurations now.</b>";

privs=Privs("iVend: Creating store directory");
if(v->createdir && !file_stat(v->root)) mkdir(v->root);
privs=0;

if(v->copyfiles=="Yes"){
privs=Privs("iVend: Copying store files ");
perror("copying store templates...\n");
mixed result=Process.system("/bin/cp -rf " +
   id->misc->ivend->this_object->query("root") + "examples/" +
   v->style +"/* " + v->root + "/");
#if efun(chmod)
catch(chmod(v->root, 0775));
#endif

privs=0;
}

if(file_stat(v->root + "/schema.mysql") && v->populatedb=="Yes"){

  array ss=Stdio.read_file(v->root +  "/schema.mysql")/"\\g\n";
  if(catch(object s=Sql.sql(v->dbhost))) {
    return "An error occurred while connecting to the store database" 
	"as " + v->dbhost + "."
	"<p>This is sometimes due to improper host table setup on "
	"the database host.";
//	+ s->error();
    }
perror("populating database...\n");
ss=ss[0..sizeof(ss)-2];
  foreach(ss, string statement)
      if(catch(s->query(statement)))
        return "A SQL Error occurred while processing this statement: " +
	  statement + "<p><b>Error:</b> " + s->error();
s->query("INSERT INTO admin_users VALUES('ADMIN','Store Administrator','"
	+ v->adminemail + "','" + crypt(adminpassword) + "', 9)");
}
else {
  retval+="You chose not to have database tables created. Before you "
	"can use this store, you must populate the database. You should "
	"use $STOREROOT/schema.mysql as a starting point. You must also "
	"add a qualified administrative user to the admin_users table "
	"using a query like this:<p>"
	"<blockquote><tt>INSERT INTO admin_users VALUES('ADMIN',"
	"'Store Administrator','Admin_Email@Address',ENCRYPT('password')"
	",9)<p>\n";
}


privs=Privs("iVend: Copying key files ");
mkdir(v->root + "/private");

if(!file_stat(v->root +"/private/key.pub"))
  write_keys(v->root + "/private/key");

#if efun(chmod)
chmod(v->root + "/private/key.pub", 0400);
chmod(v->root + "/private/key.priv", 0400);
chmod(v->root + "/private", 0500);
#endif

privs=0;

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

