/*
 * ivend.pike: Electronic Commerce for Roxen.
 *
 * Bill Welliver <hww3@riverweb.com>
 *
 */

string cvs_version = "$Id: ivend.pike,v 1.292 2004-10-18 10:43:58 hww3 Exp $";

#include "include/ivend.h"
#include "include/messages.h"
#include <module.h>
#include <stdio.h>

#undef file_stat

inherit "caudiumlib";
inherit "module";

int loaded;
mapping paths=([]);// path registry
mapping admin_handlers=([]);
mapping library=([]);
mapping actions=([]);// action storage
object db=0;// db cache
mapping modules=([]); // module cache
mapping config=([]);
int numrequests=0;
mapping admin_user_cache=([]);

int num;
int db_info_loaded=0;
int started=0;

#define PAGELINES 66
#define PAGECOLUMNS 100
#define ITEMSPERPAGE 10
#define ITEMSTARTLINE 29
array page=({});

string At(string line, int column, string text, int|void maxlen, string|void align)
{
  if(!text||text=="") return "";
  if(maxlen && sizeof(text)>maxlen)  // we need to trim the text to length
  {
    text=text[0..(maxlen-1)];
  }
  else if(maxlen && sizeof(text)<maxlen) // we need to pad the text
  {
    if(align&&align=="right")
      text= (" "*(maxlen-sizeof(text)) + text);
    else if(align&&align=="center")
      text= (" "*((maxlen-sizeof(text))/2) + text + 
	(" "*((maxlen-sizeof(text))/2)));
    else
      text=text + (" "*(maxlen-sizeof(text)));
  }
  int endcolumn=column + sizeof(text);
  string lineb="";
  string linea=line;
  if(column>1)
    lineb+=linea[0..column-2];
  lineb+=text;
  lineb+=linea[endcolumn..];
  line=lineb;
  return line;
}

void ivend_send_mail(array recipients, string message)
{
  mixed e;

  string host, sender;
  int port;
  
  sender = config["Admin Interface"]->email || "ivend@localhost";
  host = config["Admin Interface"]->smtp_server || "localhost";
  port = (int)config["Admin Interface"]->smtp_port || 25;

  werror("Protocols.SMTP.Client(%s, %d)->send_message(%O, %O, (string)message)\n", host, 
port, sender, recipients);
  Protocols.SMTP.Client(host, port)->send_message(sender, recipients, (string)message);

}

void ivend_report_error(string error, string|void orderid, string subsys, object id){
    perror(id->remoteaddr + ": " + id->misc->session_id +
           "\n" + " " + error);


    DB->query("INSERT INTO activity_log VALUES('" + 
	DB->quote(subsys) + "','" + DB->quote((string)orderid) + "'," + 
	"1, NOW(),'" +
	DB->quote(error) + "')");  

    return;

}

void ivend_report_critical_error(string error, string|void orderid, string
subsys, object id){
    perror("critical_error: " + id->remoteaddr + ": " +
		id->misc->session_id +           "\n" + " " + error);

    return;

}

void ivend_report_status(string error, string|void orderid, string subsys, object id){

    DB->query("INSERT INTO activity_log VALUES('" + 
	DB->quote(subsys) + "','" + DB->quote((string)orderid) + "'," + 
	"5, NOW(),'" +
	DB->quote(error) + "')");  

    return;

}

void ivend_report_warning(string error, string|void orderid, string subsys, object id){

    DB->query("INSERT INTO activity_log VALUES('" + 
	DB->quote(subsys) + "','" + DB->quote((string)orderid) + "'," + 
	"2, NOW(),'" +
	DB->quote(error) + "')");  

    return;

}

/*

  calculate tax

*/

float get_tax(object id, string orderid){
array r;                // result from query
string query;           // the query
float totaltax;         // totaltax
string locality;        // fieldname of locality
float taxrate=0.00;
mapping lookup=([]);

// do we have tax exemption support?
if(DB->local_settings->tax_exemption_support==TRUE){
//perror("we support tax exemption.\n");
  query="SELECT tax_exempt FROM customer_info WHERE orderid='"
	+ orderid + "' AND type=0 AND (tax_exempt<>0)";
  r=DB->query(query);
  if(sizeof(r)>0) return 0.00;
  } 

query="SELECT field_name FROM taxrates GROUP BY field_name"; 
r=DB->query(query);

if(sizeof(r)==0)
  return 0.00;
//perror("there are rates defined.\n");
array fields=({});
mapping tables=([]);

foreach(r, mapping row)  fields += ({row->field_name});
foreach(fields, string f)
  if(!tables[(f/".")[0]]) {
    tables += ([(f/".")[0]:({})]);
    tables[(f/".")[0]] += ({f});
    }
  else tables[(f/".")[0]] +=({f});

foreach(indices(tables), string tname){
                                         
query="SELECT " + (tables[tname]*", ") + " FROM " + tname +
  " WHERE " + tname + ".orderid='" + orderid + "'";


 r=DB->query(query);
string fname;
 if(sizeof(r)!=0)
  foreach(indices(r[0]), fname)
    lookup+=([tname + "." + fname: r[0][fname]]);
 }

if(sizeof(lookup)==0) {
  ivend_report_error("iVend: Unable to find order info for tax calculation!\n",
	NULL, "TAXCALC", id);
  return -1.00;
  }


else {          // calculate the tax rate as sum of all matches.
  //perror("we have matches.\n"); 
  foreach(indices(lookup), string fname) {
    query="SELECT * FROM taxrates WHERE field_name='" + fname + "' AND "
      "value='" + lookup[fname] + "'";
  //perror("looking up rates for " + fname + " " + lookup[fname] + "\n");
    r=DB->query(query);

    if(sizeof(r)!=0) {
	taxrate+=(float)(r[0]->taxrate);
	}
    }
  if(((float)taxrate)>0.00) {
     r=DB->query("SELECT SUM(value)*" + taxrate + " as totaltax "
        " FROM lineitems WHERE orderid='" + orderid + "' AND "
        "taxable='Y'");

        totaltax=(float)sprintf("%.2f", (float)r[0]->totaltax);
	return (float)(sprintf("%.2f",totaltax));
    }

  else return (0.00);
  }

// id->misc->ivend->lineitems+=(["salestax":0.00]);
return (-1.00);

} 

string is_lineitem_taxable(object id, string item, string orderid){
  if(item=="taxable") return "Y";
  if(item=="shipping" &&
CONFIG_ROOT["Checkout"]->shipping_taxable=="Yes") return
	"Y";
  else {
 return "N";
  } 
}


float get_subtotal(object id, string orderid){

float subtotal;

if(id->misc->ivend->lineitems)
 foreach(indices(id->misc->ivend->lineitems), string item) {
   if(item=="shipping");
   else {
     DB->query("DELETE FROM lineitems WHERE orderid='"
				+orderid+"' AND lineitem='"
				+item +"'");
     DB->query("REPLACE INTO lineitems VALUES('"+ 
			   orderid + 
			   "','" + item + "',"+
id->misc->ivend->lineitems[item] + ",NULL, '" + 
				is_lineitem_taxable(id, item,
orderid) +
"')");
   }
 }

array r=DB->query("SELECT SUM(value) as st FROM lineitems "
	"WHERE orderid='" + orderid + "' and lineitem like '%taxable'");

if(r && sizeof(r)==1) subtotal=(float)(r[0]->st);
else throw(({"Unable to find order lineitems.", backtrace()}));

// subtotal=(float)id->misc->ivend->lineitems->taxable +
//        (float)id->misc->ivend->lineitems->nontaxable;

return subtotal;

}  

float get_shipping(object id, string orderid){

float subtotal;

array r=DB->query("SELECT SUM(value) as st FROM lineitems "
	"WHERE orderid='" + orderid + "' and lineitem like 'shipping'");

if(r && sizeof(r)==1) subtotal=(float)(r[0]->st);
else throw(({"Unable to find order lineitems.", backtrace()}));

// subtotal=(float)id->misc->ivend->lineitems->taxable +
//        (float)id->misc->ivend->lineitems->nontaxable;

return subtotal;

}  


float get_grandtotal(object id, string orderid){

float grandtotal=0.00;


array r=DB->query("SELECT SUM(value) as gt FROM lineitems "
	"WHERE orderid='" + orderid + "'");

if(r && sizeof(r)==1) grandtotal=(float)(r[0]->gt);
else throw(({"Unable to find order lineitems.", backtrace()}));


float salestax=get_tax(id, orderid);


if(((float)salestax)) {
  grandtotal+= (float)salestax;
  }

  return (float)grandtotal;


}

