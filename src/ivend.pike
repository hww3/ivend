/*
 * ivend.pike: Electronic Commerce for Roxen.
 *
 * Bill Welliver <hww3@riverweb.com>
 *
 */

#include "include/messages.h"
#include <module.h>
#include <stdio.h>
#include <simulate.h>

inherit "roxenlib";
inherit "module";
inherit "wizard";

#if __VERSION__ >= 0.6
import ".";
#endif
#if __VERSION__ < 0.6
int read_conf();          // Read the config data.
void load_modules(string c);
void start_db(mapping c);
void get_dbkeys(mapping c);
void background_session_cleaner();
float convert(float value, object id);
array|int size_of_image(string filename);
void error(mixed error, object id);
mapping configuration_interface(array(string) request, object id);
void handle_sessionid(object id);
mixed getglobalvar(string var);
mixed return_data(mixed retval, object id);
mixed  get_image(string filename, object id);
#endif

int loaded;

object c;                       // configuration object
object g;                       // global object   

mapping db=([]);		// db cache
mapping keys=([]);		// db keys cache
int num;

mapping(string:object) modules=([]);                    // module cache
mapping config=([]);
mapping global=([]);

int save_status=1;              // 1=we've saved 0=need to save.    

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


string getmwd(){

 string mwd=combine_path(combine_path(getcwd(), backtrace()[-1][0]), "..");
  catch { mwd=combine_path(combine_path(mwd, ".."), readlink(mwd)); };
  mwd=combine_path(mwd, "../");

//  perror("getmwd(): "+mwd + "\n\n");

  return mwd;
}




void create(){

   defvar("mountpoint", "/ivend/", "Mountpoint",
          TYPE_LOCATION,
          "This is where the module will be inserted in the "
          "namespace of your server.");

   defvar("root", getmwd() , 
	  "iVend Root Location",
          TYPE_DIR,
          "This is the root directory of the iVend distribution. "
          );

   defvar("datadir", getmwd() + "data" , 
	  "iVend Data Location",
          TYPE_DIR,
          "This is location where iVend will store "
          "data files nessecary for operation.");

   defvar("configdir", getmwd() + "configurations" , 
	  "iVend Configuration Directory",
          TYPE_DIR,
          "This is location where iVend will keep Store "
          "configuration files nessecary for operation.");

   defvar("config_user", roxen->query("ConfigurationUser") ,
	  "Configuration User",
	  TYPE_STRING,	  "This is the username to use when accessing the iVend Configuration "
	  "interface.");

   defvar("config_password", roxen->query("ConfigurationPassword") ,
	  "Configuration Password",
	  TYPE_PASSWORD,
	  "The password to use when accessing the iVend Configuration "
	  "interface.");

   defvar("lang", "en", "Default Language",
	  TYPE_MULTIPLE_STRING, "Default Language for Stores",
	  ({"en","si"})
	  );}


