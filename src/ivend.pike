/*
 * ivend.pike: Electronic Shopping for Roxen.
 *
 * Bill Welliver <hww3@riverweb.com>
 *
 */

#include "include/messages.h"
#include <module.h>
#include <stdio.h>
#include <simulate.h>

inherit "module";
inherit "roxenlib";
inherit "wizard";

mapping(string:mapping(string:mixed)) config=([]);
mapping(string:mixed) global=([]) ;
object c;			// configuration object
mapping(string:object) modules=([]);			// module cache
int save_status=1; 		// 1=we've saved 0=need to save.
int loaded;

string cvs_version = "$Id: ivend.pike,v 1.47 1998-04-12 03:44:32 hww3 Exp $";

array register_module(){

 string s="";

  if(loaded) {
    s = "<br>Go to the <a href='"+
      my_configuration()->query("MyWorldLocation")+ query("mountpoint") +
	"config/'>iVend Configuration Interface</a>";

   }

  return( {
     MODULE_LOCATION | MODULE_PARSER,
       "iVend 1.0",
       "iVend enables online shopping within Roxen." + s,
            0,
            1
            } );
               
}

string query_location()
{
   return QUERY(mountpoint);
   }


void create(){

   defvar("mountpoint", "/ivend/", "Mountpoint",
          TYPE_LOCATION,
          "This is where the module will be inserted in the "
          "namespace of your server.");

   defvar("root", "/home/roxen/share/ivend/" , "iVend Root Location",
          TYPE_DIR,
          "This is location where the iVend program files are located "
          );

   defvar("datadir", query("root")+"data" , "iVend Data Location",
          TYPE_DIR,
          "This is location where iVend will store "
          "data and configuration files nessecary for operation.");

   defvar("config_user", "ivend", "Configuration User",
	  TYPE_STRING,
	  "This is the username to use when accessing the iVend Configuration "
	  "interface.");

   defvar("config_password", "", "Configuration Password",
	  TYPE_STRING,
	  "The password to use when accessing the iVend Configuration "
	  "interface.");

   defvar("lang", "en", "Default Language",
	  TYPE_MULTIPLE_STRING, "Default Language for Stores",
	  ({"en","si"})
	  );
}

string|void check_variable(string variable, mixed set_to){

return;

}

string status(){

   return ("Everything's A-OK!\n");

}

string query_name()

{
   return sprintf("iVend 1.0  mounted on <i>%s</i>", query("mountpoint"));
}

int load_ivmodule(string name){

modules+=([ name :
    (object)clone(compile_file(query("root")+"/modules/"+
    name)) ]);

return 1;

}


mixed getglobalvar(string var){

  if(catch(global[var]))
    return 0;
  else return global[var];

}

float convert(float value, object id){

if(functionp(modules[id->misc->ivend->config->currency_module]->currency_convert))
	  value=
	  modules[id->misc->ivend->config->currency_module
	  ]->currency_convert(value,id);

else ;

return value;


}



mixed handle_search(object id){

return "";
}

int clean_sessions(object id){

string query="DELETE FROM sessions WHERE timeout < "+time(0);
id->misc->ivend->db->query(query);
return 0;
}

array|int size_of_image(string filename){

  object fop;
  string sizes;
  array res = ({ 0,0 });
  fop = Stdio.File();
  if(!fop->open(filename, "r")) return -1;
  fop->seek(0);
  if(fop->read(3) !="GIF") return 0;
  fop->seek(6); 
  sizes = fop->read(4);
  if(!sizes || (strlen(sizes) < 4)) return 0; //  short file
  res[0] = (sizes[1]<<8) + sizes[0];
  res[1] = (sizes[3]<<8) + sizes[2];
  return res;

}

string|void container_ia(string name, mapping args,
                      string contents, object id)

{
if (catch(id->misc->ivend->SESSIONID)) return;

if (args["_parsed"]) return;

if (args->add) 
  return "<a _parsed=1 href=\""+query("mountpoint")
  +id->misc->ivend->st+"/"+id->misc->ivend->page+".html?SESSIONID="
  +id->misc->ivend->SESSIONID+"&ADDITEM="+id->misc->ivend->page+
  "\">"+contents+"</a>";
else if(args->cart)
  return "<a _parsed=1 href=\""+query("mountpoint")+
  id->misc->ivend->st+"/cart?SESSIONID="
  +id->misc->ivend->SESSIONID+
  "\">"+contents+"</a>";
else if(args->checkout)
  return "<a _parsed=1 href=\""+query("mountpoint")+
  id->misc->ivend->st+"/checkout?SESSIONID="
  +id->misc->ivend->SESSIONID+
  "\">"+contents+"</a>";
else if(args->href){
  int loc;
  if(loc=search(args->href,"?")==-1)
  return "<a _parsed=1 href=\""+args->href
    +"?SESSIONID=" +(id->misc->ivend->SESSIONID)
    +"\">"+contents+"</a>";  

  else  return "<a _parsed=1 href=\""+args->href
    +"&SESSIONID=" +(id->misc->ivend->SESSIONID)
    + "\">"+contents+"</a>";  

  }
else return "<!-- Error Parsing 'A' tag -->";
}

void|string container_form(string name, mapping args,
                      string contents, object id)
{
  if(args["_parsed"]) return;
  contents="<input type=hidden name=SESSIONID value="+
	id->misc->ivend->SESSIONID+">"+contents;
  string formargs="";
  string a;
  foreach(indices(args),a)
    formargs=formargs+a+"=\""+args[a]+"\" ";
  formargs+="_parsed=1";

  return "<form "+formargs+">"+contents+"</form>";

}