array register_module(){

    string s="";

    return( {
              MODULE_LOCATION | MODULE_PARSER,
              "iVend 1.2",
              s+"iVend enables online shopping within Caudium.",
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

    defvar("storeroot", getmwd() ,
           "Store Root Location",
           TYPE_DIR,
           "This is the root directory of the store."
          );

    defvar("db", "",
           "Database URL",
           TYPE_STRING,
           "The SQL URL of the database the store will use to keep data."
          );

    defvar("storename", "iVend Test Store",
           "Store Name",
           TYPE_STRING,
           "A short descriptive name for this store."
          );

    defvar("admin_enabled", 1,
           "Enable Administration Interface",
           TYPE_FLAG,
           "Toggles availability of the Store Administration Interface"
          );

    defvar("wordfile", "/usr/dict/words",
           "Word File",
           TYPE_FILE,
           "This is a file containing words that will be used to generate "
           "config passwords. On Solaris and Linux, this is usually "
           "/usr/dict/words, and on FreeBSD /usr/share/dict/words.");

}

mixed handle_path(string p, object id) {

    string np=((p/"/")-({""}))[0];
    mixed rv;
    rv=paths[np](p, id);
    return rv;
}

int have_path_handler(string p){

    if(!p || p=="")
        return 0;

    p=((p/"/")-({""}))[0];
    if(paths[p] && functionp(paths[p])) {
        return 1;
    }
    else return 0;

}

void register_path_handler(string path, function f){

    if(functionp(f))
        paths[path]=f;
    else perror("no function provided!\n");
    return;
}

array get_fatal_error(object id)
{
  return id->misc->ivend->fatal_event;
}

array get_warning_error(object id)
{
  return id->misc->ivend->warning_event;
}

mixed throw_fatal_error(string error, object id) {  

  if(!id->misc->ivend->had_fatal_event)
    id->misc->ivend->had_fatal_event=1;
  else id->misc->ivend->had_fatal_event ++;

  if(!id->misc->ivend->fatal_event) 
    id->misc->ivend->fatal_event = ({});

  id->misc->ivend->fatal_event = ({ error });
}

mixed throw_warning(string error, object id) {  

  if(!id->misc->ivend->had_warning_event)
    id->misc->ivend->had_warning_event=1;
  else id->misc->ivend->had_warning_event ++;

  if(!id->misc->ivend->warning_event) 
    id->misc->ivend->warning_event = ({});

  id->misc->ivend->warning_event = ({ error });

}

int had_fatal_error(object id){

  if(id->misc->ivend && id->misc->ivend->had_fatal_event)
	return 1;
  else return 0;

}

int had_warning(object id){

  if(id->misc->ivend->had_warning_event) return 1;
  else return 0;

}

void trigger_event(string event, object|void id, mapping|void args){

       perror("triggering event " + event + "\n");

    if(id){
        if(library->event[event])
            foreach(library->event[event], mixed f)
	     if(!had_fatal_error(id))
		if(functionp(f))
		  f(event, id, args);
    }

}

void register_event(mapping config, mapping events){
    if(!library->event)
        library->event=([]);

    foreach(indices(events), string ename){
        perror("Registering event " + ename + "\n");
        if(!library->event[ename])
            library->event[ename]=({});
        library->event[ename]+=({events[ename]});
    }
    return;
}

string|void container_procedure(string name, mapping args,
                                string contents, object id) {
    string tname;
    string type;
    string header;
    string footer;

    if(!(args->tag ||  args->container || args->event))
        return "No procedure name provided!";
    else {
        if(args->tag) {
            type="tag";
            tname=lower_case(args->tag-" ");
            header="#define MODULES id->misc->ivend->modules\n"
                   "#define STORE id->misc->ivend->st\n"
                   "#define CONFIG id->misc->ivend->config->general\n"
                   "#define DB id->misc->ivend->db\n"
		   "#define T_O id->misc->ivend->this_object\n"
                   "inherit \"roxenlib\";\n"
                   "void|mixed proc(string tag_name, mapping "
                   "args, object id, mapping defines){\n";
            footer="\n}";
        }
        else if(args->event) {
            type="event";
            tname=lower_case(args->event-" ");
            header="#define MODULES id->misc->ivend->modules\n"
                   "#define STORE id->misc->ivend->st\n"
                   "#define CONFIG id->misc->ivend->config->general\n"
                   "#define DB id->misc->ivend->db\n"
                   "#define T_O id->misc->ivend->this_object\n"
		   "inherit \"roxenlib\";\n"
                   "mixed|void proc(string event_name, "
                   "object|void id, mapping|void args){\n";
            footer="\n}";
        }
        else {
            type="container";
            tname=lower_case(args->container-" ");
            header="#define MODULES id->misc->ivend->modules\n"
                   "#define STORE id->misc->ivend->st\n"
                   "#define CONFIG id->misc->ivend->config->general\n"
                   "#define DB id->misc->ivend->db\n"
                   "#define DB->keys id->misc->ivend->keys\n"
                   "#define T_O id->misc->ivend->this_object\n"
		   "inherit \"roxenlib\";\n"
                   "mixed|void proc(string container_name, mapping args,"
                   " string contents, object id){\n";
            footer="\n}";
        }
    }
    perror("Defining Procedure (" +type+"):  " + tname + "\n");
    contents=header+contents+footer;
    mixed err;
master()->set_inhibit_compile_errors(0);
    err=catch(object p=((program)compile_string(contents))());
    if(err)perror(describe_backtrace(err));
    if(type=="event") {
        if(err)
register_event(id->config, ([tname : err ]));
        else
register_event(id->config, ([tname : p->proc ]));
    }
    else {
        if(err)
            library[type][tname]=err;
        else library[type][tname]=p->proc;
    }

    return;

}

void load_library(){
    mapping id=([]);
    array dir;
    dir=get_dir(QUERY(storeroot) + "/library/");
    if(!dir) return;
    foreach(dir, string filename) {
        string contents;
        catch(contents=Stdio.read_file(QUERY(storeroot) + "/library/" + filename));
        if(contents)
            contents=Caudium.parse_html(contents, ([]),
                    (["procedure" : container_procedure ]) ,id);
    }
    return;
}

void get_entities(){
    if(!library)
        library=([]);
    library->tag=([]);
    library->container=([]);
    library->event=([]);

}

mixed register_admin_handler(mapping f){

    if(functionp(f->handler))
        admin_handlers[f->mode]=f;
    else perror("no function provided!\n");
    return 0;
}

void start_store(){
    if(!paths) paths=([]);
    if(!admin_handlers) admin_handlers=([]);
    register_path_handler("images", get_image);
    register_path_handler("admin", admin_handler);
    register_path_handler("cart", handle_cart);

    if(QUERY(db) && strlen(QUERY(db)))
      start_db();
    else return;
    get_entities();
    catch(load_modules());

    numrequests=0;

    load_library();

    register_event(config->general, (["postadditem": 
       event_postadditem]));

    started=1;
}


void stop_store(){
    if(modules)
        foreach(indices(modules), string m) {
        if(modules[m]->stop && functionp(modules[m]->stop))
            modules[m]->stop();
        if(modules[m])
            destruct(modules[m]);
    }
    if(db)
      db=0;
    started=0;
}

void stop(){

    stop_store();

    paths=([]);// path registry
    admin_handlers=([]);
    library=([]);
    actions=([]);// action storage
    db=0;
    modules=([]); // module cache
    config=([]);
    numrequests=0;

}

int write_config_section(string section, mapping attributes){
    mixed rv;
    object privs=Privs("iVend: Writing Config File");
    rv=.IniFile.write_section(query("storeroot") + "/config/config.ini" , section,
                            attributes);
#if efun(chmod)
    chmod(query("storeroot") + "/config/config.ini", 0640);
#endif
    privs=0;
    return rv;
}

void start(int cnt, object conf){
    report_error("Starting iVend 1.2\n");
    num=0;
    module_dependencies(conf, ({"obox", "tablify", "123session"}) );
    add_include_path(getmwd() + "src/include");
    add_module_path(getmwd()+"src");
    loaded=1;

    read_conf();   // Read the config data.

    start_store();

    return 0;

}


string|void check_variable(string variable, mixed set_to){

    return 0;

}

string status(){
   if(!started)
     return ("Store not started yet. Make sure all settings are configured.");
   else
     return ("Everything's A-OK!\n");

}

string query_name()

{
    return sprintf("iVend 1.2  mounted on <i>%s</i>", query("mountpoint"));
}



void|string container_ia(string name, mapping args,
                         string contents, object id) {
    if (catch(id->misc->session_id)) return;

    if (args["_parsed"]) return;

    mapping arguments=([]);

    arguments["_parsed"]="1";
    if(args->parse) args->href=parse_rxml(args->href, id, 0);
    if (args->external)
        arguments["href"]=args->href;
    else if (args->referer)
        arguments["href"]= (id->variables->referer || ((id->referer*"")-
                            "ADDITEM=1") || "");
    else if (args->add)
	arguments["href"]=( args->href ||("./"+id->misc->ivend->page+".html")) 
           		+"?ADDITEM=1&"
                          +id->misc->ivend->item+"=ADDITEM";
    else if(args->cart)
        arguments["href"]=query("mountpoint")
                          +"cart?referer=" +
                          (((id->referer*"") - "ADDITEM=1") ||"");
    else if(args->checkout)
      arguments["href"]=((id->misc->ivend->config["Checkout"]->checkouturl) || 
         (query("mountpoint") +"checkout/" )) ;
    else if(args->href){
            arguments["href"]=args->href;
    }

    if(arguments->href && args->template) arguments->href+="&template=" +
                args->template;

    m_delete(args, "href");
    m_delete(args, "checkout");
    m_delete(args, "cart");
    m_delete(args, "add");
    m_delete(args, "template");

    arguments+=args;

    return Caudium.make_container("A", arguments, contents);

}

mixed do_complex_items_add(object id, array items){
  perror("doing complex item add...\n");
  foreach(items, mapping i){
    array r;
    catch(r=DB->query("SELECT * FROM complex_pricing WHERE product_id='"
      + i->item + "'"));
    if(!r || sizeof(r)<1)
       perror("No Pricing Configuration for " + i->item + ".\n");
    foreach(r, mapping row) {
      trigger_event("cp." + row->type,id, (["item": i->item, 
                                            "quantity": i->quantity,
                                            "options": i->options]));
    }
        
    }
    return 0;
}

mapping get_options(object id, string item, string|void optstr)
  {
	array opt=({});
	array options=({});
	float surcharge;
if(optstr)
{
 array q=optstr/"\n";
 foreach(q, string qt){
   array v=qt/":";
   if(sizeof(v)==2)
   id->variables[v[0]]=v[1];
 }
}
        array types;
	catch(types=DB->query("SELECT option_type FROM item_options "
		"WHERE product_id='" + item + "' GROUP BY option_type"));
	foreach(types, mapping c){
	 if(id->variables[c->option_type])
          options+=({([ "option_code": id->variables[c->option_type],
		"option_type": c->option_type])});
	}
	 foreach(options, mapping o) {
	array optr;
	catch(optr=DB->query("SELECT * FROM item_options "
		"WHERE product_id='" + item + 
		"' AND option_code='" + o->option_code  + "' "
		"AND option_type='" + o->option_type + "'"));
	if(!optr || sizeof(optr)<1) {
	  error("Invalid Option " + o->option_type + " for item " +
		item + ".", id);
	}
	else {
	  surcharge+=(float)(optr[0]->surcharge);
	  opt+=({ optr[0]->option_type + ":" + 
             optr[0]->option_code });			
	}
    }
	return (["options": opt*"\n", "surcharge": surcharge]);
}


string is_item_taxable(object id, string item){

if(!item) return "Y";

array r=DB->query("SELECT taxable FROM products where " +
DB->keys->products +
"='" + item + "'");

if(r && sizeof(r)==1)
  return r[0]->taxable;
else
  return "Y";

}

int do_low_additem(object id, mixed item, mixed quantity, mixed
                   price, mapping|void args){

  if(HAVE_ERRORS) { 
    id->misc["ivendstatus"]+=( ERROR_ADDING_ITEM+" " +item+ ".\n");
    return 0;
  }

  if(!args) args=([]);

  if(!id->misc->session_variables->cart) 
    id->misc->session_variables->cart=({});


mapping ent =    ([
       "item" : item,
       "quantity" : quantity,
       "options" : (args->options||""),
       "price" : price,
       "autoadd" : (args->autoadd||0),
       "lock" : (args->lock||0),
       "taxable" : is_item_taxable(id, item)
    ]) ;
                 
trigger_event("preadditem", id, ent);

if(!had_fatal_error(id))
{
  id->misc->session_variables->cart+=({ 
     ent
  });

trigger_event("postadditem", id, ent );

}
else 
{
  id->misc["ivendstatus"]+= (string) quantity +" " +
    ITEM + " " + item + " " + ADD_FAILED +"<p>"
    + (get_fatal_error(id)*"<br>"); 

}
  return 1;
}

void event_postadditem(string event_name, object id, mapping args)
{

  id->misc["ivendstatus"]+= (string) args->quantity +" " +
    ITEM + " " + args->item + " " + ADDED_SUCCESSFULLY +"\n"; 

}

mixed do_additems(object id, array items){
werror("do_additems: %O\n\n", items);
    // we should add complex pricing models to this algorithm.
    if(DB->local_settings->pricing_model==COMPLEX_PRICING) {
        return do_complex_items_add(id, items);
    }
    else{
        foreach(items, mapping item){
            float price;
	catch(price=(float)(DB->query("SELECT price FROM products WHERE "
                                  + DB->keys->products +  "='" +
                                  item->item +
                                  "'")[0]->price));
		array opt=({});
		mapping o=([]);
	if(item->options) o=get_options(id, item->item, item->options);
		else if(id->variables->options)
		 o=get_options(id, item->item);
		 price=(float)price + (float)(o->surcharge);
            int result=do_low_additem(id, item->item, item->quantity, price, o);
        }
        return 0;
    }
}

void delete_cart_item(object id, string item, string series)
{

    if(id->misc->session_variables->cart[(int)series])
    {
	if(id->misc->session_variables->cart[(int)series]->item == item)
	{
	    mapping dv= copy_value(id->misc->session_variables->cart[(int)series]);
	    
	    trigger_event("predeleteitem", id, dv );
	    if(!had_fatal_error(id))
	    {
                id->misc->session_variables->cart-= ({ id->misc->session_variables->cart[(int)series] });
		trigger_event("postdeleteitem", id, dv );
	    }
	    else
	    {
		id->misc["ivendstatus"]+= (string)
		    ITEM + " " + dv->item + " delete failed.<p>"
		    + (get_fatal_error(id)*"<br>"); 

	    }
	}
    }
    
} 

mixed container_icart(string name, mapping args, string contents, object id) {
    string retval="";
    string extrafields="";
werror(sprintf("%O", id->misc->session_variables->cart));
    if(!id->misc->session_variables->cart) 
      id->misc->session_variables->cart=({});
    array ef=({});
    array en=({});
    array efs=({});
    int madechange=0;
    if(args->fields){
        ef=args->fields/",";
        if(args->names)
            en=args->names/",";
        else en=({});
        for(int i=0; i<sizeof(ef); i++) {
            if(catch(en[i]) || !en[i])  en+=({ef[i]});
            efs+=({ ef[i] + " AS " + "'" + en[i] + "'"});
        }
        extrafields = (efs *", ");
    }

    //
    //  are we deleting an item from the cart?
    //

    string p, s, q;

    foreach(indices(id->variables), string v) {
        if(id->variables[v]==DELETE) {
            p=(v/"/")[0];
            s=(v/"/")[1];
            madechange=1; // a delete is considered an update.
	    delete_cart_item(id, p, s);
	}
    }
	// 
	//  are we updating an item in the cart?
	//
	if(id->variables->update) {
werror("we doin' update.\n");
	    for(int i=0; i< (int)id->variables->s; i++) {
		werror("looking at item %d\n\n", i); 
		p=id->variables["p"+(string)i];
		s=id->variables["s"+(string)i];
		q=id->variables["q"+(string)i];
		
		if((int)q == 0) // we're deleting an item from the cart.
		{
		    delete_cart_item(id, p, s);
		    madechange=1;
		} 
		   else // we're updating the quantity, maybe.
		   {

if(id->misc->session_variables->cart && sizeof(id->misc->session_variables->cart)>=(int)s && 
id->misc->session_variables->cart[(int)s])
		       {
			   if(id->misc->session_variables->cart[(int)s]->item == p
)	//		&& (int)id->misc->session_variables->cart[(int)s]->quantity != (int)q)
			   {
                               madechange=1;
				werror("item " + p +" " + s +" changed to " + q + "\n");
			       id->misc->session_variables->cart[(int)s]->quantity = (int)q;
			   
			   trigger_event("updateitem", id, (["item" : id->variables["p" +
										    (string)i] , "series" : id->variables["s" + (string)i],
							     "quantity": id->variables["q" + (string)i]]) );
			   }
		       }
		   }
	       }
	  }

    if(madechange==1){
        array r = copy_value(id->misc->session_variables->cart);
        if(r && sizeof(r)>0) {
	    array items=({});
          id->misc->session_variables->cart=({});
          foreach(r, mapping row) {
	      if(((int)(row->lock))==1 || ((int)(row->autoadd)==1))
		 continue;
             items+=({ (["item": row->item, "quantity": row->quantity, "options":
			 row->options, "lock": row->lock, "autoadd": row->autoadd ]) });
          }
          do_additems(id, items);
	}
    }
    
    string field;
    
    //
    //  now that the changes have been made, we can display the cart.
    //

    retval+="<form action=\""+id->not_query+"\" method=post>\n<table>\n"
	"<input type=hidden name=referer value=\"" +
	id->variables->referer + "\">\n";
    
    array r;

    if(sizeof(id->misc->session_variables->cart)==0) {
	if(id->misc->ivend->error)
	  return YOUR_CART_IS_EMPTY +"\n<false>\n";
    }
    
    r = ({});
    foreach(id->misc->session_variables->cart, mapping row)
    {
	array rx;
      write("SELECT " + extrafields + " FROM products WHERE "
                                + DB->keys->products + " = '" + row->item + "'");
      if(catch(rx= DB->query("SELECT " + extrafields + " FROM products WHERE "
			     + DB->keys->products + " = '" + row->item + "'")))
	  return "An error occurred while accessing your cart."
	     "<!-- Error follows:\n\n" + DB->error() + "\n\n-->";
      if(sizeof(rx))
      {
	  r+=({ rx[0] + row });
      }        
      
    }

    retval+="<cartdata>";
   array elements=({});
   foreach(en, field){
       elements+=({"<cartheader>"+field+"</cartheader>"});
   }
   elements+=({"<cartheader>" + WORD_OPTIONS + "</cartheader>"});
   elements+=({"<cartheader>" + PRICE +"</cartheader>"});
   elements+=({"<cartheader>" + QUANTITY +"</cartheader>"});
   elements+=({"<cartheader>" + TOTAL + "</cartheader>"});
   elements+=({"<cartheader></cartheader>"});
   retval+="<cartrow>" + elements*"\t";
   retval+="</cartrow>\n";
   
   for (int i=0; i< sizeof(r); i++){
       elements=({});
	for (int j=0; j<sizeof(en); j++)
	 if(j==0) elements+=({"<cartcell align=left><INPUT TYPE=HIDDEN NAME=s"
			    + i + " VALUE="+ i +">"
			    "<INPUT TYPE=HIDDEN NAME=p"+i+" VALUE="+r[i]->item+
			    "><A HREF=\""+ id->misc->ivend->storeurl  +
			    r[i]->item + ".html\">"
			    +r[i][en[j]]+"</A></cartcell>"});
     
       else elements+=({"<cartcell align=left>"+(r[i][en[j]] || " N/A ")
			+"</cartcell>"});
     
     string e="<cartcell align=left>";
  array o=r[i]->options/"\n";

  array eq=({});
  foreach(o, string opt){
      array o_=opt/":";
      catch(  eq+=({DB->query("SELECT description FROM item_options WHERE "
			      "product_id='" + r[i]->item + "' AND option_type='" +
			      o_[0] + "' AND option_code='" + o_[1] + "'")[0]->description}));
  }
	
werror("options: %O\n\n", eq);
  e+=(eq*"<br>") + "</cartcell>";
  elements+=({e});
  elements+=({"<cartcell align=right>" + MONETARY_UNIT +
	      sprintf("%.2f",(float)r[i]->price)+"</cartcell>"});

  elements+=({"<cartcell><INPUT TYPE="+
	      ((int)(r[i]->lock)==1?"HIDDEN":"TEXT") +
	      " SIZE=3 NAME=q"+i+" VALUE="+
	      r[i]->quantity+">" + ((int)(r[i]->lock)==1?r[i]->quantity:"")
	      + "</cartcell>"});
  elements+=({"<cartcell align=right>" + MONETARY_UNIT
	      +sprintf("%.2f",(float)r[i]->quantity*(float)r[i]->price)+"</cartcell>"});
  
  e="<cartcell align=left>";
  if((int)(r[i]->autoadd)!=1)
      e+="<input type=submit value=\"" + DELETE + "\" NAME=\"" + r[i]->item + "/" + i + "\">";
  e+="</cartcell>";
  elements+=({e});
  retval+="<cartrow>" + elements*"\t";
  retval+="</cartrow>\n";
   }
   retval+="</cartdata>\n<input type=hidden name=s value="+sizeof(r)+">\n"
      "<table><tr><td><input name=update type=submit value=\""
      + UPDATE_CART + "\"></form></td>\n";
  if(!id->misc->ivend->checkout)
  {
      if(args->checkout_url)
	retval+="<td><form action=\"" + args->checkout_url + "\">";
    else
	retval+="<td> <form action=\""+ query("mountpoint") + "checkout/"
	   + "\">";
    retval+="<input name=update type=submit value=\"" + CHECK_OUT + "\"></form></td>";
  }
    
  if(!id->misc->ivend->checkout && (args->cont||id->variables->referer))
  {
      retval+="<td> <form action=\"" +
          (args->cont||id->variables->referer) + "\">"
	  "<input type=submit value=\"Continue\"></form></td>";
  }
  retval+="</tr></table>\n<true>\n"+contents;
  return retval;
}


string tag_additem(string tag_name, mapping args,
                   object id, mapping defines) {
    string retval="";
    if(id->variables->ADDITEM && !id->misc->ivend->handled_page)
        additem(id);
    id->misc->ivend->handled_page=1;

    if(args->item) {
        if(!args->noform)
            retval="<form action=\"" + (args->action||id->not_query) + "\">";
        if(!args->silent){
            if(args->showquantity)
                retval+=QUANTITY +": <input type=text size=2 value=" +(args->quantity
                        || "1") + " name=" + args->item + "quantity> ";
            retval+="<input type=submit value=\"" + ADD_TO_CART + "\">\n";
        }
        else
            retval+="<input type=hidden size=2 value=" + (args->quantity
                    || "1") + " name=" + args->item + "quantity> ";
        retval+="<input type=hidden name=ADDITEM value=1>";
        retval+="<input type=hidden name=\""+args->item+"\" value=ADDITEM>\n";

        if(!args->noform)
            retval+="</form>\n";
    }
    return retval;

}

string tag_ivendlogo(string tag_name, mapping args,
                     object id, mapping defines) {
if(args->large) return "<img src=\"" + query("mountpoint") +
  "ivend-image/ivendlogo.gif\" border=0>";
else  return "<a external href=\"http://hww3.riverweb.com/ivend\"><img src=\""+
           query("mountpoint")+"ivend-image/ivendbutton.gif\" border=0></a>";

}

string container_rotate(string name, mapping args,
                        string contents, object id) {

    if(!id->misc->fr) id->misc->fr=({});

    id->misc->fr+=({contents});

    return "";

}

string container_category_output(string name, mapping args,
                                 string contents, object id) {

    contents=Caudium.parse_html(contents,([]),
                    (["formrotate":container_rotate]),id);

    string retval="";
    string query;

    if(!args->type) return YOU_MUST_SUPPLY_A_CATEGORY_TYPE;
    if(lower_case(args->type)!="groups"){
        query="SELECT * FROM " + lower_case(args->type) ;
        if(!args->showall) {
            query+=",product_groups ";
            query+=" WHERE product_groups.group_id='" +
                   id->misc->ivend->page + "' AND "
                   + lower_case(args->type) + "." +
                   DB->keys[lower_case(args->type)] + "=product_groups.product_id ";
            if(!args->show)
                query+=" AND status='A' ";

            if(args->restriction)
                query+=" AND " + args->restriction;
            if(args->order)
                query+=" ORDER BY " + args->order; }
    }
    else {

	string parent="";
	if(args->parent) parent=args->parent;
	if(id->variables->parent) parent=id->variables->parent;
        query="SELECT * FROM " + lower_case(args->type);
            query+=" WHERE parent='" + parent + "' ";
        if(args->restriction)
            query+="AND " + args->restriction;
        if(args->show)
            query+="AND status='A'";

        if(args->order)
            query+=" ORDER BY " + args->order;

    }
    array r;
	catch(r=DB->query(query));

    if(!r || sizeof(r)==0) return "<!-- No Records Found.-->\n";

    if(!id->misc->fr)
        retval=do_output_tag( args, r||({}), contents, id );

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

string tag_generateviews(string tag_name, mapping args,
                         object id, mapping defines)
{

    if(!args->type || !args->field) 
	return "<!-- required attributes are not present. -->\n";
    args->type=lower_case(args->type);

    string retval="";
    array r;
    if(catch(
    r = DB->query("SELECT " + args->field + " FROM "
                        + args->type + ", product_groups WHERE product_groups.product_id="
                        + args->type + "." +  DB->keys[args->type] + " AND "
                        + args->type + ".status='A'"
                        " AND product_groups.group_id= '" + id->misc->ivend->page + "' "
                        " GROUP BY " + args->field)))
	{
	error(DB->error(), id);
	return "";
	}

    if(sizeof(r) == 0)
        r=({([])});
    foreach(r, mapping row) {
        if(row[args->field]){ retval+="<h2>" + row[args->field] + "</h2>";
            args->limit=args->field + "='" + (string)row[args->field] +"'";
        }
        else
            args->limit=args->field + " IS NULL";
        retval+=Caudium.make_tag("listitems", args);
        "<!-- Listitems: " + row[args->field] + " -->\n";
    }
    return retval;
}

string tag_listitems(string tag_name, mapping args, object id, mapping defines) {

    string retval="";
    string query;
    mixed cnt, cnt2;

    // default table colors : headline-bg, headline-font, list-bg, list-bg2, list-font

    string headlinebgcolor= args->headlinebgcolor || "navy";
    string headlinefontcolor= args->headlinefontcolor || "white";
    string listbgcolor= args->listbgcolor || "white";
    string listbgcolor2= args->listbgcolor2 || "#ddeeff";
    string listfontcolor= args->listfontcolor || "navy";

    if(!id->misc->ivend->page)
        return "no page!";

    string extrafields="";
    array ef=({});
    array en=({});

    if(args->type)
	args->type=lower_case(args->type);

    if(args->fields) {
        ef=args->fields/",";
        if(args->names)
            en=args->names/",";
        else en=({});
        for(int i=0; i<sizeof(ef); i++) {
            if(catch(en[i]) || !en[i])  en+=({ef[i]});
            extrafields+=", " + ef[i] + " AS " + "'" + en[i] + "'";
        }
    }
    string tablename;
    array r;
    if(args->type=="custom") {

        query=args->query;
        tablename="products";
    }
    else if(args->type=="groups") {
        array r;
	catch(r=DB->query("SELECT id FROM groups WHERE id='" +
          id->misc->ivend->page + "'"));
	if(r && sizeof(r)>0) args->parent=r[0]->id;
	else args->parent="";
        query="SELECT " + DB->keys->groups + " AS pid " +
              extrafields+ " FROM groups";
        query+=" WHERE parent='" + args->parent
// (id->variables->parent || args->parent 
// || "")
 + "' ";
        if(!args->show)
            query+="AND status='A' ";
        tablename="groups";
    }
    else {
        query="SELECT product_id AS pid "+ extrafields+
              " FROM product_groups,products where group_id='"+
              id->misc->ivend->page+"'";
        tablename="products";

        if(!args->show)
            query+=" AND status='A' ";
        else if(args->show!="")
	    query+=" AND status='" + args->show + "' ";

        if(args->limit)
            query+=" AND " + args->limit;

        query+=" AND products." + DB->keys->products +
               "=product_id";

    }

    if(args->order)
        query+=" ORDER BY " + args->order;

    catch(r=DB->query(query));

    if(sizeof(r)==0 && !args->quiet) return "<false>\n";
    else if(sizeof(r)==0 && args->quiet) return "<!-- " +
	NO_PRODUCTS_AVAILABLE + " -->\n<false>\n";
    else retval+="<true><!-- returned true -->\n";

    array tab=({});
string fname;
    foreach(r, mapping row){
    array rw=({});
    int z=0;
	foreach(en, fname) {
		if(z==0)
                rw+=({("<A " + (args->template?("TEMPLATE=\"" +
                                                     args->template + "\""):"") +
                            " HREF=\""+row->pid+".html\">"+
				row[fname]+"</A>")});
		else
			rw+=({row[fname]});
		z++;
	}
	tab+=({rw});
    }

    if(args->title) retval+="<listitemstitle>" + args->title +
		"</listitemstitle>\n";

    retval += "<table bgcolor=#000000 cellpadding=1 cellspacing=0 border=0>";
    retval += "<tr><td><table border=0 cellspacing=0 cellpadding=4><tr bgcolor=" + headlinebgcolor + ">\n";

    foreach (indices(en), cnt) {
        retval += sprintf("<th nowrap align=left><font color=%s>%s&nbsp; </font></th>\n",
                          headlinefontcolor, (string)en[cnt]);
    }
    retval+="</tr>\n";
    int i=0;
    int m = (int)(args->modulo?args->modulo:1);
    foreach(tab, array r) {

        retval +="<tr bgcolor=" +  (((i/m)%2)?listbgcolor:listbgcolor2) +">\n";
        foreach(r, string va) {
            string align;
            align="left";
            retval += sprintf("<td nowrap align=" + align + "><font color=%s>%s&nbsp;&nbsp;</td>\n",
                              listfontcolor, (string)va);

            i++;
        }
        retval+="</tr>\n";
    }

    retval += "</table></td></tr></table>";

    return retval;

}



string tag_ivstatus(string tag_name, mapping args,
                    object id, mapping defines)
{


    return "<status>" + (((id->misc->ivendstatus || "")
	/"\n")*"</status><status>") +
		"</status>";

}
string tag_ivmg(string tag_name, mapping args,
                object id, mapping defines)

{

    string filename="";
    array r;
    if(args->field!=""){
        catch(r=DB->query("SELECT "+args->field+ " FROM "+
                              id->misc->ivend->type+"s WHERE "
                              " " +  DB->keys[id->misc->ivend->type+"s"]  +"='"
                              +id->misc->ivend->item+"'"));
        if(!r) return "<!-- query failed -->";
        else if (sizeof(r)!=1) return "<!-- no records returned -->";
        else if ((r[0][args->field]==0))
            return "<!-- No image for this record. -->\n";
        else filename=QUERY(storeroot) + "/html/images/"+
                          id->misc->ivend->type+"s/"+r[0][args->field];
    }
    else if(args->src!="")
        filename=QUERY(storeroot)+"/html/images/"+args->src;

    array|int size=size_of_image(filename);


    // file doesn't exist
    if(size==-1)
        return "<!-- couldn't find the image: "+filename+"... -->";

    args->src=query("mountpoint") + "images/" 
              +id->misc->ivend->type+"s/"+r[0][args->field];
    if(arrayp(size)){
        args->height=(string)size[1];
        args->width=(string)size[0];
    }

    return Caudium.make_tag("img", args);


}

mixed handle_cart(string filename, object id){
#ifdef MODULE_DEBUG
    perror("iVend: handling cart for "+ id->misc->ivend->st+"\n");
#endif

    string retval;
    if(!(retval=Stdio.read_bytes(QUERY(storeroot)+"/html/cart.html")))
        error("Unable to find the file "+
              "/cart.html",id);

    return retval;

}

string container_itemoutput(string name, mapping args,
                            string contents, object id) {
    string page=(args->item || id->misc->ivend->page);
    string type=lower_case(args->type || id->misc->ivend->type ||
                           "product");
    string item=(args->item || id->misc->ivend->page);

    mixed o_page=id->misc->ivend->page;
    mixed o_item=id->misc->ivend->item;
    mixed o_type=id->misc->ivend->type;

    //   id->misc->ivend->page=page;
    id->misc->ivend->type=type;
    id->misc->ivend->item=item;

    string retval="";

    string q="SELECT *" + (args->extrafields?"," +
                           args->extrafields:"") +" FROM " +
             lower_case(type) + "s WHERE " +
             DB->keys[type + "s"]
             +"='"+ item +"'";

    array r;
	catch(r=  DB->query(q));

    if(sizeof(r)==0)
        return 0;

    array desc=DB->list_fields(type +"s");

    for(int i=0; i<sizeof(desc); i++){

        if(desc[i]->type=="decimal" && desc[i]->name=="price") {
            r[0][desc[i]->name]=(string)convert((float)r[0][desc[i]->name], id);
            r[0][desc[i]->name]=sprintf("%.2f",(float)(r[0][desc[i]->name]));
        }

        else  if(desc[i]->type=="decimal")
            r[0][desc[i]->name]=sprintf("%.2f",(float)(r[0][desc[i]->name]));

    }
    retval=Caudium.parse_html(do_output_tag( args, ({ r[0] }), contents, id ),
                  (["ivmg":tag_ivmg]),([]),id);
    id->misc->ivend->page=o_page;
    id->misc->ivend->item=o_item;
    id->misc->ivend->type=o_type;
    return retval;
}

string get_type(string page, object id){

    array r;
    catch(r=DB->query("SELECT * FROM groups WHERE " +
                DB->keys->groups +
                "='"+page+"'"));
    if (r && sizeof(r)==1) { 
	id->misc->ivend->template=r[0]->template;
	return "group";
	}
    catch(r=DB->query("SELECT * FROM products WHERE " +
                DB->keys->products + "='" + page + "'"));

    if(r && sizeof(r)==1) {
	id->misc->ivend->template=r[0]->template;
	return "product";
	}
    else return "";

}

mixed find_page(string page, object id){

    string retval;

    page=(page/".")[0];// get to the core of the matter.
    id->misc->ivend->item=page;
    array(mapping(string:string)) r;
    array f;
    string type=get_type(page, id);
    id->misc->ivend->type=type;
    id->misc->ivend->page=page;
    if(!type)
        return 0;
    if(id->variables->template)
      id->misc->ivend->template=id->variables->template;
   else if(id->misc->ivend->template=="DEFAULT" ||
		id->misc->ivend->template==0)
	id->misc->ivend->template=QUERY(storeroot)+ "/html/" +
type+"_template.html";
    else id->misc->ivend->template=QUERY(storeroot) + "/templates/" +
id->misc->ivend->template +".html";

    retval=Stdio.read_bytes(id->misc->ivend->template);
    if (catch(sizeof(retval)))
        return 0;
    id->realfile=id->misc->ivend->template;
    return (retval);
}

mixed additem(object id){

    if(id->variables->quantity && (int)id->variables->quantity==0) {
        id->misc->ivendstatus= ERROR_QUANTITY_ZERO;

        return 0;
    }
    array items=({});
    foreach(indices(id->variables), string v){
        if(id->variables[v]=="ADDITEM") {
		int quantity=0;
		if(id->variables[v+"quantity"])
			quantity=(int)(id->variables[v+"quantity"]);
            else quantity=((int)(id->variables->quantity) || 1);
if(quantity>0)
items+=({ (["item" : v , "quantity" : quantity]) });
        }
    }

    if(id->variables->item)
            items+=({ (["item": id->variables->item,
                    "quantity":
                    (id->variables[id->variables->item+"quantity"]
                     ||id->variables->quantity || 1)
                   ]) });
    int result=do_additems(id, items);

    return 0;
}

mixed handle_page(string page, object id){
    mixed retval;

    switch(page){

    case "index.html":
        id->realfile=QUERY(storeroot)+"/html/index.html";
        retval= Stdio.read_bytes(QUERY(storeroot)+"/html/index.html");
        break;

    default:
        Stdio.Stat fs;
        string p = Stdio.append_path(QUERY(storeroot) + "html", page);
        string rp;
        fs=predef::file_stat(p);

        if(!fs) {
            id->misc->ivend->page=page-".html";
            return find_page(page,id);
        }
        else if(fs->isdir) {
            rp =combine_path(page, "index.html");
            fs=predef::file_stat(rp);

            if(fs && fs->isreg) {
                return Caudium.HTTP.redirect(page + "/index.html", id);
            }
            else return 0;
        }
        id->misc->ivend->page=page-".html";
	string template;
        id->misc->ivend->type=get_type(id->misc->ivend->page, id);

        retval=Stdio.read_file(p);
        id->realfile=p;
    }
    if (!retval) return 0;  // error(UNABLE_TO_FIND_PRODUCT +" " + page,id);
    return retval;

}

mapping ivend_image(array(string) request, object id){

    string image;
    image=read_file(query("root")+"/data/images/"+request[0]);

    return http_string_answer(image,
                              id->conf->type_from_filename(request[0]));

}

mapping http_string_answer(string text, string|void type, object|void id)
{
if(id){
if(!id->misc->defines) id->misc->defines=([]);
  return (["data":text,
           "type":(type||"text/html"),
           "stat":id->misc->defines[" _stat"],
           "error":id->misc->defines[" _error"],
           "rettext":id->misc->defines[" _rettext"],
           "extra_heads":id->misc->defines[" _extra_heads"],
           ]);
}
else 
    return ([ "data":text, "type":(type||"text/html") ]);
}

mapping http_auth_required(string realm, string|void message, object id)
{
  if(!message)
    message = "<h1>Authentication failed.\n</h1>";
#ifdef HTTP_DEBUG
  perror("HTTP: Auth required ("+realm+")\n");
#endif
                 if(!id->misc->defines)
                     id->misc->defines=([]);
                 if(!id->misc->defines[" _extra_heads"])
                     id->misc->defines[" _extra_heads"]=([]);
    

id->misc->defines[" _extra_heads"]+=([ 
	"WWW-Authenticate":"basic realm=\""+realm+"\""]);

  return http_low_answer(401, message)
    + ([ "extra_heads": id->misc->defines[" _extra_heads"]
        ]);

}


// Start of auth functions.

int|mixed admin_auth(object id)

{
if(!admin_user_cache)  // if we don't have it already, make space for our cache.
  admin_user_cache=([]);
if(id->cookies->admin_user && id->cookies->admin_user!="")
 { 
  if(admin_user_cache[id->cookies->admin_user] && 

(admin_user_cache[id->cookies->admin_user]==id->cookies->admin_auth))
{
  id->misc->ivend->admin_user=id->cookies->admin_user;
  return 1;
  }
 }

    mixed m;

if(id->variables->user !=""){
	catch(array r=DB->query("SELECT * FROM admin_users WHERE username='" +
		id->variables->user + "'"));
	if(sizeof(r)==1)
	  { // we've got a valid user.
		if(!crypt(id->variables->password, r[0]->password))
		{
add_cookie(id, (["name":"logging_in",
          "value":"1", "seconds": 120]),([]));
admin_user_cache[upper_case(id->variables->user)]="";
  return "<html><head><title>Login</title></head>\n"
	"<body bgcolor=white text=navy>\n"
	"<h1>iVend Login</h1>"
	"<b>Invalid Login.</b>"
	"<form action=./ method=post name=\"ivendloginform\">"
	"<input type=hidden name=" + time() + ">"
	"<table><tr><td rowspan=2><img src=\"" +
	 query("mountpoint") + "ivend-image/auth.gif\">&nbsp;&nbsp; "
	"</td><th>Username:</th>\n"
	"<td><input type=text size=15 name=user "
	"onChange=this.form.password.focus()></td></tr>\n"
	"<tr><th>Password:</th>\n"
	"<td><input type=password size=15 name=password "
	"onChange=this.form.submit()></td></tr>\n"
	"<tr><td> &nbsp; </td><td><input type=submit value=\"Login\">"
	"</td></tr></table>\n"
	"</form>\n"
	"<script language=\"JavaScript\">\n"
	"<!-- \n"
	"document.ivendloginform.user.focus(); \n"
	"// -->\n"
	"</script>\n"
	"<p>Copyright 1997-2003 Bill Welliver</body></html>";

		}
		id->misc->ivend->admin_user=r[0]->username;
		id->misc->ivend->admin_user_level=r[0]->level;

 object md5 = Crypto.MD5();
    md5->update(id->variables->password);
    md5->update(sprintf("%d", roxen->increase_id()));
    md5->update(sprintf("%d", time(1)));
    string SessionID = Caudium.Crypto.string_to_hex(md5->digest());
    admin_user_cache[id->misc->ivend->admin_user]=SessionID;
    
             add_cookie(id, (["name":"admin_user",
                              "value":r[0]->username, "seconds": 3600]),([]));
	     add_cookie(id, (["name":"admin_auth",
			      "value":SessionID, "seconds": 3600 ]), ([]));
             add_cookie(id, (["name":"logging_in",
                              "value":"", "seconds": 1]),([]));
		return 1;
	  }

}

  add_cookie(id, (["name":"logging_in",
          "value":"1", "seconds": 120]),([]));
  return "<html><head><title>Login</title></head>\n"
	"<body bgcolor=white text=navy>\n"
	"<h1>iVend Login</h1>"+
	(id->variables->user?"<b>Invalid Login.</b>":"")+
	"<form action=./ method=post name=\"ivendloginform\">"
	"<input type=hidden name=" + time() + ">"
	"<table><tr><td rowspan=2><img src=\"" +
	 query("mountpoint") + "ivend-image/auth.gif\">&nbsp;&nbsp; "
	"</td><th>Username:</th>\n"
	"<td><input type=text size=15 name=user "
	"onChange=this.form.password.focus()></td></tr>\n"
	"<tr><th>Password:</th>\n"
	"<td><input type=password size=15 name=password "
	"onChange=this.form.submit()></td></tr>\n"
	"<tr><td> &nbsp; </td><td><input type=submit value=\"Login\">"
	"</td></tr></table>\n"
	"</form>\n"
	"<script language=\"JavaScript\">\n"
	"<!-- \n"
	"document.ivendloginform.user.focus(); \n"
	"// -->\n"
	"</script>\n"
	"<p>Copyright 1997-2003 Bill Welliver</body></html>";

}



// Start of admin functions


mixed getmodify(string type, string pid, object id){

    string retval="";
    multiset gid=(<>);
    array record;
	catch(record=DB->query("SELECT * FROM " + type + "s WHERE "
                           +  DB->keys[type +"s"]  + "='" + pid +"'"));
    if (!record || sizeof(record)!=1)
        return "Error Finding " + capitalize(type) + " " +
               DB->keys[type +"s"] + " " + pid + ".<p>";

    if(type=="product") {
        array groups;
	catch(groups=DB->query("SELECT group_id from " 
                              "product_groups where product_id='"+ pid +
				"'"));
        if(groups && sizeof(groups)>0)
            foreach(groups, mapping g)
            gid[g->group_id]=1;
        record[0]->group_id=gid;
    }

    retval+="Please fill out the following information. Required fields "
            "are indicated by the <i>" + REQUIRED + "</i> next to the "
	    "field.";

    if(type=="product")
        retval+="<table>\n"+DB->gentable("products",
                                         Caudium.add_pre_state(id->not_query, (<"domodify=product">)),"groups",
                                         "product_groups", id, record[0])+"</table>\n";
    else if(type=="group")

        retval+="<table>\n"+DB->gentable("groups",
                                         Caudium.add_pre_state(id->not_query,
(<"domodify=group">)),0,0,id,
                                         record[0])+"</table>\n";

    return retval;

}

int my_security_level(object id){

 if(!id->misc->ivend->admin_user) return -1;
 if(id->misc->ivend->admin_user=="admin") return 9;
 array r=DB->query("SELECT * FROM admin_users WHERE username='" +
	id->misc->ivend->admin_user + "'");
 if(sizeof(r)!=1) return -1;
 return (int)(r[0]->level);
}

mixed have_admin_handler(string type, object id){
    if(!type || type=="")
        return 0;
    array i=indices(admin_handlers);

    foreach(i, string h){
        int loc= sizeof(h);
        loc-=sizeof(type);
        loc--;
        catch{ if(search(h, type, loc)!=-1)
            type=h;
	};
    }

    if(admin_handlers[type] &&
                functionp(admin_handlers[type]->handler)){
	int security_level;
	if(admin_handlers[type]->security_level)
	  security_level=admin_handlers[type]->security_level;
	else security_level=0;
	if(my_security_level(id)>=security_level)
        return type;
	}

}

mixed handle_admin_handler(string type, object id){

    mixed rv;
    rv=admin_handlers[type]->handler(type, id);
    return rv;

}

mixed open_popup(string name, string location, string mode, mapping
                 options, object id){
    name=replace(name," ","_");
    string retval="";
    if(!id->misc->ivend->popup) id->misc->ivend->popup=1;
    else id->misc->ivend->popup++;

    retval+="<SCRIPT>"
            "\n"
            "function popup_" + id->misc->ivend->popup
		+ "(name,location,w,h) {\n"
            " mainWin=self\n"
            "	if(h<1) h=300\n"
            "	if(w<1) w=300\n"
            "        if (navigator.appVersion.lastIndexOf('Mac') != -1) h=h-200\n"
            "        if (navigator.appVersion.lastIndexOf('Win') != -1) h=h-130\n"
            "\n";
if(options->type){
retval+=	"var idn=document.gentable."
 + lower_case(DB->keys[options->type+ "s"]) +
		".value\n"
	    " document.popupform" + id->misc->ivend->popup
+".id.value=idn\n"
	    " if(idn=='') { alert('You have not specified a " +
		DB->keys[options->type + "s"] + ".')\n return\n}\n";
}
retval+= "param='resizable=yes,toolbar=no,location=no,directories=no,status=no,menubar=no,scrollbars=no,copyhistory=yes,width='+w+',height='+h\n"
            "        palette=window.open(location,name,param)\n"
            // "        window.open('',name,param)\n"
            "        \n"
            "        if (palette!=null) palette.opener=mainWin \n"
	    "document.popupform" + id->misc->ivend->popup + ".submit()\n"
            "}\n"
            "</SCRIPT>"
            "<form name=popupform" + id->misc->ivend->popup + " target=" +
		name + " ACTION=\"" + Caudium.add_pre_state(id->not_query, (<mode>))
            +"\">";
    foreach(indices(options), string o){

        retval+="<input type=hidden name=\"" + o + "\" value=\"" + options[o] +
                "\">\n";
    }

    retval+="<input type=hidden name=id value=\"" +
       id->variables[DB->keys[options->type + "s"]] + "\">";
    retval+="<input type=hidden name=mode value=\""  +mode + "\">"
            "<input onclick=\"popup_" + id->misc->ivend->popup + "('"
		+name +"','" + Caudium.add_pre_state(id->not_query,
                          (<mode>))  + "'," +(options->width||450)+ ","
		+(options->height||300)+
		")\" type=reset value=\""
		+ replace(name,"_"," ") + "\">"
            "</form>";

    return retval;

}



string return_to_admin_menu(object id){

                 return "<a href=\""  + 	   Caudium.add_pre_state(id->not_query,
                         (<"menu=main">))+   "\">"
                        "Return to Store Administration</a>.\n";

             }

             mixed admin_handler(string filename, object id){
	       // perror("admin interface\n");
if(!QUERY(admin_enabled))
  return 0;

                 string mode, type;
if(id->variables->logout){
   add_cookie(id, (["name":"admin_user",
                 "value":"", "seconds": 1]),([]));
   add_cookie(id, (["name":"admin_auth",
                 "value":"", "seconds": 1]),([]));
   admin_user_cache[id->cookies->admin_user]="";
return "You have logged out.<p><a href=\"./\">Click here to continue.</a>";
}
                 if(sizeof(id->prestate)==0) {
                     id->prestate=(<"menu=main">);
                     return Caudium.HTTP.redirect(id->not_query + (
                                              (id->not_query[sizeof(id->not_query)-1..]!="/")?"/":"") +
                                          (id->query?("?" + id->query):""), id);
                 }

mixed r=admin_auth(id);
if(!intp(r)){
  return r;
}

                 string retval="";
                 retval+="<html><head><title>iVend Store Administration</title></head>"
                         "<body bgcolor=white text=navy>"
                         "<img src=\""+query("mountpoint")+"ivend-image/ivendlogosm.gif\"> &nbsp;"
                         "<img src=\""+query("mountpoint")+"ivend-image/admin.gif\"> &nbsp;"
                         "<gtext fg=maroon nfont=bureaothreeseven black>"
                         + QUERY(storename)+
                         " Administration</gtext><br>"
"<config_tablist>"
"<tab href=\"groups/\">Work With Groups</tab>"
"<tab href=\"products/\">Work With Products</tab>"
"<tab href=\"orders/\">Work With Orders</tab>"
"<tab href=\"setup/\">Store Setup</tab>"
"</config_tablist><p>"
                         "<font face=helvetica,arial size=+1>"
                         "<a href=\"" +
                         id->misc->ivend->storeurl + "\">Storefront</a> &gt; <a href=\"" +
                         Caudium.add_pre_state(id->not_query,(<"menu=main">))+"\">Admin Main Menu</a>\n";


                 if(id->prestate && sizeof(id->prestate)>0){
                     array(string) m=indices(id->prestate);
                     m=m[0]/"=";
                     mode=m[0];
                     if(sizeof(m)>1)
                         type=m[1];
                     if(search(mode, ".") !=-1){
                         m=mode/".";
                         mode=m[sizeof(m)-1];
                     }
                 }

                 array valid_handlers=({});

                 foreach(indices(admin_handlers), string h)
                 if(search(h, mode + (type?"."+type:""))!=-1){
                     string m=h-(mode + (type?"."+type:""));
                     if((m+(mode + (type?"."+type:"")))!=h)
                         valid_handlers+=({h});
		foreach(valid_handlers, string vh)
			if(admin_handlers[vh]->security_level
>my_security_level(id)) valid_handlers-=({vh});
                 }
                 switch(mode){

                 case "doadd":
                     mixed xj=DB->addentry(id,id->referrer);
                     retval+="<br>";
                     if(!intp(xj)){
                         return retval+= "<p>The following errors occurred:<p><ul><li>" + (xj*"<li>")
				+"</ul><p>"
	"Please return to the previous page to remedy this  "
"situation before continuing.</body></html>";
                     }
                     else{
                         type=(id->variables->table-"s");
               trigger_event("adminadd", id, (["type": type, 
		"id": id->variables[DB->keys[type + "s"]] ])
);
                       return (retval+"<br>"+capitalize(type)+" Added Sucessfully.")
				+"</body></html>";

                     }
                     break;

                 case "domodify":
                     xj=DB->modifyentry(id,id->referrer);
                     retval+="<br>";
                     if(stringp(xj)){
                         return retval+= "The following errors occurred:<p><li>" + (xj*"<li>")
				+"</body></html>";
                     }
             trigger_event("adminmodify", id, (["type": type, 
		"id": id->variables[DB->keys[type + "s"]] ])
);

                     return retval +"<br>"+ capitalize(type) + " Modified Sucessfully."
				+"</body></html>";
                     break;

                 case "add":
                     retval+="&gt <b>Add New " + capitalize(type) 
			+"</b><br>\n";
    retval+="Please fill out the following information. Required fields "
            "are indicated by the <i>" + REQUIRED + "</i> next to the "
	    "field. Click on <i>Add</i> when you are finished to add "
	    "this " + type + ".";


                     if(sizeof(valid_handlers)) retval+="<obox title=\"<font "
                                                            "face=helvetica,arial>Actions\">"
				"<table><tr>";

                     foreach(valid_handlers, string handler_name) {
                         string name;
                         array a=handler_name/".";
                         name=a[sizeof(a)-1];
			retval+="<td>";
                         retval+=open_popup( name,
                                 id->not_query + "?window=popup", handler_name ,
				(["type" : type, "width":550]) ,id);
			retval+="</td>\n";
                     }
                     if(sizeof(valid_handlers))
                         retval+="</tr></table></obox>";

                     if(type=="product")
                         retval+="<table>\n"+ DB->gentable("products",
                                                           Caudium.add_pre_state(id->not_query,(<"doadd=product">)),"groups",
                                                           "product_groups", id)+"</table>\n";
                     else if(type=="group")
                         retval+="<table>\n"+
                                 DB->gentable("groups",Caudium.add_pre_state(id->not_query,(<"doadd=group">)),0,0,id)+"</table>\n";
			retval+="</body></html>";
                     break;

                 case "dodelete":
                     if(id->variables->confirm){
                         if(id->variables[DB->keys[type +
"s"]]==0 || id->variables[DB->keys[type + "s"]]=="")
                             retval+="<p>You must select an existing ID to act upon!<br>";
                         else {

foreach(id->variables[DB->keys[type
+"s"]]/"\000", string d) {
				 retval+="<p>\n"+DB->dodelete(type,
                      			d, DB->keys[type+"s"] ); 
             trigger_event("admindelete", id, (["type": type, 
		"id": d]) );
}
				} }
                     else {
                         if(id->variables->match) {
                             mixed n=DB->showmatches(type,

id->variables[DB->keys[type+ "s"]],
                                                     DB->keys[type+"s"], id);
                             if(n)
                                 retval+="<form _parsed=1 name=form action=\"" +
					Caudium.add_pre_state(id->not_query,(<"dodelete=" + type>)) +"\">\n"
                                         + n +
                                         "<input type=hidden name=mode value=dodelete>\n"
                                         "<input type=submit value=Delete>\n</form>";
                             else retval+="<br>No " + capitalize(type +"s") + " found.";
                         }
                         else {
                                 retval+="<form name=form action=\"" +
                                         Caudium.add_pre_state(id->not_query,(<"dodelete=" + type>))
                                         + "\">\n"
                                         "Are you sure you want to delete the following?<p>";
//perror("Input: " + id->variables[DB->keys[type +"s"]] + "\n");
	foreach(id->variables[DB->keys[type +"s"]]/"\000",
string d){
                             mixed n= DB->showdepends(type,
							d
                                                      , DB->keys[type+"s"],
(type=="group"?DB->keys->products:0), id);
                             if(n){  retval+=
                                         "<input type=checkbox name=\"" +
					DB->keys[type+"s"] +
"\" value=\"" +d +"\" checked>\n";
         retval+=n;
			}
                             else retval+="<p>Couldn't find "+capitalize(type) +" "
                                              +id->variables[DB->keys[type+"s"]]+".<p>";
                             }
retval+="<input type=submit name=confirm value=\"Really Delete\"></form><hr>";
                         }

                     }

                 case "delete":
                     retval+="<form name=form action=\""+
                             Caudium.add_pre_state(id->not_query,(<"dodelete=" + type>))+"\">\n"
                             "<input type=hidden name=mode value=dodelete>\n"
                             +capitalize(type) + " "+
                             DB->keys[type +"s"] + " to Delete:\n"
                             "<input type=text size=10 name=\"" +
                             DB->keys[type+"s"] + "\">\n"
                             "<input type=hidden name=type value=" + type + ">\n"
                             "<br><font size=2>If using FindMatches, you may type any part of an "
                             + DB->keys[type+"s"] +
                             " or Name to search for.<br></font>"
                             "<input type=submit name=match value=FindMatches> &nbsp; \n"
                             "<input type=submit value=Delete>\n</form>";
                     break;

                 case "restartstore":
                     stop_store();
                     start_store();
                     retval+="Store Restarted Successfully.<p>" +
                             return_to_admin_menu(id);
                     break;

                 case "getmodify":
                     retval+="&gt <b>Modify " + capitalize(type)
                             +"</b><br>\n";
                     if(sizeof(valid_handlers)) retval+="<obox title=\"<font "
                                                            "face=helvetica,arial>Actions\">"
			"<table><tr>";

                     foreach(valid_handlers, string handler_name) {
                         string name;
                         array a=handler_name/".";
                         name=a[sizeof(a)-1];
			retval+="<td>";
                         retval+=open_popup( name,
                                 id->not_query + "?window=popup", handler_name ,
				(["type": type, "width":550]) ,id);
			retval+="</td>\n";
                     }
                     if(sizeof(valid_handlers))
                         retval+="</tr></table></obox>";
                     retval+=getmodify(type,
                                       id->variables[DB->keys[type+"s"]], id)
				+"</body></html>";

                     break;

                 case "show":
                     retval+="&gt <b>Show " + capitalize(type)
                             +"</b><br>\n";
                     retval+="<form name=form action=\"./\">\n"
                             "<input type=hidden name=mode value=show>\n"
                             "<input type=hidden name=type value="+ type + ">\n"
                             "<table><tr><td><input type=submit value=Show>"
				"<br><input type=reset value=\"Clear\">"
				"</td><td>\n";
                     retval+="<td><font face=helvetica,arial size=2><b>Show fields:</b> ";
                     array f=DB->list_fields(type+"s");
                     array k;
                     catch(k=DB->query("SHOW INDEX FROM " +
                                           type + "s"));

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

                     retval+="</font></td>";
			retval+="<td><font face=helvetica,arial "
			"size=2><b>Show:</b></font></td><td>"
			"<font face=helvetica,arial size=2>"
			   "<script language=javascript>"
			   "function setmatch() {\n"
//		"alert('Value of __matchfield is |' + document.form.__criteria.value + '|.');\n"
		"if(document.form.__matchfield.value!=\"NONE\")\n{"
			   "document.form.__select[1].checked=true;\n"
			"document.form.__rule[0].checked=true;\n"
			"}\n"
			"else \n"
			"document.form.__select[0].checked=true;\n"
			   "}\n"
			   "</script>"
			   "<input type=radio " +
(id->variables->__select!="some"?"checked":"") +" name=__select value=all> All<br>"
			   "<input type=radio " +
(id->variables->__select=="some"?"checked":"") +
" name=__select value=some> Match"
			   "</font></td><td><font face=helvetica,arial size=2>"
			   "<select name=__matchfield onchange=setmatch()>"
				"<option value=\"NONE\">Choose Field\n";
			foreach(f, mapping field)
			   retval+="<option " +
	(id->variables->__matchfield==field->name?"selected ":" ") + 
			"value=\"" + field->name + "\">"
				+ field->name + "\n";
			retval+="</select></td>";
		retval+="<td><font face=helvetica,arial size=2>\n"
	"<input type=radio "+ (id->variables->__rule=="like"?"checked":"") 
+" name=__rule value=like>Contains<br>"
	"<input type=radio "+ (id->variables->__rule=="="?"checked":"")
+" name=__rule value=\"=\">Is Exactly<br>"
	"<input type=radio "+ (id->variables->__rule=="<"?"checked":"") +
" name=__rule value=\"<\">Less Than<br>"
	"<input type=radio "+
(id->variables->__rule==">"?"checked":"") +" name=__rule value=\">\">Greater Than<br>"
	"</font></td>\n"
	"<td><font face=helvetica,arial size=2>\n"
	"<input type=text value=\"" + (id->variables->__criteria||"")
	+ "\" name=__criteria size=12></font></td>";
		     retval+="</tr></table>"
                             "<input type=hidden name=primary_key value=\"" +
                             primary_key + "\"></form>\n";
                     string query="SELECT ";
                     array fields=({});
                     foreach(f, mapping v)
                     if(id->variables["show-" + v->name])
                         fields+=({v->name});
                     if(sizeof(fields) > 0) {
                         foreach(fields, string field)
                         query+=field + ", ";

                         query=query[0..(sizeof(query)-3)] + " FROM " + type
                               + "s";
			if(id->variables->__select=="some"){
if(id->variables->__rule=="like") id->variables->__criteria="%" +
id->variables->__criteria + "%";
	query +=" WHERE " + id->variables->__matchfield
				+ " " + id->variables->__rule + " '"+
			         DB->quote(id->variables->__criteria) +
				"'";
			}
                         array r=DB->query(query);
                         if(sizeof(r)>0) {
                             retval+="<form action=\"" +
Caudium.add_pre_state(id->not_query,(<"dodelete=" + type >))  
				+ "\" method=post>"
				"<table>\n<tr><td>"
				"<input type=submit name=\"__delete_marked\" value=\"Delete Marked Items\">"
				"</td>\n";
                             foreach(fields, string f)
                             retval+="<td><b><font face=helvetica,arial>" + f + "</b></td>\n";
                             retval+="</tr>";
                             foreach(r, mapping row){
                                 retval+="<tr>\n<td><font face=helvetica,arial size=0>"
					"<input type=checkbox name=\""
					+ id->variables->primary_key + "\" "
					"value=\"" +
					row[id->variables->primary_key] + "\"> "
                                         "<a href=\"" + Caudium.add_pre_state(id->not_query,
                                                                      (<"getmodify=" + type>))+
                                         "?" +id->variables->primary_key + "=" +
                                         row[id->variables->primary_key] + "\">Modify</a> "
                                         "&nbsp; <a href=\"" +
                                         Caudium.add_pre_state(id->not_query, (<"dodelete="+ type>)) +
                                         "?" + id->variables->primary_key + "=" +
                                         row[id->variables->primary_key] + "\">Delete</a></td>";
                                 foreach(fields, string fld)
                                 retval+="<td>" + row[fld] + "</td>\n";
				if(type=="group"){
					retval+="<td>Show Items</td>\n";
				} 
                            }
                             retval+="</tr>\n";
                             retval+="</table></form></body></html>";
                         }
                         else retval+="Sorry, No Records were found.";
                     }

                     break;

                 case "modify":
                     retval+="&gt <b>Modify " + capitalize(type)
                             +"</b><br>\n";
                     retval+="<form name=form action=\""+Caudium.add_pre_state(id->not_query,(<"getmodify=" + type>))+"\">\n"
                             "<input type=hidden name=mode value=getmodify>\n"
                             + capitalize(type) + " "+
                             DB->keys[type+"s"] + " to Modify: \n"
                             "<input type=text size=10 name=\"" +
                             DB->keys[type+"s"] + "\">\n"
                             "<input type=submit value=Modify>\n</form>";
                     break;

                 default:
                     string m;
                     if(m=have_admin_handler(mode, id)){
                         mixed rv=handle_admin_handler(m,id);
                         if(!stringp(rv)) return rv;
			else if(ADMIN_FLAGS==NO_BORDER) retval="";
                         else{ array mn=mode/".";
                             mode=mn[sizeof(mn)-1];
                             retval+= " &gt; <b>" + (id->query?"<a href=\"./\">":"") +
                                      replace(mode,({"_"}),({" "}))
                                      + (id->query?"</a>":"") + "</b></font><p>";
                             if(ADMIN_FLAGS==NO_ACTIONS);
                             else{
                                 if(sizeof(valid_handlers)) retval+="<obox title=\"<font "
                                                                        "face=helvetica,arial>Actions\"><table><tr>\n";

                                 foreach(valid_handlers, string handler_name) {
                                     string name;
                                     array a=handler_name/".";
                                     name=a[sizeof(a)-1];
                                     retval+="<td>\n";
                                     retval+=open_popup( name,
                                 id->not_query+ "?window=popup", handler_name ,
					(["type": type]) ,id);
                                     retval+="</td>\n";
                                 }
                                 if(sizeof(valid_handlers))
                                     retval+="</tr></table>\n</obox>";
                             }

                         }
			if(mappingp(rv)) {
			  return rv;
			}

                         retval+=rv;
                     }
                     else if(mode=="menu" && type=="main")   {
                         retval+=
                             "<table width=90%>"
                             "<tr><td width=33%>"
                             "<obox title=\"<font face=helvetica,arial>Groups</font>\">\n"
                             "<font face=helvetica,arial>"
                             "<ul>"
                             "<li><a href=\""+
                             Caudium.add_pre_state(id->not_query,(<"show=group">))
                             +"\">Show Groups</a>\n"
                             "<li><a href=\""+
                             Caudium.add_pre_state(id->not_query,(<"add=group">))
                             +"\">Add New Group</a>\n"
                             "<li><a href=\""+
                             Caudium.add_pre_state(id->not_query,(<"modify=group">))
                             +"\">Modify a Group</a>\n"
                             "<li><a href=\""+
                             Caudium.add_pre_state(id->not_query,(<"delete=group">))
                             +"\">Delete a Group</a>\n"
                             "</font>"
                             "</obox>"
                             "<obox title=\"<font face=helvetica,arial>Products</font>\">\n"
                             "<font face=helvetica,arial>"
                             "<ul>"
                             "<li><a href=\""+
                             Caudium.add_pre_state(id->not_query,(<"show=product">))
                             +"\">Show Products</a>\n"
                             "<li><a href=\""+
                             Caudium.add_pre_state(id->not_query,(<"add=product">))
                             +"\">Add New Product</a>\n"
                             "<li><a href=\""+
                             Caudium.add_pre_state(id->not_query,(<"modify=product">))
                             +"\">Modify a Product</a>\n"
                             "<li><a href=\""+
                             Caudium.add_pre_state(id->not_query,(<"delete=product">))
                             +"\">Delete a Product</a>\n"
                             "</font>"
                             "</obox>"
                             "</ul>\n"
                             "</td><td width=33%>\n"
                             "<p><ul>";
                         array cats=({});
                         foreach(valid_handlers, string hn){
                             string m=hn-(mode+"." + (type||"") + ".");
                             if(sizeof(m/".")==1)
                                 cats+=({m});
                             else { m=(m/".")[0]; cats+=({m}); }
                         }
                         cats=Array.uniq(cats);
                         sort(cats);
                         foreach(cats, string category){
                             retval+="<obox title=\"<font face=helvetica,arial>"+ replace(category,
                                     "_", " ") +
                                     "</font>\">\n<font "
                                     "face=helvetica,arial><ul>\n";
                             sort(valid_handlers);
                             foreach(valid_handlers, string hn)
                             if(search(hn, category)!=-1)
                                 retval+="<li><a href=\"" + Caudium.add_pre_state(id->not_query,
					(<replace(hn, mode+"."+(type||"")+".","")>)) + "\">"
                                         + replace(hn,({"_",mode + "." + (type||"") +"." +category
                                                        +"."}),({" ",""})) +
                                         "</a>\n";
                             retval+="</ul></font></obox>";
                         }

                         retval+="</td></tr></table>"
                                 "</ul>"
                                 "<br><b>" + numrequests + "</b> requests handled since last startup."
				"<p>Logged in as " +
				id->misc->ivend->admin_user + ". [ <a "
"href=\"./?logout=1\">Logout</a> ] [ <a "
"href=\"./?change_password=1\">Change Password</a> ]";

                     }
                     else retval+="Sorry, couldn't find handler.";
                     break;

                 }
                 return retval;

             }

             mixed find_file(string file_name, object id){
                 if(!started) {
		   return return_data("This store has not been started.", id);
			}

                 id->misc["ivend"]=([]);
                 id->misc["ivendstatus"]="";
                 mixed retval;
                 id->misc->ivend->error=({});
                 id->misc->ivend->this_object=this_object();
                 array(string) request=(file_name / "/") - ({""});
                 if(catch(request[0])) request+=({""});

                 if(request[0]== "ivend-image") {
                     request=request[1..];
                     return ivend_image(request, id);
		}

                 // load id->misc->ivend with the good stuff...
                 id->misc->ivend->config=config;

                 mixed err;
                 if(!DB) {
                     DB=db->handle();
		}

                if(!DB || !DB->db_info_loaded) {
		   return return_data("This store is currently unavailable.", id);
		}
                MODULES=modules;
                numrequests+=1;

                id->misc->ivend->storeurl=QUERY(mountpoint);

                 if(sizeof(request) && have_path_handler(request*"/"))
                     retval= handle_path( request*"/" , id);

                 if(!retval)
                     switch(request[0]) {
                     case "":
		       string rx=replace((id->not_query + "/index.html" +
					  (id->query?("?"+id->query):"")),"//","/");
                       db->handle(DB);
		       return Caudium.HTTP.redirect(rx, id);
                       break;
                     default:
                         retval=(handle_page(request*"/", id));
                         break;
                     }
                 return return_data(retval, id);

             }

             mixed generic_tag_handler(string name, mapping args,
                                       object id, mapping defines){
                 string retval="";
                 mixed err;
                 if(functionp(library->tag[name]))
                     err=catch(retval=library->tag[name](name, args, id, defines));
                 else err=library->tag[name];

                 if(err) {
                     if(args->hideerrors)
                         return "";
                     if(args->commenterrors)
                         retval+="<!-- ";
                     retval+= "An error occurred while processing tag " + name + ":\n\n";
                     if(!args->commenterrors)
                         retval= retval+"<p><pre>" + describe_backtrace(err) + "</pre>";
                     else retval+=describe_backtrace(err);
                     if(args->commenterrors)
                         retval+="\n-->";
                 }
                 return retval;

             }

             string|void generic_container_handler(string name, mapping args,
                                                   string contents, object id) {
                 string retval="";
                 mixed err;
                 if(functionp(library->container[name]))
                     err=catch(retval=library->container[name](name, args, contents, id));
                 else err=library->container[name];
                 if(err)
                     return "an error occurred while processing tag " + name + ":<br>"
                            + describe_backtrace(err)
                            ;

                 return retval;

             }

             string|void container_ivml(string name, mapping args,
                                        string contents, object id)
             {
		mixed err;
                 if(args->_parsed) return;
                 if(!id->misc->ivend) return "<!-- not in iVend! -->\n\n"+contents;
                 if(args->extrafields)
                     id->misc->ivend->extrafields=args->extrafields;

                 mapping tags=    ([
				   "additem" : tag_additem,
                                   "ivstatus":tag_ivstatus,
                                   "ivmg":tag_ivmg,
                                   "listitems":tag_listitems,
                                   "generateviews":tag_generateviews
                                   ]);

                 mapping containers= ([
                                      "a":container_ia,
                                      "icart":container_icart,
                                      "category_output":container_category_output,
                                      "itemoutput":container_itemoutput
                                      ]);
                 mapping c=([]);
                 mapping t=([]);

                 foreach(indices(
                             library->tag), string n)
                 t[n]=generic_tag_handler;

                 foreach(indices(
                             library->container), string n)
                 c[n]=generic_container_handler;

                 contents= Caudium.make_container("html", (["_parsed":"1"]),
				Caudium.parse_html(contents,
                           t + tags,
                           c + containers, id));
                 MODULES=modules;
//                 contents=parse_rxml(contents,id);
                 return contents;

             }

             mapping query_container_callers()
             {
             return ([ "ivml": container_ivml, "html": container_ivml ]); }

             mapping query_tag_callers()
             {
             return ([ "ivendlogo" : tag_ivendlogo, 
			]); }


             // Start of support functions


             float convert(float value, object id){

                 if(objectp(MODULES->currency)
                             && functionp(MODULES->currency->currency_convert))
                     value=MODULES->currency->currency_convert(value,id);

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
                 return Image.Dims.get(fop);

             }



             void error(mixed error, object id){
                 if(arrayp(error)) id->misc->ivend->error +=({
                                 replace(describe_backtrace(error),"\n","<br>\n") });
                 else if(stringp(error)) id->misc->ivend->error += ({ error });
                 return ;

             }

             mixed handle_error(object id){
                 string retval;
		id->misc->ivend->handled_error=1;
                 if(CONFIG)
                     retval=Stdio.read_file(
                                QUERY(storeroot) +"/html/error.html");


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

                 string data=Stdio.read_bytes(
                                 QUERY(storeroot) +"/html/"+filename);
                 id->realfile=QUERY(storeroot) +"/html/"+filename;

                 return http_string_answer(data,
                                           id->conf->type_from_filename(id->realfile));

             }

             void add_header(object id, string name, string value)
             {   
                 if(!id->misc->defines)
                     id->misc->defines=([]);
                 if(!id->misc->defines[" _extra_heads"])
                     id->misc->defines[" _extra_heads"]=([]);

mapping to=id->misc->defines[" _extra_heads"];
                 if(to[name])
                     if(arrayp(to[name]))
                         to[name] += ({ value });
                     else
                         to[name] = ({ to[name], value });
                 else
                     to[name] = value;
                 return;
             }

             void add_cookie( object id, mapping m, mapping defines)
             {
                 string cookies;
                 int    t;     //time

                 if(m->name)
                     cookies = m->name+"="+Caudium.http_encode_cookie(m->value||"");
                 else
                     return ;

                 if(m->persistent)
                     t=(3600*(24*365*2));
                 else
                 {
                     if (m->hours)   t+=((int)(m->hours))*3600;
                     if (m->minutes) t+=((int)(m->minutes))*60;
                     if (m->seconds) t+=((int)(m->seconds));
                     if (m->days)    t+=((int)(m->days))*(24*3600);
                     if (m->weeks)   t+=((int)(m->weeks))*(24*3600*7);
                     if (m->months)  t+=((int)(m->months))*(24*3600*30+37800); /* 30.46d */
                     if (m->years)   t+=((int)(m->years))*(3600*(24*365+6));   /* 365.25d */
                 }

                 if(t) cookies += "; expires="+Caudium.HTTP.date(t+time());

                 //obs! no check of the parameter's usability
                 cookies += "; path=" +(m->path||"/") + ";";

                 add_header(id, "Set-Cookie", cookies);

                 return;
             }

string generate_sessionid(object id){
 object md5 = Crypto.MD5();
    md5->update((string)(id->remoteaddr));
    md5->update(sprintf("%d", roxen->increase_id()));
    md5->update(sprintf("%d", time(1)));
    string SessionID = Caudium.Crypto.string_to_hex(md5->digest());

return SessionID;
}

mixed return_data(mixed retval, object id){
  if(sizeof(id->misc->ivend->error)>0 && !id->misc->ivend->handled_error)
	retval=handle_error(id);
  if(mappingp(retval)) 
  {
    db->handle(DB);
    return retval;
  }

  if(stringp(retval))
  {
    if(id->conf->type_from_filename(id->realfile || "index.html")
	=="text/html") {
	retval=parse_rxml(retval, id);
    }

 int errno=200;
 if(id->misc->defines && id->misc->defines[" _error"]) errno=id->misc->defines[" _error"];
 if(id->misc->ivend->redirect) errno=302;

 db->handle(DB);

   return
     ([
       "error" : errno,
       "data"  : retval,
       "len"   : strlen( retval ),
       "type"  : id->conf->type_from_filename(id->realfile || "index.html")
      ]);

  }

  else { perror("RETURN return_data: fell through\n"); return retval;}

}

/*

   Start of config functions.

 */

// Read the config data.
int read_conf()
{
  object privs;
  string current_config="";

  string config_file;
                           
  privs=Privs("iVend: Reading Config Files");

  config_file= Stdio.read_file(query("storeroot") + "/config/config.ini");
  if(config_file)
  {
    mapping c=.IniFile.read(config_file);
    config=c;
  }
  else
    config=([]);
  privs=0;
  return 0;
}

mixed load_ivmodule(string name){
  mixed err;
  mixed m;

  if(!modules) modules=([]);
  string filen;
  filen=query("root")+"/src/modules/"+name;

  if(file_stat(filen));                           
  else 
  {     
     filen=QUERY(root) + "/modules/" + name;
                                 
     if(file_stat(filen));
     else return ({"Unable to find module " + name + "."});
                             
  }

  master()->set_inhibit_compile_errors(0);
  err=catch(compile_file(filen));
  if(err) 
  {
    perror(err*"\n");
    return (err);                           
  }
  master()->set_inhibit_compile_errors(1);
  m=((program)compile_file(filen))();
  modules+=([  m->module_name : m  ]);
  mixed o=modules[m->module_name];
  object s=db->handle();
  if(functionp(o->start)) {
    o->start(this, s);
  }
  db->handle(s);
  mixed p;

                             if(functionp(o->register_paths))
                                 p = o->register_paths();
                             if(p)
                                 foreach(indices(p), string np)
                                 register_path_handler(np, p[np]);
                             int need_to_save=0;
                             if(functionp(o->query_preferences)){
                                 array pr=o->query_preferences(config);
                                 foreach(pr, array pref){
                                     if(!config) config=([]);
                                     if(!config[m->module_name])
                                         config[m->module_name]=([]);
                                     if(!config[m->module_name][pref[0]]){
                                         config[m->module_name][pref[0]]= pref[4];
                                         need_to_save=1;
                                     }
                                 }
                                 if(need_to_save) {
                                     object privs=Privs("iVend: Writing Config File " +
                                                        config->general);

.IniFile.write_section(query("storeroot")+"/config/config.ini", m->module_name,
                                                          config[m->module_name]);
                                     privs=0;
                                 }
                             }

                             if(functionp(o->register_admin))
                                 p = o->register_admin();
                             if(p)
                                 foreach(p, mapping np)
                                 register_admin_handler(np);

                             if(functionp(o->query_tag_callers))
                                 library->tag+=o->query_tag_callers();
                             if(functionp(o->query_container_callers))
                                 library->container+=o->query_container_callers();
                             if(functionp(o->query_event_callers))
                                 register_event(config->general, o->query_event_callers());

                             return 0;

                         }


void start_db(){
  mixed err;
  if(!QUERY(db) || !strlen(QUERY(db)))
    return;
werror("Starting Database Connection for " + QUERY(db) + "...\n");
  db=.iVend.db_handler(QUERY(db), 4);
  object s;
  catch(s=db->handle());
  if(!s)
  {
    werror("Unable to start Database handler.\n");
  }
  else {
  if(!catch(s->query("CREATE TABLE orderid ("
    "orderid int(11) NOT NULL)")))
    s->query("INSERT INTO orderid VALUE(1)");

  catch(s->query("CREATE TABLE comments ("
    "orderid varchar(64) DEFAULT '' NOT NULL,"
    "comments blob)"));

if(sizeof(s->list_fields("payment_info","Authorization"))!=1) {
  s->query("alter table payment_info add Authorization char(24)");
  }

  s->query("alter table activity_log change orderid orderid char(64) not null");
  s->query("alter table customer_info change orderid orderid char(64) not null");
  s->query("alter table payment_info change orderid orderid char(64) not null");
  s->query("alter table lineitems change orderid orderid char(64) not null");
  s->query("alter table shipments change orderid orderid char(64) not null");



if(sizeof(s->list_fields("lineitems","taxable"))!=1) {
  //perror("ADDING TAXABLE FIELD TO LINEITEMS\n");
  s->query("alter table lineitems add taxable char(1) default 'Y'");
  }

if(sizeof(s->list_tables("admin_users"))!=1) {
  //perror("adding admin_users table...\n");
	s->query("CREATE TABLE admin_users ("
		"username char(16) not null primary key, "
		"real_name char(24) not null, "
		"email char(48) not null, "
		"password char(16) not null, "
		"level int(2) not null default 9)"
		);
}

if(sizeof(s->list_tables("activity_log"))!=1) {
  //perror("adding activity_log table...\n");
	s->query("CREATE TABLE activity_log ("
		"subsystem char(16) not null, "
		"orderid char(64) not null, "
		"severity int(1) not null, "
		"time_stamp datetime, "
		"message blob,"
		"key key1 (orderid))"
		);
 }

                            }
 if(s)
   db->handle(s);                 
 return;
                      
}

                         void load_modules(){
                             mixed err;
                             if(!config) return;
                             array mtl=({
                                    "checkout.pike", "addins.pike",
					"shipping.pike",
                                    "handleorders.pike", "admin.pike"});
                             if(config->addins)
                                 foreach(indices(config->addins), string miq)
                                 if(config->addins[miq]=="load")
                                     mtl+=({miq});

object s=db->handle();
			if(s->local_settings->pricing_model==COMPLEX_PRICING) {
			       perror("adding complex_pricing to module startup list.\n");
			       mtl+=({"complex_pricing.pike"});
			     }
                             foreach(mtl, string name) { 
perror("iVend: loading " + name + "\n");
                                 err=catch(load_ivmodule(name));
                                 if(err) perror("iVend: The following error occured while loading the module "
                                                    + name + "\n" +  describe_backtrace(err));
                             }

                             foreach(indices(config->general), string n)
                             if(Regexp("._module")->match(n)) {
                                 err=load_ivmodule(config["general"][n]);
                                 if(err) {
                                     perror("iVend: The following error occured while loading the module "
                                            + config["general"][n] + " in configuration " +
                                            config["general"]->name + ".\n\n"
                                            + describe_backtrace(err));
                                     config["general"]->error=err;
                                 }
                             }
  db->handle(s);
  return;
                         }

