/*
 * ivend.pike: Electronic Shopping for Roxen.
 *
 * Bill Welliver <hww3@riverweb.com>
 *
 */

#include <module.h>
#include <stdio.h>
#include <simulate.h>

inherit "module";
inherit "roxenlib";
inherit "wizard";

mapping(string:mapping(string:mixed)) config=([]) ;
object c;			// configuration object
int save_status=1; 		// 1=we've saved 0=need to save.

string cvs_version = "$Id: ivend.pike,v 1.15 1998-02-03 00:54:07 hww3 Exp $";

/*
 *
 * register_module() is required.
 *
 */

array register_module(){

   return( {
            MODULE_LOCATION | MODULE_PARSER,
            "iVend 1.0",
            "iVend enables online shopping within Roxen.",
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

   defvar("datadir", "/home/roxen/share/ivend/", "iVend Root Location",
          TYPE_DIR,
          "This is location where iVend will store "
          "various files nessecary for operation.");

   defvar("config_user", "ivend", "Configuration User",
	  TYPE_STRING,
	  "This is the username to use when accessing the iVend Configuration "
	  "interface.");

   defvar("config_password", "", "Configuration Password",
	  TYPE_STRING,
	  "The password to use when accessing the iVend Configuration "
	  "interface.");
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


mixed handle_search(object id){

return "";
}

int clean_sessions(object id){
string st=id->misc->ivend->st;
object s=Sql.sql(
	config[st]->dbhost, 
	config[st]->db, 
	config[st]->user, 
	config[st]->password
	);
string query="DELETE FROM sessions WHERE timeout < "+time(0);
s->query(query);
perror(query);
return 0;
}

array|int size_of_image(string filename){

  object fop;
  string sizes;
  array res = ({ 0,0 });
  fop = Stdio.File();
  if(!fop->open(filename, "r")) return 0;
  fop->seek(6); 
  sizes = fop->read(4);
  if(!sizes || (strlen(sizes) < 4)) return 0; // To short file
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
  +id->misc->ivend->st+"/"+id->misc->page+".ivml?SESSIONID="
  +id->misc->ivend->SESSIONID+"&ADDITEM="+id->misc->page+
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
else return "HAHAHAHA";
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
    if(!id->misc->ivend->st) return "You can't access your cart from here.";
    else string st=id->misc->ivend->st;

if(id->variables->update) {

  object s=Sql.sql(config[st]->dbhost, config[st]->db, config[st]->user, config[st]->password);

    for(int i=0; i< (int)id->variables->s; i++){

    if((int)id->variables["q"+(string)i]==0)
	s->query("DELETE FROM sessions WHERE SESSIONID="
	+id->misc->ivend->SESSIONID+
	  " AND id='"+id->variables["p"+(string)i]+"' AND series="+
	  id->variables["s"+(string)i] );
    else
        s->query("UPDATE sessions SET quantity="+id->variables["q"+(string)i]+
	  " WHERE SESSIONID="+id->misc->ivend->SESSIONID+" AND id='"+
	  id->variables["p"+(string)i]+ "' AND series="+ id->variables["s"+(string)i] );

    }

}

  string field;

  string retval=lower_case(contents);
  if(!id->misc->ivend->SESSIONID) return retval+"blah";
  else {
    retval+="<form action=\""+id->not_query+"\" method=post>\n<table>\n";
    object s=Sql.sql(config[st]->dbhost, config[st]->db, config[st]->user, config[st]->password);
    if(!args->fields) return "Incomplete cart configuration!";
    array r= s->query("SELECT sessions.id,series,quantity,name,price,"+ 
	args->fields+" FROM sessions,products "
      "WHERE sessions.SESSIONID="
	+id->misc->ivend->SESSIONID+" AND sessions.id=products.id");
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

	retval+="<td align=right>"
	+sprintf("$%.2f",r[i]->price)+"</td>\n"
	"<TD><INPUT TYPE=TEXT SIZE=3 NAME=q"+i+" VALUE="+
        r[i]->quantity+"></td><td align=right>"
	+sprintf("$%.2f",r[i]->quantity*r[i]->price)+"</td></tr>\n";
      }
    retval+="</table>\n<input type=hidden name=s value="+sizeof(r)+">\n"
	"<input type=hidden value=1 name=update>\n<input type=submit value=\"Update Cart\"></form>\n";
    return parse_rxml(parse_html(retval,([]),
        (["a":container_ia, "form":container_form]),id),id);
 
    }
  
}


string tag_listitems(string tag_name, mapping args,
                    object id, mapping defines)

{

string retval="";

if(!id->misc->page) return "no page!";
string st=id->misc->ivend->st;

object s=Sql.sql(config[st]->dbhost, config[st]->db, config[st]->user, config[st]->password);
array r;
if(args->type=="groups") {
  r=s->query("SELECT id AS pid,"+args->fields+ " FROM groups");
  }
else {

  r=s->query("SELECT product_id AS pid,"+args->fields+
	" FROM product_groups,products where group_id='"+id->misc->page+"'"
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
        thisrow[n]=("<A HREF=\""+row->pid+".ivml\">"+row[t]+"</A>");
      else
        thisrow[n]=row[t]; 
      n++;

    }
  rows[p]=thisrow;
  p++;
  }

retval+=html_table(titles, rows);
    return parse_html(retval,([]),
        (["a":container_ia, "form":container_form]),id);

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
  object s=Sql.sql(config[st]->dbhost, config[st]->db, config[st]->user, config[st]->password);
  r=s->query("SELECT "+args->field+ " FROM "+id->misc->ivend->type+"s WHERE "
	" id='"+id->misc->ivend->id+"'");
  if (sizeof(r)!=1) return "";
  else filename=config[id->misc->ivend->st]->root+"/images/"+
    id->misc->ivend->type+"s/"+r[0][args->field]+".gif";
  }  
else if(args->src!="") 
filename=config[id->misc->ivend->st]->root+"/images/"+args->src+".gif";
// perror("getting image "+filename+"\n");

array|int size=size_of_image(filename);

if(size==0) return "";
else return ("<IMG SRC=\""+query("mountpoint")+st+"/images/"
      +id->misc->ivend->type+"s/"+r[0][args->field]+".gif\""
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
  if(c=="global") continue;
string d="";
foreach(indices(config[c]),d){
  s=replace(s,("#"+d+"#"),config[c][d]);
  }
  s=replace(s,"#id#",c);
  retval+=s;
}

return parse_rxml(retval,id);
}

int read_conf(){          // Read the config data.

string current_config="";
string attribute;
string value;

c=iVend.config();
if(!c->load_config_defs(Stdio.read_file(query("datadir")+"ivend.cfd")))
   perror("iVend: ERROR LOADING CONFIGURATION DEFINITION!\n");

#ifdef MODULE_DEBUG
// perror("iVend: reading configuration file "+query("datadir")+"ivend.cnf\n");
#endif
array(string) config_file= read_file(query("datadir")+"ivend.cfg")/"\n";

for (int i=0; i<sizeof(config_file);i++){

#ifdef MODULE_DEBUG
// perror("iVend: config file line "+i+"\n");
#endif

	if(config_file[i][0..4]=="start"){

#ifdef MODULE_DEBUG
// perror("iVend: parsing section "+config_file[i][6..]+"\n");
#endif

		current_config=config_file[i][6..];		
		}
	else if(config_file[i]=="end") break;
	else if(config_file[i][0..0]=="$"){
// perror("iVend: we've got a parameter...\n");
		array(mixed) current_line=config_file[i][1..]/"=";
#ifdef MODULE_DEBUG
// perror("iVend: config: "+current_config+" parameter: "+current_line[0]+" value: "+current_line[1]+"\n");
#endif
	attribute=current_line[0];
	value=current_line[1];
	if(!config[current_config])
		config[current_config]= ([attribute:value]);
	else config[current_config][attribute]=value;

		}
	}

}

/*
 *
 *  start(): set up shop...
 *
 *  do anything required before we are able to service requests
 *
 */

void start(){

   	if(file_stat(query("datadir")+"ivend.cfg")==0) return; 
   	else  read_conf();   // Read the config data.
   	return;	

}

mixed handle_error(string error, object id){
string retval;
if(!(retval=Stdio.read_file(config[id->misc->ivend->st]->root+"/error.ivml")))
  retval="<title>iVend Error</title>\n<h2>iVend Error</h2>\n"
	"The following error has occurred:<p><error><p>\n"
	"Please contact the administrator for assistance.";
return replace(retval,"<error>",error);

// return "error!  "+page+" in "+st;

}

mixed handle_cart(string st, object id){
#ifdef MODULE_DEBUG
perror("iVend: handling cart for "+st+"\n");
#endif

string retval;
if(!(retval= Stdio.read_bytes(id->misc->ivend->config->root+"/cart.ivml")))
  return handle_error(id->misc->ivend->config->root+"/cart.ivml",id);
 
    return parse_rxml(parse_html(retval,([]),
        (["a":container_ia, "form":container_form]),id),id);

}

mixed parse_page(string page, array(mapping(string:string)) r, array desc){

string field;
array fields=indices(r[0]);

for(int i=0; i<sizeof(desc); i++){
  // page+=field +": "+r[0][field];
  if(desc[i]->type=="decimal") {
    string 
page2=replace(page,("#"+desc[i]->name+"#"),sprintf("%.2f",(float)(r[0][desc[i]->name])));
  }
  else 
  string page2=replace(page,("#"+desc[i]->name+"#"),(string)r[0][desc[i]->name]);
  page=page2;
  }


return page;
}

mixed find_page(string page, string st, object id){
#ifdef MODULE_DEBUG
perror("iVend: finding page "+ page+" in "+st+"\n");
#endif

string retval;
object s=Sql.sql(config[st]->dbhost, config[st]->db, 
	config[st]->user, config[st]->password);

page=page-".ivml";	// get to the core of the matter.
id->misc->ivend->id=page;
string template;
array(mapping(string:string)) r;
array f;
r=s->query("SELECT * FROM groups WHERE id='"+page+"'");
if (sizeof(r)==1){
  id->misc->ivend->type="group";
  template="group_template.ivml";
  f=s->list_fields("groups");
  }
else {
  r=s->query("SELECT * FROM products WHERE id='"+page+"'");
  id->misc->ivend->type="product";
  template="product_template.ivml";
  f=s->list_fields("products");

  }
if (sizeof(r)!=1) 
return 0;

retval=Stdio.read_bytes(config[st]->root+"/"+template);
if (catch(sizeof(retval)))
  return 0;

// retval="find_page("+page+", s, id)";
return parse_page(retval, r, f);
}

mixed additem(string item, object id){

object s=Sql.sql(config[id->misc->ivend->st]->dbhost, 
config[id->misc->ivend->st]->db, 
	config[id->misc->ivend->st]->user, config[id->misc->ivend->st]->password);

int max=sizeof(s->query("select id FROM sessions WHERE SESSIONID="+
  id->misc->ivend->SESSIONID+" AND id='"+item+"'"));
string query="INSERT INTO sessions VALUES("+ id->misc->ivend->SESSIONID+
  ",'"+item+"',1,"+(max+1)+",'Standard','"+(time(0)+
  (int)id->misc->ivend->config->session_timeout)+"')";
perror(query+"\n");
if(catch(s->query(query) ))
	id->misc["ivendstatus"]+=("Error adding item "+item+ ".\n"); 
else 
  id->misc["ivendstatus"]+=("Item "+item+ " added successfully.\n"); 
return 0;
}

mixed handle_page(string page,string st,object id){
#ifdef MODULE_DEBUG
perror("iVend: handling page "+st+" "+ page+"\n");
#endif

id->misc["page"]=page-".ivml";
if(id->variables->ADDITEM) additem(id->variables->ADDITEM,id);
mixed retval;

switch(page){

  case "index.ivml":
// perror("reading "+config[st]->root+"/index.ivml");
    retval= Stdio.read_bytes(config[st]->root+"/index.ivml"); 
    break;

  case "search":
    retval=handle_search(id);
    break;

  default:
    if(retval=Stdio.read_bytes(config[st]->root+"/"+lower_case(page))) break;
    else retval=find_page(page, st, id);
  }
  if (!retval) return handle_error("Unable to find product "+page, id);
    return parse_rxml(parse_html(retval,([]),
        (["a":container_ia, "form":container_form]),id),id);
 

// return (string)(retval+" "+page+" "+dump_id(id));
}

mapping ivend_image(array(string) request, object id){

	string image;
	image=read_file(query("datadir")+"images/"+request[1]);

	return http_string_answer(image,"image/gif");

}

mixed handle_checkout(object id){
mixed retval;
object c=clone(compile_file(id->misc->ivend->config->root+"/modules/"+
	id->misc->ivend->config->checkout_module));
retval=c->checkout(id);
if(retval==-1) return handle_page("index.ivml",id->misc->ivend->st,id);
else 
    return parse_rxml(parse_html(retval,([]),
        (["a":container_ia, "form":container_form]),id),id); 
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
// perror(query("config_password")+" "+query("config_user")+"\n");
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

	string retval="";
	if(catch(request[1])) return http_redirect(query("mountpoint")+"config/configs",id);
	retval+="<HTML>\n"
"	<HEAD>\n"
"		<TITLE>iVend Configuration</TITLE>\n"
"	</HEAD>\n"
"	<BODY BGCOLOR=\"White\" BACKGROUND=\""+query("mountpoint")+"ivend-image/ivendbg.gif\" TEXT=\"#000066\" LINK=\"#000066\">\n"
"		<CENTER><FONT COLOR=\"White\"><TABLE COOL WIDTH=\"786\" BORDER=\"0\" CELLPADDING=\"0\" CELLSPACING=\"0\">\n"
"			<TR HEIGHT=\"8\">\n"
"				<TD WIDTH=\"32\" HEIGHT=\"8\"><SPACER TYPE=\"BLOCK\" WIDTH=\"32\" HEIGHT=\"8\"></TD>\n"
"				<TD WIDTH=\"186\" HEIGHT=\"8\"><SPACER TYPE=\"BLOCK\" WIDTH=\"186\" HEIGHT=\"8\"></TD>\n"
"				<TD WIDTH=\"6\" HEIGHT=\"8\"><SPACER TYPE=\"BLOCK\" WIDTH=\"6\" HEIGHT=\"8\"></TD>\n"
"				<TD WIDTH=\"186\" HEIGHT=\"8\"><SPACER TYPE=\"BLOCK\" WIDTH=\"186\" HEIGHT=\"8\"></TD>\n"
"				<TD WIDTH=\"6\" HEIGHT=\"8\"><SPACER TYPE=\"BLOCK\" WIDTH=\"6\" HEIGHT=\"8\"></TD>\n"
"				<TD WIDTH=\"186\" HEIGHT=\"8\"><SPACER TYPE=\"BLOCK\" WIDTH=\"186\" HEIGHT=\"8\"></TD>\n"
"				<TD WIDTH=\"182\" HEIGHT=\"8\"><SPACER TYPE=\"BLOCK\" WIDTH=\"182\" HEIGHT=\"8\"></TD>\n"
"			</TR>\n";

// Do filefolder tabs

	switch(request[1]){
	
		case "status": {
		retval+=
"			<TR HEIGHT=\"28\">\n"
"			<TD WIDTH=\"32\" HEIGHT=\"28\"><SPACER TYPE=\"BLOCK\" WIDTH=\"32\" HEIGHT=\"28\"></TD>\n"
"			<TD WIDTH=\"186\" HEIGHT=\"28\" COLSPAN=\"1\" ROWSPAN=\"1\" VALIGN=\"top\" ALIGN=\"left\" XPOS=\"32\"><A "
"			HREF=\""+query("mountpoint")+"config/configs\"><IMG SRC=\""+query("mountpoint")+"ivend-image/configurationsunselect.gif\" "
"			WIDTH=\"186\" HEIGHT=\"28\" BORDER=\"0\" ALT=\"/  Configurations  \\\"></A></TD>\n"
"			<TD WIDTH=\"6\" HEIGHT=\"28\"><SPACER TYPE=\"BLOCK\" WIDTH=\"6\" HEIGHT=\"28\"></TD>\n"
"			<TD WIDTH=\"186\" HEIGHT=\"28\" COLSPAN=\"1\" ROWSPAN=\"1\" VALIGN=\"top\" ALIGN=\"left\" XPOS=\"224\">"
"<A HREF=\""+query("mountpoint")+"config/global\"><IMG SRC=\""+query("mountpoint")+"ivend-image/globalunselect.gif\" WIDTH=\"186\" HEIGHT=\"28\" BORDER=\"0\" ALT=\"/ Global Variables \\\"></A></TD>\n"
"			<TD WIDTH=\"6\" HEIGHT=\"28\"><SPACER TYPE=\"BLOCK\" WIDTH=\"6\" HEIGHT=\"28\"></TD>\n"
"			<TD WIDTH=\"186\" HEIGHT=\"28\" COLSPAN=\"1\" ROWSPAN=\"1\" VALIGN=\"top\" ALIGN=\"left\" XPOS=\"416\"><A HREF=\""+query("mountpoint")+"config/status\"><IMG SRC=\""+query("mountpoint")+
"ivend-image/statusselect.gif\" WIDTH=\"186\" HEIGHT=\"28\" BORDER=\"0\" ALT=\"/        Status        \\\"></A></TD>\n"
"				<TD WIDTH=\"182\" HEIGHT=\"28\"><SPACER TYPE=\"BLOCK\" WIDTH=\"182\" HEIGHT=\"28\"></TD>\n"
"			</TR>\n";
		
		break; 
		
		}
		
		case "save": {
		
		return write_configuration(id);
		
		break;
		
		}
		
		case "global": {
if(!catch(request[2]) && request[2]=="save")
{
// perror("SAVING CHANGES...\n");
array(string) vars=indices(id->variables);
string v;
foreach((vars),v){

  if(!config->global) config["global"]=([v:id->variables[v]]);

  else config["global"][v]=id->variables[v];
}

save_status=0;	// we need to save.
}
		
		retval+=
"			<TR HEIGHT=\"28\">\n"
"			<TD WIDTH=\"32\" HEIGHT=\"28\"><SPACER TYPE=\"BLOCK\" WIDTH=\"32\" HEIGHT=\"28\"></TD>\n"
"			<TD WIDTH=\"186\" HEIGHT=\"28\" COLSPAN=\"1\" ROWSPAN=\"1\" VALIGN=\"top\" ALIGN=\"left\" XPOS=\"32\"><A "
" HREF=\""+query("mountpoint")+"config/configs\"><IMG SRC=\""+query("mountpoint")+"ivend-image/configurationsunselect.gif\" "
" WIDTH=\"186\" HEIGHT=\"" "	28\" BORDER=\"0\" ALT=\"/  Configurations  \\\"></A></TD>\n"
"			<TD WIDTH=\"6\" HEIGHT=\"28\"><SPACER TYPE=\"BLOCK\" WIDTH=\"6\" HEIGHT=\"28\"></TD>\n"
"			<TD WIDTH=\"186\" HEIGHT=\"28\" COLSPAN=\"1\" ROWSPAN=\"1\" VALIGN=\"top\" ALIGN=\"left\" XPOS=\"224\"><A HREF=\""+query("mountpoint")+"config/global\"><IMG SRC=\""+query("mountpoint")+"ivend-image/globalselect.gif\" WIDTH=\"186\" HEIGHT=\"28\""
" BORDER=\"0\" ALT=\"/ Global Variables \\\"></A></TD>\n"
"			<TD WIDTH=\"6\" HEIGHT=\"28\"><SPACER TYPE=\"BLOCK\" WIDTH=\"6\" HEIGHT=\"28\"></TD>\n"
"			<TD WIDTH=\"186\" HEIGHT=\"28\" COLSPAN=\"1\" ROWSPAN=\"1\" VALIGN=\"top\" ALIGN=\"left\" XPOS=\"416\"><A HREF=\""+query("mountpoint")+"config/status\"><IMG SRC=\""+query("mountpoint")+"ivend-image/statusunselect.gif\" WIDTH=\"186\" HEIGHT=\"28\""
" BORDER=\"0\" ALT=\"/        Status        \\\"></A></TD>\n"
"			<TD WIDTH=\"182\" HEIGHT=\"28\"><SPACER TYPE=\"BLOCK\" WIDTH=\"182\" HEIGHT=\"28\"></TD>\n"
"			</TR>\n"
"<TD COLSPAN=6><BR><BLOCKQUOTE><P ALIGN=\"LEFT\"><FONT SIZE=+2 FACE=\"times\">"
"Global Variables</FONT><P>\n"
"<FORM METHOD=POST ACTION=\""+query("mountpoint")+"config/global/save\">\n"
"<TABLE><TR>\n"
"<TD>Generate Store Index?<BR><FONT SIZE=0>Should iVend create an index of all stores?</FONT></TD>\n"
"<TD><select NAME=\"create_index\"><OPTION";

if(catch(config->global->create_index) ||
config->global->create_index=="yes")
retval+=" SELECTED>yes<OPTION>no</SELECT>\n";
else retval+=">yes<OPTION SELECTED>no</SELECT>\n";
retval+="</TD></TR>\n"
"<TR><TD><INPUT TYPE=SUBMIT VALUE=\" Update Variables \"></TD><TD>&nbsp;</TD></TR>\n" 
"</TABLE></FORM>\n"
"</TD></TR>";
		break;
		
		}
		
		case "configs":
		default:
		
		{
		
		retval+=
"			<TR HEIGHT=\"28\">\n"
"				<TD WIDTH=\"32\" HEIGHT=\"28\"><SPACER TYPE=\"BLOCK\" WIDTH=\"32\" HEIGHT=\"28\"></TD>\n"
"				<TD WIDTH=\"186\" HEIGHT=\"28\" COLSPAN=\"1\" ROWSPAN=\"1\" VALIGN=\"top\" ALIGN=\"left\" XPOS=\"32\"><A HREF=\""+query("mountpoint")+"config/configs\"><IMG SRC=\""+query("mountpoint")+"ivend-image/configurationsselect.gif\" "
 "WIDTH=\"186\" HEIGHT=\"28\"" 
" BORDER=\"0\" ALT=\"/  Configurations  \\\"></A></TD>\n"
"				<TD WIDTH=\"6\" HEIGHT=\"28\"><SPACER TYPE=\"BLOCK\" WIDTH=\"6\" HEIGHT=\"28\"></TD>\n"
"				<TD WIDTH=\"186\" HEIGHT=\"28\" COLSPAN=\"1\" ROWSPAN=\"1\" VALIGN=\"top\" ALIGN=\"left\" XPOS=\"224\"><A HREF=\""+query("mountpoint")+"config/global\"><IMG SRC=\""+query("mountpoint")+"ivend-image/globalunselect.gif\" WIDTH=\"186\" "
" HEIGHT=\"28\" BORDER=\"0\" ALT=\"/ Global Variables \\\"></A></TD>\n"
"				<TD WIDTH=\"6\" HEIGHT=\"28\"><SPACER TYPE=\"BLOCK\" WIDTH=\"6\" HEIGHT=\"28\"></TD>\n"
"				<TD WIDTH=\"186\" HEIGHT=\"28\" COLSPAN=\"1\" ROWSPAN=\"1\" VALIGN=\"top\" ALIGN=\"left\" XPOS=\"416\"><A HREF=\""+query("mountpoint")+"config/status\"><IMG SRC=\""+query("mountpoint")+"ivend-image/statusunselect.gif\" WIDTH=\"186\" "
" HEIGHT=\"28\" BORDER=\"0\" ALT=\"/        Status        \\\"></A></TD>\n"
"				<TD WIDTH=\"182\" HEIGHT=\"28\"><SPACER TYPE=\"BLOCK\" WIDTH=\"182\" HEIGHT=\"28\"></TD>\n"
"			</TR>\n"
"			<TR>\n"
"				<TD WIDTH=\"32\" HEIGHT=\"28\"><SPACER TYPE=\"BLOCK\" WIDTH=\"32\" HEIGHT=\"28\"></TD>\n";

		
		if(request[1]=="new"){
			
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
	(c->genform()||"Error Loading Configuration Definitions!")+
	"</table><p><input type=submit value=\"Add New Store\"></form>"
	"</TD></TR>";

			
			}
			
			
		
		
		
		else if(catch(request[2])){		// Haven't specified a configuration yet, so list 'em all.
		
			retval+="<TD COLSPAN=6><BR><BLOCKQUOTE><P ALIGN=\"LEFT\"><FONT SIZE=+2 FACE=\"times\">"
				"All Configurations</FONT><P>\n";
				
			array(string) all_configs=indices(config);
			
			for(int i=0; i<sizeof(all_configs); i++){
			
				if(all_configs[i]=="global") continue;		// Don't list global configs
				else retval+="<LI><FONT SIZE=+1 FACE=\"helvetica,arial\"><A HREF=\""+query("mountpoint")+"config/configs/"+all_configs[i]+"\">"
					+config[all_configs[i]]->name+"</A></FONT>\n";
			
				}

			retval+="<P><FONT FACE=\"times\" SIZE=+1>To View, Modify or Delete a Configuration, Click on it's name in the list above.</FONT><P>\n"
				"<A HREF=\""+query("mountpoint")+"config/new\">New Configuration</A> &nbsp; ";
			if(save_status!=1)
				retval+="<A HREF=\""+query("mountpoint")+"config/save\">Save Changes</A>";

			}
		
		
		
				
			
		else {					// OK, we know what we have in mind...

			if(id->variables->config_delete==1) {

				config=m_delete(config,request[2]);
				save_status=0;
				return http_redirect(query("mountpoint")+"config/configs?"+time(),id);				

				}			

			else if(!catch(request[3]) && request[3]=="config_modify") {
				array(string) variables= (indices(id->variables)- ({"config_modify"}));
                                for(int i=0; i<sizeof(variables); i++){
 
                                	config[id->variables->config][variables[i]]=id->variables[variables[i]];

                                        }
 
                                save_status=0;   
                                return http_redirect(query("mountpoint")+"config/configs/"+request[2]+"?"+time(),id);


				}

			else retval+="<TD COLSPAN=6><BR><BLOCKQUOTE><P ALIGN=\"LEFT\"><FONT SIZE=+2 FACE=\"times\">"
			+config[request[2]]->name+"</FONT><P>\n"
			"<FORM METHOD=POST ACTION=\""+query("mountpoint")+"config/configs/"+request[2]+"/config_modify\">\n"
			"<TABLE>"
			+(c->genform(config[request[2]])
			||"Error loading configuration definitions")+
			"</TABLE><p><input type=submit value=\"Modify Configuration\">"
			"</FORM>"
			"</TD></TR>";


			"<A HREF=\""+ query("mountpoint") +"config/configs/"+ request[2]+"?config_delete=1\">Delete Configuration</A>";

			
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

mixed 

admin_handler(string filename, object id){

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
  "<gtext fg=maroon nfont=helvetica black>"
  +id->misc->ivend->config->name+
  " Administration</gtext><p>"
  "<font face=helvetica,arial size=+1>"
  "<a href=./>Storefront</a> &gt; <a href=./admin>Admin</a><p>\n";

switch(id->variables->mode){

  case "doadd":
  object s=iVend.db(
    id->misc->ivend->config->dbhost,
    id->misc->ivend->config->db,
    id->misc->ivend->config->user,
    id->misc->ivend->config->password
    );
  mixed j=s->addentry(id,id->referrer);
//  return http_redirect(id->referrer, id);
  return http_string_answer(parse_rxml(retval+"Product Added Sucessfully.",id));
  break;

  case "addproduct":
  object s=iVend.db(
    id->misc->ivend->config->dbhost,
    id->misc->ivend->config->db,
    id->misc->ivend->config->user,
    id->misc->ivend->config->password
    );
  retval+=s->gentable("products","./admin","groups", 
	"product_groups", id->misc->ivend->SESSIONID);
  break;

  case "addgroup":
  object s=iVend.db(
    id->misc->ivend->config->dbhost,
    id->misc->ivend->config->db,
    id->misc->ivend->config->user,
    id->misc->ivend->config->password
    );
  retval+=s->gentable("groups","./admin",0,0,id->misc->ivend->SESSIONID);
  break;

  case "dodelete":
//  perror("doing delete...\n");
  object s=iVend.db(
    id->misc->ivend->config->dbhost,
    id->misc->ivend->config->db,
    id->misc->ivend->config->user,
    id->misc->ivend->config->password
    );
  if(id->variables->confirm){
    retval+=s->dodelete(id->variables->type, id->variables->id);  }
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

    case "delete":
    retval+="<form action=./admin>\n"
      "<input type=hidden name=mode value=dodelete>\n"
      "ID to Delete: \n"
      "<input type=text size=10 name=id>\n"
      "&nbsp; <input type=radio name=type default value=product>\n"
      "Product &nbsp; <input type=radio name=type value=group>\n"
      "Group<p>"
      "<input type=submit value=Delete>\n</form>";
  break;

  case "orders":
  retval+="Orders:\n";
  break;

  case "clearsessions":
  clean_sessions(id);	
  retval+="Sessions Cleaned Successfully.<p><a href=\"./admin\">"
	"Return to Administration Menu.</a>\n";
  break;

  default:
  retval+= "<ul>\n"
    "<li><a href=admin?mode=orders>Orders</a>\n"
    "</ul>\n"
    "<ul>\n"
    "<li><a href=\"admin?mode=addproduct\">Add New Product</a>\n"
    "<li><a href=\"admin?mode=addgroup\">Add New Group</a>\n"
    "<li><a href=\"admin?mode=modify\">Modify a Product/Group</a>\n"
    "<li><a href=\"admin?mode=delete\">Delete a Product/Group</a>\n"
    "</ul>\n"
    "<ul>\n"
    "<li><a href=\"admin?mode=clearsessions\">Clear Stale Sessions</a>\n";



  break;

}

  return http_string_answer(
    parse_rxml(parse_html(retval,([]),
        (["a":container_ia, "form":container_form]),id),id));

}

mixed get_image(string filename, object id){

string 
data=Stdio.read_bytes(config[id->misc->ivend->st]->root+"/images/"+filename);

return http_string_answer(data, "image/gif");

}

string create_index(object id){
string retval="";
string file=Stdio.read_bytes(query("datadir")+"index.ivml");
retval=parse_rxml(file,id);
return retval;
}

mixed find_file(string file_name, object id){
	id->misc["ivend"]=([]);
	id->misc["ivendstatus"]="";
	string retval="";
   	array(string) request=explode(file_name,"/");
	string restofrequest=request[2..]*"/";

if(file_name==""){
	  if (config->global->create_index=="yes")
	    retval=create_index(id);
	  else 
retval="You must enter through a store!\n";

   	return http_string_answer(retval);
}


	switch(request[0]){
	
		case "config":
		return configuration_interface(request, id);
		break;
		
		case "ivend-image":
		return ivend_image(request, id);
		break;
		
		default:
		break;
	
	}
	

	if(!id->variables->SESSIONID) 
	  id->misc->ivend->SESSIONID=
        	(hash((string)time(1)+(string)random(32201)));	
	else id->misc->ivend->SESSIONID=id->variables->SESSIONID;

	m_delete(id->variables,"SESSIONID");

	if(request[0] && catch(request[1])) 
		return http_redirect(query("mountpoint")+file_name+"/?SESSIONID="+
	         id->misc->ivend->SESSIONID);

	if(config[request[0]])
	  {
	    if(!config[request[0]]) return http_string_answer("NO SUCH STORE!");
            id->misc->ivend+=(["st":request[0], "config":config[request[0]] ]);	

	    if(catch(request[1])) {
//	      perror("iVend: no product specified.\n");
	      return http_string_answer(parse_rxml(handle_page("index.ivml", request[0], id),id));
	    }
	    else {
perror("finding request...\n");
              id->misc->ivend+=(["st":request[0], "config":config[request[0]] ]);	
// perror(sprintf("%O",id));	
	      switch(request[1]) {
		    case "":
	        case "index.ivml":
		  return http_string_answer(handle_page("index.ivml", request[0], id));
	          break;
		case "cart":
		  return http_string_answer(handle_cart(request[0], id));
		  break;
		case "checkout":
		  return http_string_answer(handle_checkout(id));
		  break;
		case "images":
		  return get_image(restofrequest, id);
		  break;
		case "admin":
		  perror("ADMIN!\n");
		  return admin_handler(restofrequest, id);
		  break;
		default:
perror("doing the default thing...\n");
		  return http_string_answer(handle_page(request[1], request[0], id));
		}
	    }
	  }

#ifdef MODULE_DEBUG	
//	retval+=dump_id(id);
#endif

   	return http_string_answer(retval);

}


mapping query_container_callers()
{
  return ([ "icart":container_icart, "ivindex":container_ivindex ]); }

mapping query_tag_callers()
{
  return ([ "ivstatus":tag_ivstatus, "ivmg":tag_ivmg, "listitems":tag_listitems ]); }