string container_icart(string name, mapping args,
                      string contents, object id)
{
string st;
    if(!id->misc->ivend->st) return "You can't access your cart from here.";
    else st=id->misc->ivend->st;

if(id->variables->update) {


    for(int i=0; i< (int)id->variables->s; i++){

    if((int)id->variables["q"+(string)i]==0)
	id->misc->ivend->db->query("DELETE FROM sessions WHERE SESSIONID='"
	+id->misc->ivend->SESSIONID+
	  "' AND id='"+id->variables["p"+(string)i]+"' AND series="+
	  id->variables["s"+(string)i] );
    else
   id->misc->ivend->db->query("UPDATE sessions SET "
      "quantity="+id->variables["q"+(string)i]+
	  " WHERE SESSIONID='"+id->misc->ivend->SESSIONID+"' AND id='"+
	  id->variables["p"+(string)i]+ "' AND series="+ id->variables["s"+(string)i] );

    }

}

  string field;

  string retval=lower_case(contents);
  if(!id->misc->ivend->SESSIONID) return retval+"blah";
  else {
    retval+="<form action=\""+id->not_query+"\" method=post>\n<table>\n";

    if(!args->fields) return "Incomplete cart configuration!";
    array r= id->misc->ivend->db->query(
      "SELECT sessions.id,series,quantity,name,sessions.price,"+ 
	args->fields+" FROM sessions,products "
      "WHERE sessions.SESSIONID='"
	+id->misc->ivend->SESSIONID+"' AND sessions.id=products.id");
    if (sizeof(r)==0) return "Your Cart is Empty.\n";
    retval+="<tr><th bgcolor=maroon><font color=white>Code</th>\n"
	"<th bgcolor=maroon><font color=white>Product</th>\n";
	
    foreach(args->fields / ",",field){
	retval+="<th bgcolor=maroon>&nbsp; <font color=white>"+field+" &nbsp; </th>\n";
	}
    retval+="<th bgcolor=maroon><font color=white>&nbsp; Price &nbsp;</th>\n"
    	"<th bgcolor=maroon><font color=white>&nbsp; Qty &nbsp;</th>\n"
	"<th bgcolor=maroon><font color=white>&nbsp; Total &nbsp;</th></tr>\n";
    for (int i=0; i< sizeof(r); i++){
      retval+="<TR><TD><INPUT TYPE=HIDDEN NAME=s"+i+" VALUE="+r[i]->series+">\n"
	  "<INPUT TYPE=HIDDEN NAME=p"+i+" VALUE="+r[i]->id+">&nbsp; \n"
        +r[i]->id+" &nbsp;</TD>\n"
	  "<td>"+r[i]["name"]+"</td>\n";

	foreach(args->fields / ",",field){
	    retval+="<td>"+(r[i][field] || " N/A ")+"</td>\n";
	    }

	  r[i]->price=convert((float)r[i]->price,id);

	retval+="<td align=right>"
	+sprintf("$%.2f",(float)r[i]->price)+"</td>\n"
	"<TD><INPUT TYPE=TEXT SIZE=3 NAME=q"+i+" VALUE="+
        r[i]->quantity+"></td><td align=right>"
	+sprintf("$%.2f",(float)r[i]->quantity*(float)r[i]->price)+"</td></tr>\n";
      }
    retval+="</table>\n<input type=hidden name=s value="+sizeof(r)+">\n"
	"<input type=hidden value=1 name=update>\n<input type=submit value=\"Update Cart\"></form>\n";
return retval;    
 
    }
  
}

string tag_ivendlogo(string tag_name, mapping args,
                    object id, mapping defines) {

return "<a href=\"http://hww3.riverweb.com/ivend\"><img src=\""+
	query("mountpoint")+"ivend-image/ivendbutton.gif\" border=0></a>";

}

string tag_sessionid(string tag_name, mapping args,
                    object id, mapping defines) {

return id->misc->ivend->SESSIONID;

}

string container_rotate(string name, mapping args,
                      string contents, object id) {

  if(!id->misc->fr) id->misc->fr=({});

  id->misc->fr+=({contents});

  return "";

}

string container_category_output(string name, mapping args,
                      string contents, object id) {

contents=parse_html(contents,([]),
        (["formrotate":container_rotate]),id);

  string retval="";
  string query;

  if(!args->type) return "You must supply a category type.";

  query="SELECT * FROM " + lower_case(args->type);
  
  if(args->restriction)
    query+=" WHERE " + args->restriction;

  array r=id->misc->ivend->db->query(query);

  if(!id->misc->fr)
    retval+=do_output_tag( args, r, contents, id );  

  else {
    int n=0;
    foreach(r, mapping row) {
      if(args->random)
        n=random(sizeof(id->misc->fr));
      retval+=do_output_tag( args, ({ row }), id->misc->fr[n], id); 
      n++;
      if(n>=sizeof(id->misc->fr)) n=0;  // larger than number of forms.

      }

    }

  return retval;
}

string tag_listitems(string tag_name, mapping args,
                    object id, mapping defines)

{

string retval="";

if(!id->misc->ivend->page) return "no page!";
string st=id->misc->ivend->st;

array r;
if(args->type=="groups") {
  r=id->misc->ivend->db->query("SELECT id AS pid,"+args->fields+ " FROM groups");
  }
else {

  r=id->misc->ivend->db->query("SELECT product_id AS pid,"+args->fields+
	" FROM product_groups,products where group_id='"+
	     id->misc->ivend->page+"'"
	" AND products.id=product_id");
}

if(sizeof(r)==0) return "Sorry, No Products are Available.";

mapping row;

array(string) titles=(args->fields/",");
array(array(string)) rows=allocate(sizeof(r));
int p=0;
foreach(r,row){
  array thisrow=allocate(sizeof(row)-1);
  string t;
  int n=0;
// perror(indices(row)*" - ");
  foreach(titles, t){
//	perror(t);  

      if(n==0)
        thisrow[n]=("<A HREF=\""+row->pid+".html\">"+row[t]+"</A>");
      else
        thisrow[n]=row[t]; 
      n++;

    }
  rows[p]=thisrow;
  p++;
  }

retval+=html_table(titles, rows);
return retval;

    }


string tag_ivstatus(string tag_name, mapping args,
                    object id, mapping defines)
{

return replace(id->misc->ivendstatus || "","\n","<br>");

}
string tag_ivmg(string tag_name, mapping args,
                    object id, mapping defines)

{
string st=id->misc->ivend->st;
string filename="";
array r;
if(args->field!=""){
  r=id->misc->ivend->db->query("SELECT "+args->field+ " FROM "+ 
    id->misc->ivend->type+"s WHERE "
	" id='"+id->misc->ivend->id+"'");
  if (sizeof(r)!=1) return "";
  else filename=config[id->misc->ivend->st]->root+"/images/"+
    id->misc->ivend->type+"s/"+r[0][args->field];
  }  
else if(args->src!="") 
filename=config[id->misc->ivend->st]->root+"/images/"+args->src;

array|int size=size_of_image(filename);


// file doesn't exist
if(size==-1) return "<couldn't find the image: "+filename+"... -->";
// it's not a gif file
else if(size==0)	
	return ("<IMG SRC=\""+query("mountpoint")+st+"/images/"
      +id->misc->ivend->type+"s/"+r[0][args->field]+"\">");
// it's a gif file
else return ("<IMG SRC=\""+query("mountpoint")+st+"/images/"
      +id->misc->ivend->type+"s/"+r[0][args->field]+"\""
	" HEIGHT=\""+size[1]+"\" WIDTH=\""+size[0]+"\">");


}