void start(){

num=0;
 add_include_path(getmwd() + "include");
// perror("iVend: added include path: "+getmwd()+"include\n"); 
add_module_path(getmwd()+"src");
// perror("iVend: added module path: "+getmwd()+"src\n"); 
  loaded=1;
if(catch(perror(query("datadir")))) return;

  if(file_stat(query("datadir")+"ivend.cfd")==0) 
      return; 
    else  read_conf();   // Read the config data.
  
  foreach(indices(config), string c)
    load_modules(config[c]->config);

  foreach(indices(config), string c)
    start_db(config[c]);

  foreach(indices(config), string c)
    get_dbkeys(config[c]);

  perror(sprintf("%O", keys));

  call_out(background_session_cleaner, 900);

  return;	

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


string|void container_ia(string name, mapping args,
                      string contents, object id)

{
if (catch(id->misc->ivend->SESSIONID)) return;

if (args["_parsed"]) return;

mapping arguments=([]);

arguments["_parsed"]="1";

if (arguments->external)
  arguments["href"]=args->href;

else if (args->add) 
  arguments["href"]="./"+id->misc->ivend->page+".html?SESSIONID="
  +id->misc->ivend->SESSIONID+"&ADDITEM="+id->misc->ivend->page;
else if(args->cart)
  arguments["href"]=query("mountpoint")+
    (id->misc->ivend->moveup?"":id->misc->ivend->st+ "/")
    +"cart?SESSIONID=" +id->misc->ivend->SESSIONID;
else if(args->checkout)
  arguments["href"]=query("mountpoint")+
    (id->misc->ivend->moveup?"":id->misc->ivend->st + "/")
    +"checkout?SESSIONID=" +id->misc->ivend->SESSIONID;
else if(args->href){
  int loc;
  if(loc=search(args->href,"?")==-1)
    arguments["href"]=args->href
    +"?SESSIONID=" +(id->misc->ivend->SESSIONID);  

  else  arguments["href"]=args->href
    +"&SESSIONID=" +(id->misc->ivend->SESSIONID);  

  }

if(arguments->href && args->template) arguments->href+="&template=" +
	args->template; 
  
  m_delete(args, "href");
  m_delete(args, "checkout");
  m_delete(args, "cart");
  m_delete(args, "add");
  m_delete(args, "template");

  arguments+=args;
  return make_container("A", arguments, contents);

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
string retval="";

st=id->misc->ivend->st;

string extrafields="";
array ef=({});
array en=({});

 if(args->fields){
   ef=args->fields/",";
   if(args->names)
   en=args->names/",";
   else en=({});
   for(int i=0; i<sizeof(ef); i++) {
     if(catch(en[i]) || !en[i])  en+=({ef[i]});
     extrafields+=", " + ef[i] + " AS " + "'" + en[i] + "'"; 
   }
 }

if(id->variables->update) {

    if(id->variables->update !=UPDATE_CART)
    return http_redirect(query("mountpoint") +
(  (sizeof(config)==1 && getglobalvar("move_onestore")=="Yes")
        ?"":st+"/")+"checkout/?SESSIONID=" + id->misc->ivend->SESSIONID);

    for(int i=0; i< (int)id->variables->s; i++){

    if((int)id->variables["q"+(string)i]==0)
	id->misc->ivend->db->query("DELETE FROM sessions WHERE SESSIONID='"
	+id->misc->ivend->SESSIONID+
	  "' AND id='"+id->variables["p"+(string)i]+"' AND series="+
	  id->variables["s"+(string)i] );
    else
   id->misc->ivend->db->query("UPDATE sessions SET "
      "quantity="+(int)(id->variables["q"+(string)i])+
	  " WHERE SESSIONID='"+id->misc->ivend->SESSIONID+"' AND id='"+
	  id->variables["p"+(string)i]+ "' AND series="+ id->variables["s"+(string)i] );

    }

}

  string field;


    retval+="<form action=\""+id->not_query+"\" method=post>\n<table>\n";

//    if(!args->fields) return "Incomplete cart configuration!";
    array r= id->misc->ivend->db->query(
      "SELECT sessions." + keys[id->misc->ivend->st]->products +
	",series,quantity,sessions.price "+ 
	extrafields+" FROM sessions,products "
      	"WHERE sessions.SESSIONID='"
	+id->misc->ivend->SESSIONID+"' AND sessions."+
	keys[id->misc->ivend->st]->products+"=products." +
	keys[id->misc->ivend->st]->products);
    if (sizeof(r)==0) {
      if(id->misc->ivend->error) 
//	error(YOUR_CART_IS_EMPTY, id);
      return YOUR_CART_IS_EMPTY +"\n<false>\n";
    }
    retval+="<tr><th bgcolor=maroon><font color=white>"+ CODE +"</th>\n";
	
    foreach(en, field){
	retval+="<th bgcolor=maroon>&nbsp; <font color=white>"+field+" &nbsp; </th>\n";
	}
    retval+="<th bgcolor=maroon><font color=white>&nbsp; "
	+ PRICE +" &nbsp;</th>\n"
    	"<th bgcolor=maroon><font color=white>&nbsp; "
	+ QUANTITY +" &nbsp;</th>\n"
	"<th bgcolor=maroon><font color=white>&nbsp; "
	+ TOTAL + " &nbsp;</th></tr>\n";
    for (int i=0; i< sizeof(r); i++){
      retval+="<TR><TD><INPUT TYPE=HIDDEN NAME=s"+i+" VALUE="+r[i]->series+">\n"
	  "<INPUT TYPE=HIDDEN NAME=p"+i+" VALUE="+r[i][
	keys[id->misc->ivend->st]->products]+">&nbsp; \n"
        +r[i][ keys[id->misc->ivend->st]->products]+" &nbsp;</TD>\n";

	foreach(en, field){
//		perror(field +"\n");
	    retval+="<td>"+(r[i][field] || " N/A ")+"</td>\n";
	    }

	  r[i]->price=convert((float)r[i]->price,id);

	retval+="<td align=right>" + MONETARY_UNIT +
	sprintf("%.2f",(float)r[i]->price)+"</td>\n"
	"<TD><INPUT TYPE=TEXT SIZE=3 NAME=q"+i+" VALUE="+
        r[i]->quantity+"></td><td align=right>" + MONETARY_UNIT 
	+sprintf("%.2f",(float)r[i]->quantity*(float)r[i]->price)+"</td></tr>\n";
      }
    retval+="</table>\n<input type=hidden name=s value="+sizeof(r)+">\n"
	"<input name=update type=submit value=\"" 
	+ UPDATE_CART + "\">"
	"<input name=update type=submit value=\" Check Out \">"
	"</form>\n<true>\n"+contents;
return retval;    
 
}

string tag_additem(string tag_name, mapping args,
                    object id, mapping defines) {
if(!args->item) return "<!-- you must specify an item " +
	keys[id->misc->ivend->st]->products +". -->\n";
string retval="<form action=" + id->not_query + ">";
retval+=QUANTITY +": <input type=text size=2 value=" + (args->quantity ||
"1") + " name=quantity> ";
retval+="<input type=submit value=\"" + ADD_TO_CART + "\">\n";
retval+="<input type=hidden name=ADDITEM value=\""+args->item+"\">\n";
retval+="</form>\n";
return retval;

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

  if(!args->type) return YOU_MUST_SUPPLY_A_CATEGORY_TYPE;

  query="SELECT * FROM " + lower_case(args->type);

  if(!args->show)
    query+=" WHERE status='A' ";

  else if(args->show && args->restriction)
    query+=" WHERE ";
  if(!args->show && args->restriction)
    query+=" AND ";

  if(args->restriction)
    query+=args->restriction;

  array r=id->misc->ivend->db->query(query);

  if(!r || sizeof(r)==0) return "<!-- No Records Found.-->\n";

  if(!id->misc->fr)
    retval+=do_output_tag( args, r||({}), contents, id );  

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
string query;

if(!id->misc->ivend->page) return "no page!";
string st=id->misc->ivend->st;
string extrafields="";
array ef=({});
array en=({});

 if(args->fields){
   ef=args->fields/",";
   if(args->names)
   en=args->names/",";
   else en=({});
   for(int i=0; i<sizeof(ef); i++) {
     if(catch(en[i]) || !en[i])  en+=({ef[i]});
     extrafields+=", " + ef[i] + " AS " + "'" + en[i] + "'"; 
   }
 }

array r;
if(args->type=="groups") {
  query="SELECT " + keys[id->misc->ivend->st]->groups + " AS pid " +
	extrafields+ " FROM groups";
  if(!args->show)
    query+=" WHERE status='A' ";

   r=id->misc->ivend->db->query(query);
  }
else {
  query="SELECT product_id AS pid "+ extrafields+
	" FROM product_groups,products where group_id='"+
	     id->misc->ivend->page+"'";

  if(!args->show)
    query+=" and status='A' ";
 
  query+=" AND products." +  keys[id->misc->ivend->st]->products +
	"=product_id";

  r=id->misc->ivend->db->query(query);
}

if(sizeof(r)==0) return NO_PRODUCTS_AVAILABLE;

mapping row;

array(array(string)) rows=allocate(sizeof(r));
int p=0;
foreach(r,row){
  array thisrow=allocate(sizeof(row)-1);
  string t;
  int n=0;
// perror(indices(row)*" - ");
  foreach(en, t){
//	perror(t);  

      if(n==0) {
        thisrow[n]=("<A " + (args->template?("TEMPLATE=\"" +
	  args->template + "\""):"") +
	  " HREF=\""+row->pid+".html\">"+row[t]+"</A>");
        }
      else
        thisrow[n]=row[t]; 
      n++;

    }
  rows[p]=thisrow;
  p++;
  }

retval+=html_table(en, rows);
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
	" " +  keys[id->misc->ivend->st]->products  +"='" 
	+id->misc->ivend->id+"'");
  if (sizeof(r)!=1) return "";
  else filename=config[id->misc->ivend->st]->root+"/images/"+
    id->misc->ivend->type+"s/"+r[0][args->field];
  }  