string container_ivindex(string name, mapping args,
                      string contents, object id)
{
string retval="";
array(string)a=indices(config);
string c;
foreach(a,c){
  string s=contents;
string d="";
foreach(indices(config[c]),d){
  s=replace(s,("#"+d+"#"),config[c][d]);
  }
  s=replace(s,"#id#",c);
  retval+=s;
}
return retval;

}

int read_conf(){          // Read the config data.

string current_config="";
string attribute;
string value;

c=iVend.config();
if(!c->load_config_defs(Stdio.read_file(query("datadir")+"ivend.cfd")))
   perror("iVend: ERROR LOADING CONFIGURATION DEFINITION!\n");
else 
   perror("iVend: LOADED CONFIGURATION DEFINITION!\n");
catch(array(string) config_file= read_file(query("datadir")+"ivend.cfg")/"\n");
if(!config_file) {
   perror("iVend: ERROR NONEXISTANT ivend.cfg!\n");
   return 0;

   }

for (int i=0; i<sizeof(config_file);i++){

	if(config_file[i][0..4]=="start"){

#ifdef MODULE_DEBUG
 perror("iVend: parsing section "+config_file[i][6..]+"\n");
#endif

		current_config=config_file[i][6..];		
		}
	else if(config_file[i]=="end") break;
	else if(config_file[i][0..0]=="$"){
		array(mixed) current_line=config_file[i][1..]/"=";
	attribute=current_line[0];
	value=current_line[1];
	if(!config[current_config])
		config[current_config]= ([attribute:value]);
	else config[current_config][attribute]=value;

		}
	}

}


void load_modules(string c){
  foreach(indices(config[c]), string n)
    if(Regexp("._module")->match(n)) {
      perror("loading module " + config[c][n] + "\n");
      load_ivmodule(config[c][n]);
      }
  return;
}

void start(){

  loaded=1;

  if(file_stat(query("datadir")+"ivend.cfg")==0) return; 
    else  read_conf();   // Read the config data.
  add_include_path(query("root") + "include");
  add_module_path(query("root"));
  add_program_path(query("root")[0..sizeof(query("root"))-2]);
  
  foreach(indices(config), string c)
    load_modules(config[c]->config);

  return;	


}

mixed stat_file( mixed f, mixed id )  {
if(! id->misc->ivend) 
	return ({ 33204,0,time(),time(),time(),0,0 });
array fs;
#ifdef MODULE_DEBUG
 perror("statting "+id->misc->ivend->root+"/"+f+"\n");
#endif
fs=file_stat(id->misc->ivend->root+"/"+f);
return fs;
}


mixed handle_error(string error, object id){
string retval;
if(!(retval=Stdio.read_file(config[id->misc->ivend->st]->root+"/error.html")))
  retval="<title>iVend Error</title>\n<h2>iVend Error</h2>\n"
	"The following error has occurred:<p><error><p>\n"
	"Please contact the administrator for assistance.";
return replace(retval,"<error>",error);

}

mixed handle_cart(string st, object id){
#ifdef MODULE_DEBUG
perror("iVend: handling cart for "+st+"\n");
#endif

string retval;
if(!(retval=Stdio.read_bytes(id->misc->ivend->config->root+"/cart.html")))
  return handle_error(id->misc->ivend->config->root+"/cart.html",id);
 
return retval;    

}

mixed parse_page(string page, array(mapping(string:string)) r, array desc,
object|void id){

string field;
array fields=indices(r[0]);

for(int i=0; i<sizeof(desc); i++){

  if(desc[i]->type=="decimal" && desc[i]->name=="price") {
    r[0][desc[i]->name]=(string)convert((float)r[0][desc[i]->name], id);
    r[0][desc[i]->name]=sprintf("%.2f",(float)(r[0][desc[i]->name]));
  }

else  if(desc[i]->type=="decimal")
  r[0][desc[i]->name]=sprintf("%.2f",(float)(r[0][desc[i]->name]));

  }
 return do_output_tag( ([]), ({ r[0] }), page, id ); 

}

mixed find_page(string page, object id){
#ifdef MODULE_DEBUG
perror("iVend: finding page "+ page+" in "+id->misc->ivend->st+"\n");
#endif

string retval;

page=page-".html";	// get to the core of the matter.
id->misc->ivend->id=page;
string template;
array(mapping(string:string)) r;
array f;
r=id->misc->ivend->db->query("SELECT * FROM groups WHERE id='"+page+"'");
if (sizeof(r)==1){
  id->misc->ivend->type="group";
  template="group_template.html";
  f=id->misc->ivend->db->list_fields("groups");
  }
else {
  r=id->misc->ivend->db->query("SELECT * FROM products WHERE id='"+page+"'");
  id->misc->ivend->type="product";
  template="product_template.html";
  f=id->misc->ivend->db->list_fields("products");

  }
if (sizeof(r)!=1) 
return 0;

retval=Stdio.read_bytes(id->misc->ivend->config->root+"/"+template);
if (catch(sizeof(retval)))
  return 0;
id->realfile=id->misc->ivend->config->root+"/"+template;
return parse_page(retval, r, f, id);
}

mixed additem(string item, object id){

  float price=id->misc->ivend->db->query("SELECT price FROM products WHERE id='" 
  + item + "'")[0]->price;

  price=convert((float)price,id);


int max=sizeof(id->misc->ivend->db->query("select id FROM sessions WHERE SESSIONID='"+
  id->misc->ivend->SESSIONID+"' AND id='"+item+"'"));
string query="INSERT INTO sessions VALUES('"+ id->misc->ivend->SESSIONID+
  "','"+item+"',1,"+(max+1)+",'Standard','"+(time(0)+
  (int)id->misc->ivend->config->session_timeout)+"'," + price +")";
perror(query+"\n");
if(catch(id->misc->ivend->db->query(query) ))
	id->misc["ivendstatus"]+=("Error adding item "+item+ ".\n"); 
else 
  id->misc["ivendstatus"]+=("Item "+item+ " added successfully.\n"); 
return 0;
}

mixed handle_page(string page, object id){
#ifdef MODULE_DEBUG
perror("iVend: handling page "+ page+ " in "+ id->misc->ivend->st +"\n");
#endif

id->misc->ivend["page"]=page-".html";
if(id->variables->ADDITEM) additem(id->variables->ADDITEM,id);
mixed retval;

switch(page){

  case "index.html":
    id->realfile=id->misc->ivend->config->root+"/index.html";
    retval= Stdio.read_bytes(id->misc->ivend->config->root+"/index.html"); 
    break;

  case "search":
    retval=handle_search(id);
    break;

  default:

    if(retval=Stdio.read_bytes(id->misc->ivend->config->root+
	    "/"+page )) { 
	id->realfile=id->misc->ivend->config->root+"/"+page;
	break;
	}
    else retval=find_page(page, id);
  }
  if (!retval) return handle_error("Unable to find product "+page, id);
  else return retval;

}

mapping ivend_image(array(string) request, object id){

	string image;
	image=read_file(query("datadir")+"images/"+request[0]);

	return http_string_answer(image,
		id->conf->type_from_filename(request[0]));

}

mixed handle_checkout(object id){
mixed retval;


retval=modules[id->misc->ivend->config->checkout_module]->checkout(id);

if(retval==-1) return handle_page("index.html",id);
else 
return retval;    
}



mapping write_configuration(object id){

string config_file="";

array(string) configs= indices(config);

for(int i=0; i<sizeof(config); i++){
	
	config_file+="start "+ configs[i] +"\n";
	array(string) this_config= indices(config[configs[i]]);
	
	for(int j=0; j<sizeof(this_config); j++){
	
		config_file+="$" +this_config[j]+ "=" + config[configs[i]][this_config[j]] + "\n";
		
		}
	config_file+="\n";
	}
	
config_file+="end\n";

mv(query("datadir")+"ivend.cfg",query("datadir")+"ivend.cfg.back");
write_file(query("datadir")+"ivend.cfg", config_file);
save_status=1;	// We've saved.
return http_redirect(query("mountpoint")+"config", id);

}

int get_auth(object id, int|void i){
if(i){
// perror(query("config_password")+" "+query("config_user")+"\n");
  array(string) auth=id->realauth/":";
  if(auth[0]!=query("config_user")) return 0;
  else if(query("config_password")==auth[1])
        return 1;
  else return 0;                   
}
  array(string) auth=id->realauth/":";
  if(auth[0]!=id->misc->ivend->config->config_user) return 0;
  else if(id->misc->ivend->config->config_password==auth[1])
        return 1;
  else return 0;

}