else if(args->src!="") 
filename=config[id->misc->ivend->st]->root+"/images/"+args->src;

array|int size=size_of_image(filename);


// file doesn't exist
if(size==-1) return "<!-- couldn't find the image: "+filename+"... -->";
// it's not a gif file
else if(size==0)	
	return ("<IMG SRC=\""+query("mountpoint")+
(  (sizeof(config)==1 && getglobalvar("move_onestore")=="Yes") 
	?"":st+"/")+"images/"
      +id->misc->ivend->type+"s/"+r[0][args->field]+"\">");
// it's a gif file
else return ("<IMG SRC=\""+query("mountpoint")+st+"/images/"+
(  (sizeof(config)==1 && getglobalvar("move_onestore")=="Yes") 
	?"":st+"/")+"images/"

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


mixed handle_cart(string st, object id){
#ifdef MODULE_DEBUG
// perror("iVend: handling cart for "+st+"\n");
#endif

string retval;
if(!(retval=Stdio.read_bytes(id->misc->ivend->config->root+"/cart.html")))
  error("Unable to find the file "+
    (id->misc->ivend->config->root)+"/cart.html",id);
 
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
// perror("iVend: finding page "+ page+" in "+id->misc->ivend->st+"\n");
#endif

string retval;

page=(page/".")[0];	// get to the core of the matter.
id->misc->ivend->id=page;
string template;
array(mapping(string:string)) r;
array f;
r=id->misc->ivend->db->query("SELECT * FROM groups WHERE " +
	keys[id->misc->ivend->st]->groups + 
	"='"+page+"'");
if (sizeof(r)==1){
  id->misc->ivend->type="group";
  if(id->variables->template) template=id->variables->template;
  else template="group_template.html";
  f=id->misc->ivend->db->list_fields("groups");
  }
else {
  r=id->misc->ivend->db->query("SELECT * FROM products WHERE " +
	keys[id->misc->ivend->st]->products +"='"+page+"'");
  id->misc->ivend->type="product";
  if(id->variables->template) template=id->variables->template;
  else template="product_template.html";
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

  if(id->variables->quantity && (int)id->variables->quantity==0) {
    id->misc->ivendstatus= ERROR_QUANTITY_ZERO;

    return 0;
    }
  
  float price=id->misc->ivend->db->query("SELECT price FROM products WHERE " 
	+ keys[id->misc->ivend->st]->products +  "='" + item + "'")[0]->price;

  price=convert((float)price,id);


int max=sizeof(id->misc->ivend->db->query("select id FROM sessions WHERE SESSIONID='"+
  id->misc->ivend->SESSIONID+"' AND id='"+item+"'"));
string query="INSERT INTO sessions VALUES('"+ id->misc->ivend->SESSIONID+

"','"+item+"',"+(id->variables->quantity 
|| 1)+","+(max+1)+",'Standard','"+(time(0)+
  (int)id->misc->ivend->config->session_timeout)+"'," + price +")";

if(catch(id->misc->ivend->db->query(query) ))
	id->misc["ivendstatus"]+=( ERROR_ADDING_ITEM+" " +item+ ".\n"); 
else 
  id->misc["ivendstatus"]+=((id->variables->quantity || "1")+" " + ITEM
	+ " " + item + " " + ADDED_SUCCESSFULLY +"\n"); 
return 0;
}

mixed handle_page(string page, object id){
#ifdef MODULE_DEBUG
// perror("iVend: handling page "+ page+ " in "+ id->misc->ivend->st +"\n");
#endif


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
  
  mixed fs;
  fs=stat_file(page,id);

    if(!fs) {
      id->misc->ivend["page"]=page-".html";
      return find_page(page,id);
      }
    else if(fs[1]<=0) {
//      perror("we've got a directory!\n"
//	"trying " + page + "/index.html\n");
page="/"+((page/"/") - ({""})) * "/";
      fs=stat_file(page+"/index.html",id);
//  perror(sprintf("%O",fs));
	
      if(fs && fs[1]>0) {
  //      perror("found it!\n");
        return http_redirect(page + "/index.html", id);
       }
      else return 0;
      }    
    retval=Stdio.read_file(id->misc->ivend->config->root + "/" + page);
	id->realfile=id->misc->ivend->config->root+"/"+page;
  }
  if (!retval) return 0;  // error(UNABLE_TO_FIND_PRODUCT +" " + page,id);
  return retval;

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


if(retval==-1) return 
handle_page("index.html",id);
else 
return retval;    
}


string create_index(object id){
string retval="";
retval=Stdio.read_bytes(query("datadir")+"index.html");
return retval;
}

mixed getsessionid(object id) {

  return id->misc->ivend->SESSIONID;

}

// Start of auth functions.

// we're login' in to the main config interface.
int get_auth(object id){

  array(string) auth=id->realauth/":";
  if(auth[0]!=query("config_user")) return 0;
  else if(crypt(auth[1], query("config_password")))
        return 1;
  else return 0;                   

}

int admin_auth(object id)

{
  array(string) auth=id->realauth/":";
  if(catch(id->misc->ivend->db=iVend.db(
    id->misc->ivend->config->dbhost,
    id->misc->ivend->config->db,
    auth[0],
    auth[1]
    )))
    return 0;
else return 1;
}



// Start of admin functions


int do_clean_sessions(object db){

string query="SELECT sessionid FROM sessions WHERE timeout < "+time(0);
array r=db->query(query);
foreach(r,mapping record){
  foreach(({"customer_info","payment_info","orderdata","lineitems"}),
    string table)
   db->query("DELETE FROM " + table + " WHERE orderid='"
	+ record->sessionid + "'");

}
string query="DELETE FROM sessions WHERE timeout < "+time(0);

db->query(query);

return sizeof(r);
}

int clean_sessions(object id){

int numsessions=do_clean_sessions(id->misc->ivend->db);
return numsessions;

}

void background_session_cleaner(){

object d;
mixed err;

foreach(indices(config), string st){
  mapping store=config[st];
  err=catch(d=db[st]->handle());
 if(err)
   perror("iVend: BackgroundSessionCleaner failed."
	+ describe_backtrace(err) + "\n");    
    
 else { 
    int numsessions=do_clean_sessions(d);
    if(numsessions)
      perror("iVend: BackgroundSessionCleaner cleaned " + numsessions +
         " sessions from database " + store->db + ".\n");
    }
perror("returning db in background_session_cleaner\n");
  db[st]->handle(d);
  }
call_out(background_session_cleaner, 900);
}


mixed order_handler(string filename, object id){

if(id->auth==0)
  return http_auth_required("iVend Store Orders",
	"Silly user, you need to login!"); 
else if(!admin_auth(id)) 
  return http_auth_required("iVend Store Orders",
	"Silly user, you need to login!");

string retval="";
retval+="<title>iVend Store Orders</title>"
  "<body bgcolor=white text=navy>"
  "<img src=\""+query("mountpoint")+"ivend-image/ivendlogosm.gif\"> &nbsp;"
  "<img src=\""+query("mountpoint")+"ivend-image/admin.gif\"> &nbsp;"
  "<gtext fg=maroon nfont=bureaothreeseven black>"
  +id->misc->ivend->config->name+
  " Orders</gtext><p>"
  "<font face=helvetica,arial size=+1>"
  "<a href=./>Storefront</a> &gt; <a href=./admin>Admin</a> &gt; <a href=./orders>Orders</a><p>\n";


 mixed d=id->misc->ivend->modules[
	id->misc->ivend->config->order_module]->show_orders(id, 
   id->misc->ivend->db);
 if(stringp(d))
 retval+=d;


return retval;

}

mixed shipping_handler(string filename, object id){

if(id->auth==0)
  return http_auth_required("iVend Store Shipping",
	"Silly user, you need to login!"); 
else if(!admin_auth(id)) 
  return http_auth_required("iVend Store Shipping",
	"Silly user, you need to login!");

string retval="";
retval+="<title>iVend Shipping Administration</title>"
  "<body bgcolor=white text=navy>"
  "<img src=\""+query("mountpoint")+"ivend-image/ivendlogosm.gif\"> &nbsp;"
  "<img src=\""+query("mountpoint")+"ivend-image/admin.gif\"> &nbsp;"
  "<gtext fg=maroon nfont=bureaothreeseven black>"
  +id->misc->ivend->config->name+
  " Shipping</gtext><p>"
  "<font face=helvetica,arial size=+1>"
  "<a href=index.html>Storefront</a> &gt; <a href=admin>Admin</a> &gt; <a "
  "href=shipping>Shipping</a><p>\n";


 mixed d=id->misc->ivend->modules[
	id->misc->ivend->config->shipping_module
	]->shipping_admin(id);
 if(stringp(d))
 retval+=d;


return retval;

}

mixed getmodify(string type, string pid, object id){

string retval="";
multiset gid=(<>);
array record=id->misc->ivend->db->query("SELECT * FROM " + type + "s WHERE "
+  keys[id->misc->ivend->st][type +"s"]  + "='" + pid +"'");
if (sizeof(record)!=1)
  return "Error Finding " + capitalize(type) + " " +
	keys[id->misc->ivend->st][type +"s"] + " " + pid + ".<p>";

if(type=="product") {
  array groups=id->misc->ivend->db->query("SELECT group_id from "
    "product_groups where product_id='"+ pid + "'");
  if(sizeof(groups)>0)
    foreach(groups, mapping g)
      gid[g->group_id]=1;
  record[0]->group_id=gid;
  }

  retval+="&gt <b>Modify " + capitalize(id->variables->type)
+"</b><br>\n";

if(id->variables->type=="product")
  retval+="<table>\n"+id->misc->ivend->db->gentable("products","./admin","groups",
        "product_groups", id, record[0])+"</table>\n";
  else if(id->variables->type=="group")

retval+="<table>\n"+id->misc->ivend->db->gentable("groups","./admin",0,0,id,
record[0])+"</table>\n";
 
return retval;

}

mixed admin_handler(string filename, object id){

if(id->auth==0)
  return http_auth_required("iVend Store Administration",
	"Silly user, you need to login!"); 
else if(!admin_auth(id)) 
  return http_auth_required("iVend Store Administration",
	"Silly user, you need to login!");

string retval="";
retval+="<title>iVend Store Administration</title>"
  "<body bgcolor=white text=navy>"
  "<img src=\""+query("mountpoint")+"ivend-image/ivendlogosm.gif\"> &nbsp;"
  "<img src=\""+query("mountpoint")+"ivend-image/admin.gif\"> &nbsp;"
  "<gtext fg=maroon nfont=bureaothreeseven black>"
  +id->misc->ivend->config->name+
  " Administration</gtext><p>"
  "<font face=helvetica,arial size=+1>"
  "<a href=index.html>Storefront</a> &gt; <a href=admin>Admin</a>\n";

switch(id->variables->mode){

  case "doadd":
  mixed j=id->misc->ivend->db->addentry(id,id->referrer);
  retval+="<br>";
  if(stringp(j))
    return retval+= "The following errors occurred:<p><li>" + (j*"<li>");


  string type=(id->variables->table-"s");
  return retval+type+" Added Sucessfully.";
  break;

  case "domodify":
  mixed j=id->misc->ivend->db->modifyentry(id,id->referrer);
  retval+="<br>";
  if(stringp(j))
    return retval+= "The following errors occurred:<p><li>" + (j*"<li>");


  string type=(id->variables->table-"s");
  return retval + capitalize(type) + " Modified Sucessfully.";
  break;

  case "add":
  retval+="&gt <b>Add New " + capitalize(id->variables->type) +"</b><br>\n";

  if(id->variables->type=="product")
    retval+="<table>\n"+id->misc->ivend->db->gentable("products","./admin","groups", 
	"product_groups", id)+"</table>\n";
  else if(id->variables->type=="group")
    retval+="<table>\n"+id->misc->ivend->db->gentable("groups","./admin",0,0,id)+"</table>\n";
  break;

  case "dodelete":
//  perror("doing delete...\n");
  if(id->variables->confirm){
    if(id->variables->id==0 || id->variables->id=="") 
      retval+="You must select an ID to act upon!<br>";
    else retval+=id->misc->ivend->db->dodelete(id->variables->type,
id->variables[ keys[id->misc->ivend->st][id->variables->type +"s"]],
id->misc->ivend->keys[id->variables->type +"s"]); }
  else {
    if(id->variables->match) {
    mixed n=id->misc->ivend->db->showmatches(id->variables->type,
      id->variables->id, id->misc->ivend->keys[id->variables->type+"s"]);
    if(n)
      retval+="<form action=./admin>\n"
        + n +
        "<input type=hidden name=mode value=dodelete>\n"
        "<input type=submit value=Delete>\n</form>";
    else retval+="No " + capitalize(id->variables->type +"s") + " found.";
    }
    else {
      mixed n=id->misc->ivend->db->showdepends(id->variables->type,
        id->variables[  keys[id->misc->ivend->st][id->variables->type+"s"]
], keys[id->misc->ivend->st][id->variables->type+"s"],
(id->variables->type=="group"?keys[id->misc->ivend->st]->products:0));
      if(n){ 
        retval+="<form action=./admin>\n"
          "<input type=hidden name=mode value=dodelete>\n"
          "<input type=hidden name=type value="+id->variables->type+">\n"
          "<input type=hidden name=id value="+id->variables[
		keys[id->misc->ivend->st][id->variables->type+"s"] ]+">\n"
          "Are you sure you want to delete the following?<p>";
          retval+=n+"<input type=submit name=confirm value=\"Really Delete\"></form><hr>";
        }
      else retval+="Couldn't find "+capitalize(id->variables->type) +" "
        +id->variables[ keys[id->misc->ivend->st][ 
	id->variables->type+"s"]]+".<p>";
      }

    }

    case "delete":
    retval+="<form action=./admin>\n"
      "<input type=hidden name=mode value=dodelete>\n"
      +capitalize(id->variables->type) + " "+
	keys[id->misc->ivend->st][id->variables->type +"s"] + " to Delete:\n"
      "<input type=text size=10 name=\"" +
	keys[id->misc->ivend->st][id->variables->type+"s"] + "\">\n"
      "<input type=hidden name=type value=" + id->variables->type + ">\n"
      "<br><font size=2>If using FindMatches, you may type any part of an "
	+ keys[id->misc->ivend->st][id->variables->type+"s"] +
      " or Name to search for.<br></font>"
      "<input type=submit name=match value=FindMatches> &nbsp; \n"
      "<input type=submit value=Delete>\n</form>";
  break;

  case "clearsessions":
  int r =clean_sessions(id);	
  retval+=r+ " Sessions Cleaned Successfully.<p><a href=\"./admin\">"
	"Return to Administration Menu.</a>\n";
  break;

  case "getmodify":

  retval+=getmodify(id->variables->type,
	id->variables[keys[ 
	id->misc->ivend->st][id->variables->type+"s"]], id);

  break;

  case "show":
  retval+="&gt <b>Show " + capitalize(id->variables->type)
	+"</b><br>\n";
    retval+="<form action=./admin>\n"
      "<input type=hidden name=mode value=show>\n"
      "<input type=hidden name=type value="+ id->variables->type + ">\n"
      "<table><tr><td><input type=submit value=Show></td><td>\n";
      retval+="<td><b>Show fields:</b> ";
    array f=id->misc->ivend->db->list_fields(id->variables->type+"s");
array k;
catch(k=id->misc->ivend->db->query("SHOW INDEX FROM " + 
	id->variables->type + "s"));

    string primary_key;

    foreach(k, mapping key){

      if(key->Key_name=="PRIMARY")
      primary_key=key->Column_name;
    }

    foreach(f, mapping field)
      if(field->name !=primary_key)
        retval+="<input type=checkbox name=\"show-" + field->name +
    	  "\" value=\"yes\"" + ((id->variables["show-" +
	  field->name]=="yes")?" CHECKED ":"") + ">"
	  "&nbsp;" + field->name +" &nbsp; \n"; 
        else
          retval+="<input type=hidden name=\"show-" + field->name +
            "\" value=\"yes\">\n";

    retval+="</td></tr></table>"
	"<input type=hidden name=primary_key value=\"" +
		primary_key + "\"></form>"; 

    string query="SELECT ";
    array fields=({});
    foreach(f, mapping v)
      if(id->variables["show-" + v->name])
        fields+=({v->name});     
      if(sizeof(fields) > 0) {
        foreach(fields, string field)
          query+=field + ", ";

      query=query[0..(sizeof(query)-3)] + " FROM " + id->variables->type
	  + "s";
      array r=id->misc->ivend->db->query(query);
      if(sizeof(r)>0) {
        retval+="<table>\n<tr><td></td>\n";
        foreach(fields, string f)
          retval+="<td><b><font face=helvetica,arial>" + f + "</b></td>\n";
        retval+="</tr>";
        foreach(r, mapping row){
          retval+="<tr>\n<td><font face=helvetica,arial size=0>"
	    "<a href=\"./admin?mode=getmodify&type=" +
	    id->variables->type + "&" +id->variables->primary_key + "=" +
		row[id->variables->primary_key] + "\">Modify</a> "
	    "&nbsp; <a href=\"./admin?mode=dodelete&type=" +
	    id->variables->type + "&" + id->variables->primary_key + "=" + 
		row[id->variables->primary_key] + "\">Delete</a></td>";
          foreach(fields, string fld)
            retval+="<td>" + row[fld] + "</td>\n";              
            }  
          retval+="</tr>\n";
       retval+="</table>";   
	}
     else retval+="Sorry, No Records were found.";
      }

  break;

  case "modify":
  retval+="&gt <b>Modify " + capitalize(id->variables->type)
	+"</b><br>\n";
    retval+="<form action=./admin>\n"
      "<input type=hidden name=mode value=getmodify>\n"
      + capitalize(id->variables->type) + " "+
keys[id->misc->ivend->st][id->variables->type+"s"] + " to Modify: \n"
      "<input type=text size=10 name=\"" +
	keys[id->misc->ivend->st][id->variables->type+"s"] + "\">\n"
      "<input type=hidden name=type value="+id->variables->type+">\n"
      "<input type=submit value=Modify>\n</form>";
  break;

  default:
  retval+= "<ul>\n"
    "<li><a href=\"orders\">Orders</a>\n"
   "</ul>\n"
    "<ul>\n"
    "<li>Groups\n"
    "<ul>"
    "<li><a href=\"admin?mode=show&type=group\">Show Groups</a>\n"
    "<li><a href=\"admin?mode=add&type=group\">Add New Group</a>\n"
    "<li><a href=\"admin?mode=modify&type=group\">Modify a Group</a>\n"
    "<li><a href=\"admin?mode=delete&type=group\">Delete a Group</a>\n"
    "<li><a href=\"admin?mode=dump&type=group\">Dump Groups</a>\n"
    "</ul>"
    "<li>Products\n"
    "<ul>"
    "<li><a href=\"admin?mode=show&type=product\">Show Products</a>\n"
    "<li><a href=\"admin?mode=add&type=product\">Add New Product</a>\n"
    "<li><a href=\"admin?mode=modify&type=product\">Modify a Product</a>\n"
    "<li><a href=\"admin?mode=delete&type=product\">Delete a Product</a>\n"
    "<li><a href=\"admin?mode=dump&type=product\">Dump Products</a>\n"
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

}



mixed find_file(string file_name, object id){

  id->misc["ivend"]=([]);
  id->misc->ivend->modules=modules;
  id->misc["ivendstatus"]="";
  string retval;
  id->misc->ivend->error=({});
  array(string) request=(file_name / "/") - ({""});
  if(catch(request[0])) request+=({""});
  switch(request[0]){
	
    case "config":
    request=request[1..];
    return configuration_interface(request, id);
    break;
		
    case "ivend-image":
    request=request[1..];
    return ivend_image(request, id);
    break;
		
    default:

    handle_sessionid(id);
    break;
	
    }


  if(sizeof(config)==1 && getglobalvar("move_onestore")=="Yes") {
    id->misc->ivend->st=indices(config)[0];
    id->misc->ivend->moveup=1;
}
  else if(sizeof(request)==0 || (sizeof(request)>=1 && !config[request[0]])) 

    { 
    if(getglobalvar("create_index")=="Yes")
      retval=create_index(id);
    else  retval="you must enter through a store!\n";
    }
  else {
    id->misc->ivend->st=request[0];
    request=request[1..];
    }

  if(retval) return return_data(retval, id);

/*
if(config[id->misc->ivend->st]->error)
    error(config[id->misc->ivend->st]->error, id);
    return return_data("An error has prevented iVend from servicing your request.", id);
*/	

  else if(!config[id->misc->ivend->st]) {

    return return_data("NO SUCH STORE!", id);
    }

  else if(catch(request[0])) {
    request+=({""});

    }
// load id->misc->ivend with the good stuff...
  id->misc->ivend->config=config[id->misc->ivend->st];	
  id->misc->ivend->keys=keys[id->misc->ivend->st];
mixed err;

  switch(request[0]) {
    case "images":
    break;
    case "admin":
    return return_data(admin_handler(request*"/", id),id);
    break;
    case "orders":
    return return_data(order_handler(request*"/", id),id);
    break;
    case "shipping":
    return return_data(shipping_handler(request*"/", id),id);
    break;
    default:
    err=catch(id->misc->ivend->db=db[id->misc->ivend->st]->handle());
    if(err || config[id->misc->ivend->st]->error) { 
       error(err || config[id->misc->ivend->st]->error, id);
       return return_data(retval, id);
       }

  }


  switch(request[0]) {
    case "":
	db[id->misc->ivend->st]->handle(id->misc->ivend->db);
      return http_redirect(simplify_path(id->not_query +
        "/index.html")+"?SESSIONID="+getsessionid(id), id);
    break;
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
    default:
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
catch {
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
    tags+=modules[id->misc->ivend->config->shipping_module
    ]->query_tag_callers();
  }
};
if(objectp(!id->misc->ivend->db))
    err=catch(id->misc->ivend->db=db[id->misc->ivend->st]->handle());

  id->misc->ivend->modules=modules;
contents=parse_rxml(contents,id);
 contents= "<html>"+parse_html(contents,
       tags,containers,id) +"</html>";
if(objectp(id->misc->ivend->db))
  db[id->misc->ivend->st]->handle(id->misc->ivend->db);
return contents;

}

mapping query_container_callers()
{
  return ([ "ivml": container_ivml ]); }

mapping query_tag_callers()
{
  return ([ "ivendlogo" : tag_ivendlogo, "additem" : tag_additem,
	"sessionid" : tag_sessionid ]); }


// Start of support functions


float convert(float value, object id){

if(functionp(id->misc->ivend->modules[
	id->misc->ivend->config->currency_module
	]->currency_convert))
	  value=id->misc->ivend->modules[id->misc->ivend->config->currency_module
	  ]->currency_convert(value,id);

else ;

return value;


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


mixed stat_file( mixed f, mixed id )  {

if(! id->misc->ivend->config) 
	return ({ 33204,0,time(),time(),time(),0,0 });
//  perror("iVend: statting "+id->misc->ivend->config->root+"/"+f+"\n");

  array fs;
  if(!id->pragma["no-cache"] &&
     (fs=cache_lookup("stat_cache", id->misc->ivend->config->root+"/" 
	+f)))
    return fs[0];  

object privs;



  fs = file_stat(
	id->misc->ivend->config->root + "/" + f);  
	/* No security currently in this function */

#ifndef THREADS
  privs = 0;
#endif

  cache_set("stat_cache", id->misc->ivend->config->root+"/" +f, ({fs}));
  return fs;    

}


void error(mixed error, object id){
  if(arrayp(error)) id->misc->ivend->error +=({	
    replace(describe_backtrace(error),"\n","<br>\n") });
  else if(stringp(error)) id->misc->ivend->error += ({ error });
  return;

}

mixed handle_error(object id){
string retval;

if(id->misc->ivend->st && id->misc->ivend->config)
  retval=Stdio.read_file(
    id->misc->ivend->config->root+"/error.html");

// perror("error: " + retval + "\n");

if(!retval) retval="<title>iVend Error</title>\n<h2>iVend Error</h2>\n"
    "<b>One or more errors have occurred. Please review the following "
    "information and, if necessary, make any changes on the previous page "
    "before continuing.<p>If you feel that this is a configuration error, "
    "please contact the administrator of this system for assistance."
    "<error>";

return replace(retval,"<error>","<ul><li>"+(id->misc->ivend->error * "\n<li>")
	       +"</ul>\n");

}


mixed get_image(string filename, object id){

//perror("** "+id->misc->ivend->config[id->misc->ivend->st]->root+filename+"\n\n");

string data=Stdio.read_bytes(
	id->misc->ivend->config->root+"/"+filename);
id->realfile=id->misc->ivend->config->root+"/"+filename;

return http_string_answer(data,
	id->conf->type_from_filename(id->realfile));

}

void handle_sessionid(object id) {


  if(!id->variables->SESSIONID) {

    id->misc->ivend->SESSIONID=
      "S" + (string)hash((string)time(1))+num;	
      num+=1;

      }

    else id->misc->ivend->SESSIONID=id->variables->SESSIONID;

  m_delete(id->variables,"SESSIONID");

}

mixed return_data(mixed retval, object id){

    if(sizeof(id->misc->ivend->error)>0)
     	 retval=handle_error(id);
db[id->misc->ivend->st]->handle(id->misc->ivend->db);

  if(mappingp(retval))
	return retval;

  if(stringp(retval)){ 
    if(id->conf->type_from_filename(id->realfile || "index.html")
=="text/html")
    retval=parse_rxml(retval, id);


    return http_string_answer(retval,
      id->conf->type_from_filename(id->realfile|| "index.html"));

}

  else return retval;

}


// Start of config functions.



mixed getglobalvar(string var){

  if(catch(global[var]))
    return 0;
  else return global[var];

}

int read_conf(){          // Read the config data.

string current_config="";
string attribute;
string value;

c=iVend.config();
g=iVend.config();
if(!c->load_config_defs(Stdio.read_file(query("datadir")+"ivend.cfd")))
   perror("iVend: ERROR LOADING CONFIGURATION DEFINITION!\n");
// else 
//   perror("iVend: LOADED CONFIGURATION DEFINITION!\n");
if(!g->load_config_defs(Stdio.read_file(query("datadir")+"global.cfd")))
   perror("iVend: ERROR LOADING GLOBAL VARIABLES DEFINITION!\n");
// else 
//   perror("iVend: LOADED GLOBAL VARIABLES DEFINITION!\n");

array|int configfiles=get_dir(query("configdir"));

if(intp(configfiles)) return 0;	// no config directory.

configfiles-=({"CVS",".",".."});

for(int i=0; i<sizeof(configfiles); i++){

  if(search(configfiles[i], "~")>0) {
#ifdef MODULE_DEBUG
//    perror("iVend: Skipping Config File " + configfiles[i] + ".\n");
#endif
    continue;
    }

  catch(array(string) config_file= Stdio.read_file(query("configdir")+ 
	configfiles[i])/"\n");

#ifdef MODULE_DEBUG
 // perror("iVend: parsing configuration "+configfiles[i]+"\n");
#endif

  current_config=configfiles[i];

  for(int j=0; j<sizeof(config_file);j++)
	if(config_file[j][0..0]=="$"){
	  array(mixed) current_line=config_file[j][1..]/"=";
	  attribute=current_line[0];
	  value=current_line[1];
	  if(!config[current_config])
	    config[current_config]= ([attribute:value]);
	  else config[current_config][attribute]=value;
          }
  }


global=config["global"];
m_delete(config,"global");
return 0;
}


mixed load_ivmodule(string c, string name){

mixed err;
mixed m;

    err=catch(m=(object)clone(compile_file(query("root")+"/src/modules/"+
    name)));
if(err) {

  return (err);
  }
modules+=([ name : m  ]);
if(objectp(modules[name]) && functionp(modules[name]->start))
  modules[name]->start(config[c]);
return 0;

}


void get_dbkeys(mapping c){

perror("iVend: Getting DB Keys for " + c->config + "\n");

object s=db[c->config]->handle();

keys[c->config]=([]); // make the entry.

foreach(({"products", "groups"}), string t) {
array r;
r=s->query("SHOW INDEX FROM " + t );  // MySQL dependent?
  if(sizeof(r)==0)
    keys[c->config][t]="id";
  else {
    string primary_key;
    foreach(r, mapping key){
        if(key->Key_name=="PRIMARY")
        primary_key=key->Column_name;
      }
    keys[c->config][t]=primary_key; 
    }  

  }

return;

}

void start_db(mapping c){

perror("iVend: Starting dbhandler for " + c->config + "\n");

db[c->config]=iVend.db_handler(
		    c->dbhost,
		    c->db,
		    4,
		    c->dblogin,
		    c->dbpassword
		    );

return;

}


void load_modules(string c){

// perror("iVend: running load_modules() for " + c + "\n");

mixed err;
if(!c) return;
if(!config[c]) return;
  foreach(indices(config[c]), string n)
    if(Regexp("._module")->match(n)) {
//      perror("iVend: loading module " + config[c][n] + "\n");
      err=load_ivmodule(c, config[c][n]);
      if(err) {
        perror("iVend: The following error occured while loading the module "
	  + config[c][n] + " in configuration " + config[c]->name + ".\n\n"
	  + describe_backtrace(err));
        config[c]->error=err;
	}
      }
  return;
}

mapping write_configuration(object id){
string config_file="";

array(string) configs= indices(config);
configs+=({"global"});
array(string) this_config;
for(int i=0; i<sizeof(configs); i++){	
  if(configs[i]=="global") {

    if(!global) this_config=({});
    else this_config= indices(global);
    }
  else
    this_config= indices(config[configs[i]]);
	
  for(int j=0; j<sizeof(this_config); j++){
	
    if(configs[i]=="global")
      config_file+="$" +this_config[j]+ "=" +
       global[this_config[j]] + "\n";
    else {
      config_file+="$" +this_config[j]+ "=" +
        config[configs[i]][this_config[j]] + "\n";
      }
    }
  config_file+="\n";
  mv(query("configdir")+configs[i],query("configdir")+configs[i]+"~");
  Stdio.write_file(query("configdir")+configs[i], config_file);
  config_file="";
  }
	


save_status=1;	// We've saved.
// perror("iVend: reloading all modules...\n");
start();	// Reload all of the modules and crap.
return http_redirect(id->referer, id);

}

mapping configuration_interface(array(string) request, object id){

if(id->auth==0)
  return http_auth_required("iVend Configuration","Silly user, you need to login!"); 
else if(!get_auth(id)) 
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
"<TD WIDTH=\"32\" HEIGHT=\"8\"><SPACER TYPE=\"BLOCK\" WIDTH=\"32\" HEIGHT=\"8\"></TD>\n"
"<TD WIDTH=\"186\" HEIGHT=\"8\"><SPACER TYPE=\"BLOCK\" WIDTH=\"186\" HEIGHT=\"8\"></TD>\n"
"<TD WIDTH=\"6\" HEIGHT=\"8\"><SPACER TYPE=\"BLOCK\" WIDTH=\"6\" HEIGHT=\"8\"></TD>\n"
"<TD WIDTH=\"186\" HEIGHT=\"8\"><SPACER TYPE=\"BLOCK\" WIDTH=\"186\" HEIGHT=\"8\"></TD>\n"
"<TD WIDTH=\"6\" HEIGHT=\"8\"><SPACER TYPE=\"BLOCK\" WIDTH=\"6\" HEIGHT=\"8\"></TD>\n"
"<TD WIDTH=\"186\" HEIGHT=\"8\"><SPACER TYPE=\"BLOCK\" WIDTH=\"186\" HEIGHT=\"8\"></TD>\n"
"<TD WIDTH=\"182\" HEIGHT=\"8\"><SPACER TYPE=\"BLOCK\" WIDTH=\"182\" HEIGHT=\"8\"></TD>\n"
"</TR>\n";

// Do filefolder tabs

	switch(request[0]){
	
		case "status": {
		retval+=
"<TR HEIGHT=\"28\">\n"
"<TD WIDTH=\"32\" HEIGHT=\"28\"><SPACER TYPE=\"BLOCK\" WIDTH=\"32\" HEIGHT=\"28\"></TD>\n"
"<TD WIDTH=\"186\" HEIGHT=\"28\" COLSPAN=\"1\" ROWSPAN=\"1\" VALIGN=\"top\" ALIGN=\"left\" XPOS=\"32\"><A "
"HREF=\""+query("mountpoint")+"config/configs\"><IMG SRC=\""+query("mountpoint")+"ivend-image/configurationsunselect.gif\" "
"WIDTH=\"186\" HEIGHT=\"28\" BORDER=\"0\" ALT=\"/  Configurations  \\\"></A></TD>\n"
"<TD WIDTH=\"6\" HEIGHT=\"28\"><SPACER TYPE=\"BLOCK\" WIDTH=\"6\" HEIGHT=\"28\"></TD>\n"
"<TD WIDTH=\"186\" HEIGHT=\"28\" COLSPAN=\"1\" ROWSPAN=\"1\" VALIGN=\"top\" ALIGN=\"left\" XPOS=\"224\">"
"<A HREF=\""+query("mountpoint")+"config/global\"><IMG SRC=\""+query("mountpoint")+"ivend-image/globalunselect.gif\" WIDTH=\"186\" HEIGHT=\"28\" BORDER=\"0\" ALT=\"/ Global Variables \\\"></A></TD>\n"
"<TD WIDTH=\"6\" HEIGHT=\"28\"><SPACER TYPE=\"BLOCK\" WIDTH=\"6\" HEIGHT=\"28\"></TD>\n"
"<TD WIDTH=\"186\" HEIGHT=\"28\" COLSPAN=\"1\" ROWSPAN=\"1\" VALIGN=\"top\" ALIGN=\"left\" XPOS=\"416\"><A HREF=\""+query("mountpoint")+"config/status\"><IMG SRC=\""+query("mountpoint")+
"ivend-image/statusselect.gif\" WIDTH=\"186\" HEIGHT=\"28\" BORDER=\"0\" ALT=\"/        Status        \\\"></A></TD>\n"
"<TD WIDTH=\"182\" HEIGHT=\"28\"><SPACER TYPE=\"BLOCK\" WIDTH=\"182\" HEIGHT=\"28\"></TD>\n"
"</TR>\n"
"<tr><td>THIS PAGE LEFT INTENTIONALLY BLANK.\n</td></tr>";
		
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
"<TABLE>" +

	(g->genform(
	global || 0,
	query("lang"), 
	query("root")+"src/modules")
	  ||"Error Loading Configuration Definitions!")+



"<TR><TD><INPUT TYPE=SUBMIT VALUE=\" Update Variables \"></TD><TD>&nbsp;</TD></TR>\n" 
"</TABLE></FORM>";
	if(save_status!=1)
  	retval+="<A HREF=\""+query("mountpoint")+"config/save\">Save Changes</A>";
retval+="\n</TD></TR>";

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

		
  if(request[0]=="reload"){
	start();
	return http_redirect(query("mountpoint")+"config/configs",id);

  }

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
	query("root")+"src/modules")
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
  "<A HREF=\""+query("mountpoint")+"config/new\">New Configuration</A> &nbsp; "
  "<A HREF=\""+query("mountpoint")+"config/reload\">Reload Configurations</A> &nbsp; ";
  if(save_status!=1)
   	  retval+="<A HREF=\""+query("mountpoint")+"config/save\">Save Changes</A>";

			}
		
		
		
				
			
	else {		// OK, we know what we have in mind...

	if(id->variables->config_delete=="1") {

	config=m_delete(config,request[1]);
	save_status=0;
  mv(query("configdir")+ request[1], query("configdir") + request[1] + "~");

	return http_redirect(query("mountpoint")+"config/configs?"+time(),id);				

				}			

	else if(!catch(request[2]) && request[2]=="config_modify") {
		array(string) variables= (indices(id->variables)- ({"config_modify"}));
                  for(int i=0; i<sizeof(variables); i++){
 	if(variables[i]=="config_password" &&
id->variables[variables[i]]!=config[id->variables->config][variables[i]])
{

  id->variables[variables[i]]=crypt(id->variables[variables[i]]);
}

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
			  query("root")+"src/modules")
			||"Error loading configuration definitions")+
			"</TABLE><p><input type=submit value=\"Modify Configuration\"><p>";
			if(save_status!=1)
				retval+="<A HREF=\""+query("mountpoint")+"config/save\">Save Changes</A> &nbsp; ";
			retval+=
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