mapping configuration_interface(array(string) request, object id){

if(id->auth==0)
  return http_auth_required("iVend Configuration","Silly user, you need to login!"); 
else if(!get_auth(id,1)) 
  return http_auth_required("iVend Configuration","Silly user, you need to login!");

if(!c) read_conf(); 

	string retval="";

	if(catch(request[0])) return
http_redirect(query("mountpoint")+"config/configs",id);
retval+="<HTML>\n"
"<HEAD>\n"
"<TITLE>iVend Configuration</TITLE>\n"
"</HEAD>\n"
"<BODY BGCOLOR=\"White\" BACKGROUND=\""+query("mountpoint")+"ivend-image/ivendbg.gif\" TEXT=\"#000066\" LINK=\"#000066\">\n"
"<CENTER><FONT COLOR=\"White\"><TABLE COOL WIDTH=\"786\" BORDER=\"0\" CELLPADDING=\"0\" CELLSPACING=\"0\">\n"
"<TR HEIGHT=\"8\">\n"
"	<TD WIDTH=\"32\" HEIGHT=\"8\"><SPACER TYPE=\"BLOCK\" WIDTH=\"32\" HEIGHT=\"8\"></TD>\n"
"	<TD WIDTH=\"186\" HEIGHT=\"8\"><SPACER TYPE=\"BLOCK\" WIDTH=\"186\" HEIGHT=\"8\"></TD>\n"
"	<TD WIDTH=\"6\" HEIGHT=\"8\"><SPACER TYPE=\"BLOCK\" WIDTH=\"6\" HEIGHT=\"8\"></TD>\n"
"	<TD WIDTH=\"186\" HEIGHT=\"8\"><SPACER TYPE=\"BLOCK\" WIDTH=\"186\" HEIGHT=\"8\"></TD>\n"
"	<TD WIDTH=\"6\" HEIGHT=\"8\"><SPACER TYPE=\"BLOCK\" WIDTH=\"6\" HEIGHT=\"8\"></TD>\n"
"	<TD WIDTH=\"186\" HEIGHT=\"8\"><SPACER TYPE=\"BLOCK\" WIDTH=\"186\" HEIGHT=\"8\"></TD>\n"
"	<TD WIDTH=\"182\" HEIGHT=\"8\"><SPACER TYPE=\"BLOCK\" WIDTH=\"182\" HEIGHT=\"8\"></TD>\n"
"</TR>\n";

// Do filefolder tabs

	switch(request[0]){
	
		case "status": {
		retval+=
"<TR HEIGHT=\"28\">\n"
"	<TD WIDTH=\"32\" HEIGHT=\"28\"><SPACER TYPE=\"BLOCK\" WIDTH=\"32\" HEIGHT=\"28\"></TD>\n"
"	<TD WIDTH=\"186\" HEIGHT=\"28\" COLSPAN=\"1\" ROWSPAN=\"1\" VALIGN=\"top\" ALIGN=\"left\" XPOS=\"32\"><A "
"	HREF=\""+query("mountpoint")+"config/configs\"><IMG SRC=\""+query("mountpoint")+"ivend-image/configurationsunselect.gif\" "
"	WIDTH=\"186\" HEIGHT=\"28\" BORDER=\"0\" ALT=\"/  Configurations  \\\"></A></TD>\n"
"	<TD WIDTH=\"6\" HEIGHT=\"28\"><SPACER TYPE=\"BLOCK\" WIDTH=\"6\" HEIGHT=\"28\"></TD>\n"
"	<TD WIDTH=\"186\" HEIGHT=\"28\" COLSPAN=\"1\" ROWSPAN=\"1\" VALIGN=\"top\" ALIGN=\"left\" XPOS=\"224\">"
"<A HREF=\""+query("mountpoint")+"config/global\"><IMG SRC=\""+query("mountpoint")+"ivend-image/globalunselect.gif\" WIDTH=\"186\" HEIGHT=\"28\" BORDER=\"0\" ALT=\"/ Global Variables \\\"></A></TD>\n"
"	<TD WIDTH=\"6\" HEIGHT=\"28\"><SPACER TYPE=\"BLOCK\" WIDTH=\"6\" HEIGHT=\"28\"></TD>\n"
"	<TD WIDTH=\"186\" HEIGHT=\"28\" COLSPAN=\"1\" ROWSPAN=\"1\" VALIGN=\"top\" ALIGN=\"left\" XPOS=\"416\"><A HREF=\""+query("mountpoint")+"config/status\"><IMG SRC=\""+query("mountpoint")+
"ivend-image/statusselect.gif\" WIDTH=\"186\" HEIGHT=\"28\" BORDER=\"0\" ALT=\"/        Status        \\\"></A></TD>\n"
"<TD WIDTH=\"182\" HEIGHT=\"28\"><SPACER TYPE=\"BLOCK\" WIDTH=\"182\" HEIGHT=\"28\"></TD>\n"
"</TR>\n";
		
		break; 
		
		}
		
		case "save": {
		
		return write_configuration(id);
		
		break;
		
		}
		
		case "global": {
if(!catch(request[1]) && request[1]=="save")
{
// perror("SAVING CHANGES...\n");
array(string) vars=indices(id->variables);
string v;
foreach((vars),v){

  if(!global) global=([v:id->variables[v]]);

  else global[v]=id->variables[v];
}

save_status=0;	// we need to save.
}
		
retval+=
"<TR HEIGHT=\"28\">\n"
"<TD WIDTH=\"32\" HEIGHT=\"28\"><SPACER TYPE=\"BLOCK\" WIDTH=\"32\" HEIGHT=\"28\"></TD>\n"
"<TD WIDTH=\"186\" HEIGHT=\"28\" COLSPAN=\"1\" ROWSPAN=\"1\" VALIGN=\"top\" ALIGN=\"left\" XPOS=\"32\"><A "
" HREF=\""+query("mountpoint")+"config/configs\"><IMG SRC=\""+query("mountpoint")+"ivend-image/configurationsunselect.gif\" "
" WIDTH=\"186\" HEIGHT=\"" "	28\" BORDER=\"0\" ALT=\"/  Configurations  \\\"></A></TD>\n"
"<TD WIDTH=\"6\" HEIGHT=\"28\"><SPACER TYPE=\"BLOCK\" WIDTH=\"6\" HEIGHT=\"28\"></TD>\n"
"<TD WIDTH=\"186\" HEIGHT=\"28\" COLSPAN=\"1\" ROWSPAN=\"1\" VALIGN=\"top\" ALIGN=\"left\" XPOS=\"224\"><A HREF=\""+query("mountpoint")+"config/global\"><IMG SRC=\""+query("mountpoint")+"ivend-image/globalselect.gif\" WIDTH=\"186\" HEIGHT=\"28\""
" BORDER=\"0\" ALT=\"/ Global Variables \\\"></A></TD>\n"
"<TD WIDTH=\"6\" HEIGHT=\"28\"><SPACER TYPE=\"BLOCK\" WIDTH=\"6\" HEIGHT=\"28\"></TD>\n"
"<TD WIDTH=\"186\" HEIGHT=\"28\" COLSPAN=\"1\" ROWSPAN=\"1\" VALIGN=\"top\" ALIGN=\"left\" XPOS=\"416\"><A HREF=\""+query("mountpoint")+"config/status\"><IMG SRC=\""+query("mountpoint")+"ivend-image/statusunselect.gif\" WIDTH=\"186\" HEIGHT=\"28\""
" BORDER=\"0\" ALT=\"/        Status        \\\"></A></TD>\n"
"<TD WIDTH=\"182\" HEIGHT=\"28\"><SPACER TYPE=\"BLOCK\" WIDTH=\"182\" HEIGHT=\"28\"></TD>\n</TR>\n"
"<TD COLSPAN=6><BR><BLOCKQUOTE><P ALIGN=\"LEFT\"><FONT SIZE=+2 FACE=\"times\">"
"Global Variables</FONT><P>\n"
"<FORM METHOD=POST ACTION=\""+query("mountpoint")+"config/global/save\">\n"
"<TABLE><TR>\n"
"<TD>Generate Store Index?<BR><FONT SIZE=0>Should iVend create an index of all stores?</FONT></TD>\n"
"<TD><select NAME=\"create_index\"><OPTION";

if(getglobalvar("create_index")=="yes")
retval+=" SELECTED>yes<OPTION>no</SELECT>\n";
else retval+=">yes<OPTION SELECTED>no</SELECT>\n";
retval+="</TD></TR>\n"
"<tr>"
"<TD>Move only store up 1 level?<BR><FONT SIZE=0>Should iVend move the only store to the iVend root?</FONT></TD>\n"
"<TD><select NAME=\"move_onestore\"><OPTION";

if(getglobalvar("move_onestore")=="yes")
retval+=" SELECTED>yes<OPTION>no</SELECT>\n";
else retval+=">yes<OPTION SELECTED>no</SELECT>\n";
retval+="</TD></TR>\n"
"<TR><TD><INPUT TYPE=SUBMIT VALUE=\" Update Variables \"></TD><TD>&nbsp;</TD></TR>\n" 
"</TABLE></FORM>\n</TD></TR>";
		break;
		
		}
		
		case "configs":
		default:
		
		{
		
		retval+=
"<TR HEIGHT=\"28\">\n"
"<TD WIDTH=\"32\" HEIGHT=\"28\"><SPACER TYPE=\"BLOCK\" WIDTH=\"32\" HEIGHT=\"28\"></TD>\n"
"<TD WIDTH=\"186\" HEIGHT=\"28\" COLSPAN=\"1\" ROWSPAN=\"1\" VALIGN=\"top\" ALIGN=\"left\" XPOS=\"32\"><A HREF=\""+query("mountpoint")+"config/configs\"><IMG SRC=\""+query("mountpoint")+"ivend-image/configurationsselect.gif\" "
 "WIDTH=\"186\" HEIGHT=\"28\"" 
" BORDER=\"0\" ALT=\"/  Configurations  \\\"></A></TD>\n"
"<TD WIDTH=\"6\" HEIGHT=\"28\"><SPACER TYPE=\"BLOCK\" WIDTH=\"6\" HEIGHT=\"28\"></TD>\n"
"<TD WIDTH=\"186\" HEIGHT=\"28\" COLSPAN=\"1\" ROWSPAN=\"1\" VALIGN=\"top\" ALIGN=\"left\" XPOS=\"224\"><A HREF=\""+query("mountpoint")+"config/global\"><IMG SRC=\""+query("mountpoint")+"ivend-image/globalunselect.gif\" WIDTH=\"186\" "
" HEIGHT=\"28\" BORDER=\"0\" ALT=\"/ Global Variables \\\"></A></TD>\n"
"<TD WIDTH=\"6\" HEIGHT=\"28\"><SPACER TYPE=\"BLOCK\" WIDTH=\"6\" HEIGHT=\"28\"></TD>\n"
"<TD WIDTH=\"186\" HEIGHT=\"28\" COLSPAN=\"1\" ROWSPAN=\"1\" VALIGN=\"top\" ALIGN=\"left\" XPOS=\"416\"><A HREF=\""+query("mountpoint")+"config/status\"><IMG SRC=\""+query("mountpoint")+"ivend-image/statusunselect.gif\" WIDTH=\"186\" "
" HEIGHT=\"28\" BORDER=\"0\" ALT=\"/        Status        \\\"></A></TD>\n"
"<TD WIDTH=\"182\" HEIGHT=\"28\"><SPACER TYPE=\"BLOCK\" WIDTH=\"182\" HEIGHT=\"28\"></TD>\n"
"</TR>\n"
"<TR>\n"
"<TD WIDTH=\"32\" HEIGHT=\"28\"><SPACER TYPE=\"BLOCK\" WIDTH=\"32\" HEIGHT=\"28\"></TD>\n";

		
		if(request[0]=="new"){
			
			if(id->variables->config && !config[id->variables->config]){
			
				array(string) variables= indices(id->variables);
				for(int i=0; i<sizeof(variables); i++){
				
					if(!config[id->variables->config]) 
config[id->variables->config]= ([]);
config[id->variables->config]+=([variables[i]:id->variables[variables[i]] ]);
				
					}
				
				save_status=0;
				return http_redirect(query("mountpoint")+"config/configs",id);
				
				}
				
	else retval+="<TD COLSPAN=6><BR><BLOCKQUOTE><P ALIGN=\"LEFT\"><FONT SIZE=+2 FACE=\"times\">"
	"New Configuration</FONT><P>\n"
	"<FORM METHOD=POST ACTION=\""+query("mountpoint")+"config/new\">\n<table>"+
	(c->genform(
	0,
	query("lang"), 
	query("root")+"/modules")
	  ||"Error Loading Configuration Definitions!")+
	"</table><p><input type=submit value=\"Add New Store\"></form>"
	"</TD></TR>";
			
			}
			
			
		
		
		
		else if(catch(request[1])){		// Haven't specified a configuration yet, so list 'em all.
		
			retval+="<TD COLSPAN=6><BR><BLOCKQUOTE><P ALIGN=\"LEFT\"><FONT SIZE=+2 FACE=\"times\">"
				"All Configurations</FONT><P>\n";
				
			array(string) all_configs=indices(config);
			
			for(int i=0; i<sizeof(all_configs); i++){
			
				retval+="<LI><FONT SIZE=+1 FACE=\"helvetica,arial\"><A HREF=\""+query("mountpoint")+"config/configs/"+all_configs[i]+"\">"
					+config[all_configs[i]]->name+"</A></FONT>\n";
			
				}

			retval+="<P><FONT FACE=\"times\" SIZE=+1>To View, Modify or Delete a Configuration, Click on it's name in the list above.</FONT><P>\n"
				"<A HREF=\""+query("mountpoint")+"config/new\">New Configuration</A> &nbsp; ";
			if(save_status!=1)
				retval+="<A HREF=\""+query("mountpoint")+"config/save\">Save Changes</A>";

			}
		
		
		
				
			
	else {		// OK, we know what we have in mind...

			if(id->variables->config_delete=="1") {
perror("DELETING " + request[1] + "\n");
				config=m_delete(config,request[1]);
				save_status=0;
				return http_redirect(query("mountpoint")+"config/configs?"+time(),id);				

				}			

			else if(!catch(request[2]) && request[2]=="config_modify") {
				array(string) variables= (indices(id->variables)- ({"config_modify"}));
                                for(int i=0; i<sizeof(variables); i++){
 
                                	config[id->variables->config][variables[i]]=id->variables[variables[i]];

                                        }
 
                                save_status=0;   
                                return http_redirect(query("mountpoint")+"config/configs/"+request[1]+"?"+time(),id);


				}

			else retval+="<TD COLSPAN=6><BR><BLOCKQUOTE><P ALIGN=\"LEFT\"><FONT SIZE=+2 FACE=\"times\">"
			"<a href=\""+
			query("mountpoint")+
			"/"+request[1]+"\">"
			+config[request[1]]->name+"</a></FONT><P>\n"
			"<FORM METHOD=POST ACTION=\""+query("mountpoint")+"config/configs/"+request[1]+"/config_modify\">\n"
			"<TABLE>"
			+(c->genform(config[request[1]],query("lang"),
			  query("root")+"/modules")
			||"Error loading configuration definitions")+
			"</TABLE><p><input type=submit value=\"Modify Configuration\">"
			"<p>"
			"<A HREF=\""+ query("mountpoint")
+"config/configs/"+ request[1]+"?config_delete=1\">Delete Configuration</A>"
			"</FORM>"
			"</TD></TR>";
			
			}
		
		retval+="</TD></TR>\n";	
		
		break;

		}
				
		

	
	}
	
	
	retval+=

"		</TABLE>\n"
"		</FONT></CENTER>\n"
"	</BODY>\n"
"</HTML>\n";

   	return http_string_answer(retval);
  
   }


mixed order_handler(string filename, object id){

if(id->auth==0)
  return http_auth_required("iVend Store Orders",
	"Silly user, you need to login!"); 
else if(!get_auth(id)) 
  return http_auth_required("iVend Store Orders",
	"Silly user, you need to login!");

string retval="";
retval+="<title>iVend Store Orders</title>"
  "<body bgcolor=white text=navy>"
  "<img src=\"/ivend/ivend-image/ivendlogosm.gif\"> &nbsp;"
  "<img src=\"/ivend/ivend-image/admin.gif\"> &nbsp;"
  "<gtext fg=maroon nfont=bureaothreeseven black>"
  +id->misc->ivend->config->name+
  " Orders</gtext><p>"
  "<font face=helvetica,arial size=+1>"
  "<a href=./>Storefront</a> &gt; <a href=./admin>Admin</a> &gt; <a href=./orders>Orders</a><p>\n";


 mixed d=modules[id->misc->ivend->config->order_module]->show_orders(id, 
   id->misc->ivend->db);
 if(stringp(d))
 retval+=d;


return retval;

}

mixed shipping_handler(string filename, object id){

if(id->auth==0)
  return http_auth_required("iVend Store Shipping",
	"Silly user, you need to login!"); 
else if(!get_auth(id)) 
  return http_auth_required("iVend Store Shipping",
	"Silly user, you need to login!");

string retval="";
retval+="<title>iVend Shipping Administration</title>"
  "<body bgcolor=white text=navy>"
  "<img src=\"/ivend/ivend-image/ivendlogosm.gif\"> &nbsp;"
  "<img src=\"/ivend/ivend-image/admin.gif\"> &nbsp;"
  "<gtext fg=maroon nfont=bureaothreeseven black>"
  +id->misc->ivend->config->name+
  " Shipping</gtext><p>"
  "<font face=helvetica,arial size=+1>"
  "<a href=index.html>Storefront</a> &gt; <a href=admin>Admin</a> &gt; <a "
  "href=shipping>Shipping</a><p>\n";


 mixed d=modules[id->misc->ivend->config->shipping_module]->shipping_admin(id);
 if(stringp(d))
 retval+=d;


return retval;

}

mixed getmodify(string type, string pid, object id){

return "";

}

mixed admin_handler(string filename, object id){

if(id->auth==0)
  return http_auth_required("iVend Store Administration",
	"Silly user, you need to login!"); 
else if(!get_auth(id)) 
  return http_auth_required("iVend Store Administration",
	"Silly user, you need to login!");

string retval="";
retval+="<title>iVend Store Administration</title>"
  "<body bgcolor=white text=navy>"
  "<img src=\"/ivend/ivend-image/ivendlogosm.gif\"> &nbsp;"
  "<img src=\"/ivend/ivend-image/admin.gif\"> &nbsp;"
  "<gtext fg=maroon nfont=bureaothreeseven black>"
  +id->misc->ivend->config->name+
  " Administration</gtext><p>"
  "<font face=helvetica,arial size=+1>"
  "<a href=index.html>Storefront</a> &gt; <a href=admin>Admin</a>\n";

switch(id->variables->mode){

  case "doadd":
  object s=iVend.db(
    id->misc->ivend->config->dbhost,
    id->misc->ivend->config->db,
    id->misc->ivend->config->dblogin,
    id->misc->ivend->config->dbpassword
    );
  mixed j=s->addentry(id,id->referrer);
  retval+="<br>";
  if(stringp(j))
    return retval+= "The following errors occurred:<p>" + j;


  string type=(id->variables->table-"s");
  return http_string_answer(parse_rxml(retval+type+" Added Sucessfully.",id));
  break;

  case "add":
  object s=iVend.db(
    id->misc->ivend->config->dbhost,
    id->misc->ivend->config->db,
    id->misc->ivend->config->dblogin,
    id->misc->ivend->config->dbpassword
    );
  retval+="&gt <b>Add New " + capitalize(id->variables->type) +"</b><br>\n";

  if(id->variables->type="group")
    retval+="<table>\n"+s->gentable("products","./admin","groups", 
	"product_groups", id)+"</table>\n";
  else if(id->variables->type=="product")
    retval+="<table>\n"+s->gentable("groups","./admin",0,0,id)+"</table>\n";
  break;

  case "dodelete":
//  perror("doing delete...\n");
  object s=iVend.db(
    id->misc->ivend->config->dbhost,
    id->misc->ivend->config->db,
    id->misc->ivend->config->dblogin,
    id->misc->ivend->config->dbpassword
    );
  if(id->variables->confirm){
    if(id->variables->id==0 || id->variables->id=="") 
      retval+="You must select an ID to act upon!<br>";
    else retval+=s->dodelete(id->variables->type, id->variables->id);  }
  else {
    if(id->variables->match) {
    mixed n=s->showmatches(id->variables->type, id->variables->id);
    if(n)
      retval+="<form action=./admin>\n"
        + n +
        "<input type=hidden name=mode value=dodelete>\n"
        "<input type=submit value=Delete>\n</form>";
    else retval+="No " + capitalize(id->variables->type) + " found.";
    }
    else {
      mixed n=s->showdepends(id->variables->type, id->variables->id);
      if(n){ 
        retval+="<form action=./admin>\n"
          "<input type=hidden name=mode value=dodelete>\n"
          "<input type=hidden name=type value="+id->variables->type+">\n"
          "<input type=hidden name=id value="+id->variables->id+">\n"
          "Are you sure you want to delete the following?<p>";
          retval+=n+"<input type=submit name=confirm value=\"Really Delete\"></form><hr>";
        }
      else retval+="Couldn't find "+capitalize(id->variables->type) +" "
        +id->variables->id+".<p>";
      }

    }

    case "delete":
    retval+="<form action=./admin>\n"
      "<input type=hidden name=mode value=dodelete>\n"
      +capitalize(id->variables->type) + " ID to Delete: \n"
      "<input type=text size=10 name=id>\n"
      "<input type=hidden name=type value=" + id->variables->type + ">\n"
      "<br><font size=2>If using FindMatches, you may type any part of an ID"
      " or Name to search for.<br></font>"
      "<input type=submit name=match value=FindMatches> &nbsp; \n"
      "<input type=submit value=Delete>\n</form>";
  break;

  case "clearsessions":
  clean_sessions(id);	
  retval+="Sessions Cleaned Successfully.<p><a href=\"./admin\">"
	"Return to Administration Menu.</a>\n";
  break;

  case "getmodify":

  retval+=getmodify(id->variables->type, id->variables->id, id);

  break;

  case "modify":
    retval+="<form action=./admin>\n"
      "<input type=hidden name=mode value=getmodify>\n"
      "ID to Modify: \n"
      "<input type=text size=10 name=id>\n"
      "&nbsp; <input type=radio name=type selected value=product>\n"
      "Product &nbsp; <input type=radio name=type value=group>\n"
      "Group<p>"
      "<input type=submit value=Modify>\n</form>";
  break;

  default:
  retval+= "<ul>\n"
    "<li><a href=\"orders\">Orders</a>\n"
    "</ul>\n"
    "<ul>\n"
    "<li>Groups\n"
    "<ul>"
    "<li><a href=\"admin?mode=add&type=group\">Add New Group</a>\n"
    "<li><a href=\"admin?mode=modify&type=group\">Modify a Group</a>\n"
    "(Non Functional)\n"
    "<li><a href=\"admin?mode=delete&type=group\">Delete a Group</a>\n"
    "</ul>"
    "<li>Products\n"
    "<ul>"
    "<li><a href=\"admin?mode=add&type=product\">Add New Product</a>\n"
    "<li><a href=\"admin?mode=modify&type=product\">Modify a Product</a>\n"
    "(Non Functional)\n"
    "<li><a href=\"admin?mode=delete&type=product\">Delete a Product</a>\n"
    "</ul>"
    "</ul>\n"
    "<ul>\n"
    "<li><a href=\"admin?mode=clearsessions\">Clear Stale Sessions</a>\n"
    "</ul>\n"
    "<ul>\n"
    "<li><a href=\"shipping\">Shipping Administration</a>\n";



  break;

}

return retval;  
return http_string_answer(
    parse_rxml(parse_html(retval,([]),
        (["a":container_ia, "form":container_form]),id),id));

}

mixed get_image(string filename, object id){

// perror("** "+config[id->misc->ivend->st]->root+filename+"\n\n");

string data=Stdio.read_bytes(
	config[id->misc->ivend->st]->root+"/"+filename);
id->realfile=config[id->misc->ivend->st]->root+"/"+filename;

return http_string_answer(data,
	id->conf->type_from_filename(id->realfile));

}

string create_index(object id){
string retval="";
retval=Stdio.read_bytes(query("datadir")+"index.html");
return retval;
}

mixed getsessionid(object id) {

  return id->misc->ivend->SESSIONID;

}

void handle_sessionid(object id) {


  if(!id->variables->SESSIONID) 
    id->misc->ivend->SESSIONID=
      "S"+(string)hash((string)time(1)+(string)random(32201));	
    else id->misc->ivend->SESSIONID=id->variables->SESSIONID;

  m_delete(id->variables,"SESSIONID");

}

mixed return_data(mixed retval, object id){

  if(stringp(retval)){

	retval=parse_rxml(retval, id);
   	return http_string_answer(retval,
		id->conf->type_from_filename(id->realfile|| "index.html"));
	}

  else return retval;

}


mixed find_file(string file_name, object id){

  id->misc["ivend"]=([]);
  id->misc["ivendstatus"]="";
  string retval;

  array(string) request=(file_name / "/") - ({""});


  if(sizeof(config)==1 && getglobalvar("move_onestore")=="yes") 
    id->misc->ivend->st=indices(config)[0];
  else  if(sizeof(request)==0 && getglobalvar("create_index")=="yes")
    retval=create_index(id);
  else if(sizeof(request)==0)
    retval="you must enter through a store!\n";
  else {
    id->misc->ivend->st=request[0];
    request=request[1..];
    }

  switch(id->misc->ivend->st){
	
    case "config":
    return configuration_interface(request, id);
    break;
		
    case "ivend-image":
    return ivend_image(request, id);
    break;
		
    default:

    handle_sessionid(id);
    break;
	
    }
	
  if(retval) return return_data(retval, id);

  if(!config[id->misc->ivend->st]) 
    return return_data("NO SUCH STORE!", id);

  if(catch(request[0]))
    request+=({""});

// load id->misc->ivend with the good stuff...
  id->misc->ivend->config=config[id->misc->ivend->st];	


  switch(request[0]) {
    case "images":
    break;
    default:
    id->misc->ivend->db=iVend.db(
      id->misc->ivend->config->dbhost,
      id->misc->ivend->config->db,
      id->misc->ivend->config->dblogin,
      id->misc->ivend->config->dbpassword
    );

  }

// perror("REQUEST[0]: " + request[0] + "\n");

  switch(request[0]) {
    case "":
      return http_redirect(id->not_query +
        "/index.html?SESSIONID="+getsessionid(id), id);
    case "index.html":
    retval=(handle_page("index.html", id));
    break;
    case "cart":
    retval=(handle_cart(id->misc->ivend->st,id));
    break;
    case "checkout":
    retval=(handle_checkout(id));
    break;
    case "images":
    return get_image(request*"/", id);
    break;
    case "admin":
    perror("ADMIN!\n");
    retval=admin_handler(request*"/", id);
    break;
    case "orders":
    perror("ORDERS!\n");
    retval=order_handler(request*"/", id);
    break;
    case "shipping":
    perror("SHIPPING!\n");
    retval=shipping_handler(request*"/", id);
    break;
    default:
    perror("DEFAULT!\n");
    retval=(handle_page(request*"/", id));

    }

  return return_data(retval, id);

}

string|void container_ivml(string name, mapping args,
                      string contents, object id)
{

if(!id->misc->ivend) return "<!-- not in iVend! -->\n\n"+contents;

 mapping tags=    ([
	"ivstatus":tag_ivstatus, 
	"ivmg":tag_ivmg, 
	"listitems":tag_listitems
    ]);


 mapping containers= ([
	"a":container_ia, 
	"form":container_form,
	"icart":container_icart, 
	"ivindex":container_ivindex,
	"category_output":container_category_output
    ]);

if(id->misc->ivend->st){

if(functionp( modules[id->misc->ivend->config->checkout_module
    ]->query_container_callers))
containers+=  modules[id->misc->ivend->config->checkout_module
    ]->query_container_callers();

if(functionp( modules[id->misc->ivend->config->checkout_module
    ]->query_tag_callers))
tags+=  modules[id->misc->ivend->config->checkout_module
    ]->query_tag_callers();

if(functionp( modules[id->misc->ivend->config->shipping_module
    ]->query_container_callers))
containers+= modules[id->misc->ivend->config->shipping_module
    ]->query_container_callers();

if(functionp( modules[id->misc->ivend->config->shipping_module
    ]->query_tag_callers))
tags+= 
  modules[id->misc->ivend->config->shipping_module
    ]->query_tag_callers();
}


  id->misc->ivend->modules=modules;
 return "<html>"+parse_html(contents,
       tags,containers,id) +"</html>";

}

mapping query_container_callers()
{
  return ([ "ivml": container_ivml ]); }

mapping query_tag_callers()
{
  return ([ "ivendlogo" : tag_ivendlogo,
	"sessionid" : tag_sessionid ]); }

