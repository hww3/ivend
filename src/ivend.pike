/*
 * ivend.pike: Electronic Commerce for Roxen.
 *
 * Bill Welliver <hww3@riverweb.com>
 *
 */

string cvs_version = "$Id: ivend.pike,v 1.287 2003-11-18 02:14:37 hww3 Exp $";

#include "include/ivend.h"
#include "include/messages.h"
#include <module.h>
#include <stdio.h>
//#include <simulate.h>

// #define ENABLE_ADMIN_BACKDOOR 0

#if __VERSION__ >= 0.6
import ".";
#endif

inherit "roxenlib";
inherit "module";
inherit "wizard";

#if __VERSION__ < 0.6
int read_conf();          // Read the config data.
void load_modules(string c);
void start_db(mapping c);
void add_cookie( object id, mapping m, mapping defines);
void background_session_cleaner();
float convert(float value, object id);
array|int size_of_image(string filename);
void error(mixed error, object id);
mapping configuration_interface(array(string) request, object id);
void handle_sessionid(object id);
mixed getglobalvar(string var);
mixed return_data(mixed retval, object id);
mixed  get_image(string filename, object id);
mixed admin_handler(string filename, object id);
mixed handle_cart(string filename, object id);
mixed additem(object id);
#endif

int loaded;
object c;                       // configuration object
object g;                       // global object
mapping paths=([]);// path registry
mapping admin_handlers=([]);
mapping library=([]);
mapping actions=([]);// action storage
mapping db=([]);// db cache
mapping modules=([]); // module cache
mapping config=([]);
mapping global=([]);
mapping numsessions=([]);
mapping numrequests=([]);
mapping admin_user_cache=([]);

int num;
int save_status=1;              // 1=we've saved 0=need to save.
int db_info_loaded=0;

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

void report_error(string error, string|void orderid, string subsys, object id){
    perror(id->remoteaddr + ": " + id->misc->ivend->sessionid +
           "\n" + " " + error);


    DB->query("INSERT INTO activity_log VALUES('" + 
	DB->quote(subsys) + "','" + DB->quote((string)orderid) + "'," + 
	"1, NOW(),'" +
	DB->quote(error) + "')");  

    return;

}

void report_critical_error(string error, string|void orderid, string
subsys, object id){
    perror("critical_error: " + id->remoteaddr + ": " +
		id->misc->ivend->sessionid +           "\n" + " " + error);

    return;

}

void report_status(string error, string|void orderid, string subsys, object id){

    DB->query("INSERT INTO activity_log VALUES('" + 
	DB->quote(subsys) + "','" + DB->quote((string)orderid) + "'," + 
	"5, NOW(),'" +
	DB->quote(error) + "')");  

    return;

}

void report_warning(string error, string|void orderid, string subsys, object id){

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
//perror("getting tax for orderid: " + orderid + "\n");
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
  report_error("iVend: Unable to find order info for tax calculation!\n",
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
    if(loaded) {
        s += "<br>Go to the <a href='"+
             my_configuration()->query("MyWorldLocation")+ query("mountpoint") +
             "config/'>iVend Configuration Interface</a><p>";
    }


    return( {
              MODULE_LOCATION | MODULE_PARSER,
              "iVend 1.0",
              s+"iVend enables online shopping within Roxen.",
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

    defvar("config_user", "administrator" ,
           "Configuration User",
           TYPE_STRING,  "This is the username to use when accessing the iVend Configuration "
           "interface.");

    defvar("config_password", "" ,
           "Configuration Password",
           TYPE_PASSWORD,
           "The password to use when accessing the iVend Configuration "
           "interface.");

    defvar("lang", "en", "Default Language",
           TYPE_MULTIPLE_STRING, "Default Language for Stores",
           ({"en","si"})
          );
    defvar("wordfile", "/usr/dict/words",
           "Word File",
           TYPE_FILE,
           "This is a file containing words that will be used to generate "
           "config passwords. On Solaris and Linux, this is usually "
           "/usr/dict/words, and on FreeBSD /usr/share/dict/words.");

}

mixed handle_path(string s, string p, object id) {

    string np=((p/"/")-({""}))[0];
    mixed rv;
    rv=paths[s][np](p, id);
    // perror(sprintf("%O\n",rv));
    return rv;
}

int have_path_handler(string s, string p){

    if(!p || p=="")
        return 0;

    p=((p/"/")-({""}))[0];
    if(paths[s][p] && functionp(paths[s][p])) {
        //  perror("have handler for " + p + " in " + s + "\n");
        return 1;
    }
    else return 0;

}

void register_path_handler(string c, string path, function f){

       perror("registering path " + path + " for " + c + "...\n");

    if(functionp(f))
        paths[c][path]=f;
    else perror("no function provided!\n");
    return;
}

mixed throw_fatal_error(mixed error, object id) {  
// we don't do anything with error yet.

  if(!id->misc->ivend->had_fatal_event)
    id->misc->ivend->had_fatal_event=1;
  else id->misc->ivend->had_fatal_event ++;

}

mixed throw_warning(mixed error, object id) {  
// we don't do anything with error yet.

  if(!id->misc->ivend->had_warning_event)
    id->misc->ivend->had_warning_event=1;
  else id->misc->ivend->had_warning_event ++;

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

    if(id && STORE){
        if(library[STORE]->event[event])
            foreach(library[STORE]->event[event], mixed f)
	     if(!had_fatal_error(id))
		if(functionp(f))
		  f(event, id, args);
    }

}

void register_event(mapping config, mapping events){
    if(!library[config->config]->event)
        library[config->config]->event=([]);

    foreach(indices(events), string ename){
        perror("Registering event " + ename + "\n");
        if(!library[config->config]->event[ename])
            library[config->config]->event[ename]=({});
        library[config->config]->event[ename]+=({events[ename]});
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
                   "mixed proc(string tag_name, mapping "
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
                   "mixed proc(string event_name, "
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
                   "mixed proc(string container_name, mapping args,"
                   " string contents, object id){\n";
            footer="\n}";
        }
    }
    perror("Defining Procedure (" +type+"):  " + tname + "\n");
    contents=header+contents+footer;
    mixed err;
master()->set_inhibit_compile_errors(0);
    err=catch(object p=(object)clone(compile_string(contents)));
    if(err)perror(describe_backtrace(err));
    if(type=="event") {
        if(err)
register_event(id->config, ([tname : err ]));
        else
register_event(id->config, ([tname : p->proc ]));
    }
    else {
        if(err)
            library[id->config->config][type][tname]=err;
        else library[id->config->config][type][tname]=p->proc;
    }

    return;

}

void load_library(mapping c){
    mapping id=([]);
    id->config=c;
    array dir;
    dir=get_dir(c->root + "/library/");
    if(!dir) return;
    foreach(dir, string filename) {
        string contents;
        catch(contents=Stdio.read_file(c->root + "/library/" + filename));
        if(contents)
            contents=parse_html(contents, ([]),
                    (["procedure" : container_procedure ]) ,id);
    }
    return;
}

void get_entities(mapping c){
    if(!library[c->config])
        library[c->config]=([]);
    library[c->config]->tag=([]);
    library[c->config]->container=([]);
    library[c->config]->event=([]);

}

mixed register_admin_handler(string c, mapping f){

    if(functionp(f->handler))
        admin_handlers[c][f->mode]=f;
    else perror("no function provided!\n");
    return 0;
}


void start_store(string c){
    perror("Starting store " + c + "...\n");

    if(!paths[c]) paths[c]=([]);
    if(!admin_handlers[c]) admin_handlers[c]=([]);
    register_path_handler(c, "images", get_image);
    register_path_handler(c, "admin", admin_handler);
    register_path_handler(c, "cart", handle_cart);



    // perror(config[c]->general->config +"\n\n");
    if(!config[c]->general)
	return;
    start_db(config[c]->general);

    get_entities(config[c]->general);
    catch(load_modules(config[c]->general->config));

    numsessions[config[c]->general->config]=0;
    numrequests[config[c]->general->config]=0;

    load_library(config[c]->general);

}


void stop_store(string c){
    if(modules[c])
        foreach(indices(modules[c]), string m) {
        if(modules[c][m]->stop && functionp(modules[c][m]->stop))
            modules[c][m]->stop();
        if(modules[c][m])
            destruct(modules[c][m]);

    }
    if(db[c])
        destruct(db[c]);
}

void stop(){

    foreach(indices(config), string c)
    stop_store(c);

    paths=([]);// path registry
    admin_handlers=([]);
    library=([]);
    actions=([]);// action storage
    db=([]);// db cache
    modules=([]); // module cache
    config=([]);
    global=([]);
    numsessions=([]);
    numrequests=([]);

}

int write_config_section(string store, string section, mapping attributes){
    mixed rv;
    object privs=Privs("iVend: Writing Config File " + store);
    rv=Config.write_section(query("configdir") + store, section,
                            attributes);
#if efun(chmod)
    chmod(query("configdir") + store, 0640);
#endif
    privs=0;
    return rv;
}

void start(){

    num=0;
    add_include_path(getmwd() + "src/include");
    add_module_path(getmwd()+"src");
    loaded=1;
    if(catch(query("datadir"))) return;

    if(file_stat(query("datadir")+"ivend.cfd")==0)
        return;
    else {
        read_conf();   // Read the config data.
    }

    foreach(indices(config), string c) {
        start_store(c);
    }

    call_out(background_session_cleaner, 900);

    return 0;

}


string|void check_variable(string variable, mixed set_to){

    return 0;

}

string status(){

    return ("Everything's A-OK!\n");

}

string query_name()

{
    return sprintf("iVend 1.0  mounted on <i>%s</i>", query("mountpoint"));
}



void|string container_ia(string name, mapping args,
                         string contents, object id) {
    if (catch(id->misc->ivend->SESSIONID)) return;

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
	arguments["href"]=( args->href ||("./"+id->misc->ivend->page+".html")) +
			"?SESSIONID="
           		+id->misc->ivend->SESSIONID+"&ADDITEM=1&"
                          +id->misc->ivend->item+"=ADDITEM";
    else if(args->cart)
        arguments["href"]=query("mountpoint")+
                          (id->misc->ivend->moveup?"": STORE+ "/")
                          +"cart?SESSIONID=" +id->misc->ivend->SESSIONID + "&referer=" +
                          (((id->referer*"") - "ADDITEM=1") ||"");
    else if(args->checkout)

arguments["href"]=((id->misc->ivend->config["Checkout"]->checkouturl) || (query("mountpoint")+
                          (id->misc->ivend->moveup?"": STORE + "/")
                          +"checkout/")) +"?SESSIONID="+id->misc->ivend->SESSIONID;
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
    contents="<!-- form container --><input type=hidden name=SESSIONID value="+
             id->misc->ivend->SESSIONID+">"+contents;
    args["_parsed"]="1";
    return make_container("FORM", args, contents);


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
//            perror("triggering an event, cp." + row->type + " for " +
// i->item + "\n");
trigger_event("cp." + row->type,id,(["item": i->item, "quantity":
                                                 i->quantity,
"options": i->options]));
        }
        if(!COMPLEX_ADD_ERROR)
trigger_event("additem",id,(["item": i->item, "quantity":
                                         i->quantity]));
//        else perror("An error occurred while adding an item.\n");
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
// perror("options: " + (opt*"\n") + "\n");
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
    int max=sizeof(DB->query("select id FROM sessions WHERE SESSIONID='"+
                             id->misc->ivend->SESSIONID+"' AND id='"+item+"'"));
    string query="INSERT INTO sessions VALUES('"+
                 id->misc->ivend->SESSIONID+
                 "','"+item+"',"+ quantity +","+(max+1)+",'" +
		(args->options||"") + "'," + price +
                 "," + (args->autoadd||0) +"," + (args->lock||0) + 
		 ",'" + is_item_taxable(id, item) + "')";

    if(catch(
DB->query(query)
 )) {
        id->misc["ivendstatus"]+=( ERROR_ADDING_ITEM+" " +item+ ".\n" +
DB->error());
        return 0;
    }
    else { 
//perror("added successfully.\n");
        id->misc["ivendstatus"]+= (string) quantity +" " +
                                  ITEM + " " + item + " " + ADDED_SUCCESSFULLY +"\n";
        return 1;
    }
}


mixed do_additems(object id, array items){

    // we should add complex pricing models to this algorithm.
    if(DB->local_settings->pricing_model==COMPLEX_PRICING) {
        //    perror("DOING COMPLEX PRICE CALCULATIONS...\n");
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


mixed container_icart(string name, mapping args, string contents, object id) {
    string retval="";
    string extrafields="";
    array ef=({});
    array en=({});
    int madechange=0;
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


    foreach(indices(id->variables), string v) {
        if(id->variables[v]==DELETE) {
            string p=(v/"/")[0];
            string s=(v/"/")[1];
            catch(DB->query("DELETE FROM sessions WHERE SESSIONID='"
                      +id->misc->ivend->SESSIONID+
                      "' AND id='"+ p +"' AND series=" +s ));
            madechange=1;
trigger_event("deleteitem", id, (["item" : p , "series" : s]) );
        }
    }



    if(id->variables->update) {
        for(int i=0; i< (int)id->variables->s; i++){
            if((int)id->variables["q"+(string)i]==0) {
/*
		array mr=DB->query("SELECT autoadd, locked FROM sessions "
			"WHERE SESSIONID='" + id->misc->ivend->SESSIONID + 
			"' AND id='" + id->variables["p" + (string)i] + "'"
			" AND series=" + id->variables["s" + (string)i]);
		if(mr[0]->locked==0) 
*/
                  madechange=1;
                catch(DB->query("DELETE FROM sessions WHERE SESSIONID='"
                          +id->misc->ivend->SESSIONID+
                          "' AND id='"+id->variables["p"+(string)i]+"' AND series="+
                          id->variables["s"+(string)i] ));
trigger_event("deleteitem", id, (["item" : id->variables["p" + (string)i] , "series" : id->variables["s" + (string)i]]) );
            } else {
                madechange=1;

                catch(DB->query("UPDATE sessions SET "
                          "quantity="+(int)(id->variables["q"+(string)i])+
                          " WHERE SESSIONID='"+id->misc->ivend->SESSIONID+"' AND id='"+
                          id->variables["p"+(string)i]+ "' AND series="+
			id->variables["s"+(string)i] ));
trigger_event("updateitem", id, (["item" : id->variables["p" +
                                  (string)i] , "series" : id->variables["s" + (string)i],
                                  "quantity": id->variables["p" + (string)i]]) );
            }
        }
    }
// madechange=0;
    if(madechange==1){
        array r;
	catch(r=DB->query("SELECT id, price, quantity, series, options, autoadd, locked "
                          " FROM sessions WHERE sessionid='" +
			id->misc->ivend->SESSIONID + "'"));

        if(r && sizeof(r)>0) {
            array items=({});
            catch(DB->query("DELETE FROM sessions WHERE sessionid='" +
                      id->misc->ivend->SESSIONID + "'"));
            foreach(r, mapping row) {
                if(((int)(row->locked))==1 || ((int)(row->autoadd)==1))
		 continue;
items+=({ (["item": row->id, "quantity": row->quantity, "options":
            row->options, "series": row->series, "locked": row->locked,
"autoadd": row->autoadd ]) });
            }
            do_additems(id, items);
        }
    }
    string field;

    retval+="<form action=\""+id->not_query+"\" method=post>\n<table>\n"
            "<input type=hidden name=referer value=\"" +
            id->variables->referer + "\">\n";
    // if(!args->fields) return "Incomplete cart configuration!";
array r;
    if(catch(r= DB->query(
                                "SELECT sessions.id" +
                                ",series,quantity,sessions.price, "
				"sessions.locked, sessions.autoadd, " 
				"sessions.options " +
                                extrafields+" FROM sessions,products "
                                "WHERE sessions.SESSIONID='"
                                +id->misc->ivend->SESSIONID+"' AND sessions."
                                "id=products." +
                                DB->keys->products
                            )))
        return "An error occurred while accessing your cart."
               "<!-- Error follows:\n\n" + DB->error() + "\n\n-->";
    if (sizeof(r)==0) {
        if(id->misc->ivend->error)
            return YOUR_CART_IS_EMPTY +"\n<false>\n";
    }

retval+="<cartdata>";
array elements=({});
    foreach(en, field){
        elements+=({"<cartheader>"+field+"</cartheader>"});
    }
    elements+=({"<cartheader>" + WORD_OPTIONS
+ "</cartheader>"});
elements+=({
	"<cartheader>"
            + PRICE +"</cartheader>"});
elements+=({"<cartheader>"
            + QUANTITY +"</cartheader>"});
elements+=({"<cartheader>"
            + TOTAL + "</cartheader>"});
elements+=({"<cartheader></cartheader>"});
retval+="<cartrow>" + elements*"\t";
retval+="</cartrow>\n";
    for (int i=0; i< sizeof(r); i++){
	elements=({});
     for (int j=0; j<sizeof(en); j++)
       if(j==0) elements+=({"<cartcell align=left><INPUT TYPE=HIDDEN NAME=s"
		+ i + " VALUE="+r[i]->series+">"
                "<INPUT TYPE=HIDDEN NAME=p"+i+" VALUE="+r[i]->id+
                "><A HREF=\""+ id->misc->ivend->storeurl  +
                r[i]->id + ".html\">"
                +r[i][en[j]]+"</A></cartcell>"});

       else elements+=({"<cartcell align=left>"+(r[i][en[j]] || " N/A ")
	+"</cartcell>"});

string e="<cartcell align=left>";
array o=r[i]->options/"\n";

  array eq=({});
foreach(o, string opt){
  array o_=opt/":";
catch(  eq+=({DB->query("SELECT description FROM item_options WHERE "
   "product_id='" + r[i]->id + "' AND option_type='" +
   o_[0] + "' AND option_code='" + o_[1] + "'")[0]->description}));
}
	e+=(eq*"<br>") + "</cartcell>";
elements+=({e});
elements+=({"<cartcell align=right>" + MONETARY_UNIT +
                sprintf("%.2f",(float)r[i]->price)+"</cartcell>"});

elements+=({"<cartcell><INPUT TYPE="+
		(r[i]->locked=="1"?"HIDDEN":"TEXT") +
		" SIZE=3 NAME=q"+i+" VALUE="+
                r[i]->quantity+">" + (r[i]->locked=="1"?r[i]->quantity:"")
		+ "</cartcell>"});
elements+=({"<cartcell align=right>" + MONETARY_UNIT
		+sprintf("%.2f",(float)r[i]->quantity*(float)r[i]->price)+"</cartcell>"});

e="<cartcell align=left>";
if(r[i]->autoadd!="1")
  e+="<input type=submit value=\"" + DELETE + "\" NAME=\"" +
   r[i]->id + "/" + r[i]->series + "\">";
e+="</cartcell>";
elements+=({e});
retval+="<cartrow>" + elements*"\t";
retval+="</cartrow>\n";
    }
    retval+="</cartdata>\n<input type=hidden name=s value="+sizeof(r)+">\n"
            "<table><tr><Td><input name=update type=submit value=\""
            + UPDATE_CART + "\"></form></td>\n";
    if(!id->misc->ivend->checkout){
        if(args->checkout_url)
            retval+="<td><form action=\"" + args->checkout_url + "\">";
        else
            retval+="<td> <form action=\""+ query("mountpoint") +
                    (  (sizeof(config)==1 && getglobalvar("move_onestore")=="Yes")
                       ?"": STORE+"/")+"checkout/?SESSIONID=" +
                    id->misc->ivend->SESSIONID
                    + "\">";
        retval+="<input name=update type=submit value=\"" + CHECK_OUT + "\"></form></td>";
    }
    if(!id->misc->ivend->checkout &&
(args->cont||id->variables->referer)){
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
        retval+=make_tag("listitems", args);
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
        else filename=CONFIG->root+"/html/images/"+
                          id->misc->ivend->type+"s/"+r[0][args->field];
    }
    else if(args->src!="")
        filename=CONFIG->root+"/html/images/"+args->src;

    array|int size=size_of_image(filename);


    // file doesn't exist
    if(size==-1)
        return "<!-- couldn't find the image: "+filename+"... -->";

    args->src=query("mountpoint") +
              (  (sizeof(config)==1 && getglobalvar("move_onestore")=="Yes")
                 ?"": STORE+"/")+"images/"
              +id->misc->ivend->type+"s/"+r[0][args->field];
    if(arrayp(size)){
        args->height=(string)size[1];
        args->width=(string)size[0];
    }

    return make_tag("img", args);


}

string container_ivindex(string name, mapping args,
                         string contents, object id)
{
    string retval="";
    array(string)a=indices(config);
    string c;
    foreach(a,c){
        string s="";
        string d="";
//        retval+=do_output_tag( args, r||({}), contents, id );
        s+=do_output_tag(args, ({(config[c]->general + (["id":c]))}),
		contents, id);
//        s=replace(s,"#id#",c);
        retval=s;
    }
    return retval;

}


mixed handle_cart(string filename, object id){
#ifdef MODULE_DEBUG
    perror("iVend: handling cart for "+ id->misc->ivend->st+"\n");
#endif

    string retval;
    if(!(retval=Stdio.read_bytes(CONFIG->root+"/html/cart.html")))
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
    retval=parse_html(do_output_tag( args, ({ r[0] }), contents, id ),
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

#ifdef MODULE_DEBUG
    perror("iVend: finding page "+ page+" in "+ id->misc->ivend->st +"\n");
#endif

    string retval;

    page=(page/".")[0];// get to the core of the matter.
    id->misc->ivend->item=page;
//    string template;
array(mapping(string:string)) r;
    array f;
    string type=get_type(page, id);
    id->misc->ivend->type=type;
    id->misc->ivend->page=page;
    if(!type)
        return 0;
// id->misc->ivend->template="";
    if(id->variables->template)
id->misc->ivend->template=id->variables->template;
   else if(id->misc->ivend->template=="DEFAULT" ||
		id->misc->ivend->template==0)
	id->misc->ivend->template=CONFIG->root+ "/html/" +
type+"_template.html";
    else id->misc->ivend->template=CONFIG->root + "/templates/" +
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
    if(result)
        foreach(items, mapping item) {
   trigger_event("preadditem", id, (["item": item->item, "quantity":
	item->quantity]));
   trigger_event("additem",id,(["item": item->item, "quantity":
                                     item->quantity]));
   trigger_event("postadditem",id,(["item": item->item, "quantity":
                                     item->quantity]));
  }
    return 0;
}

mixed handle_page(string page, object id){
#ifdef MODULE_DEBUG
    perror("iVend: handling page "+ page+ " in "+ STORE +"\n");
#endif


    mixed retval;

    switch(page){

    case "index.html":
        id->realfile=CONFIG->root+"/html/index.html";
        retval= Stdio.read_bytes(CONFIG->root+"/html/index.html");
        break;

    default:

        mixed fs;
        fs=stat_file(page,id);

        if(!fs) {
            id->misc->ivend->page=page-".html";
            return find_page(page,id);
        }
        else if(fs[1]<=0) {
            page="/"+((page/"/") - ({""})) * "/";
            fs=stat_file(page+"/index.html",id);

            if(fs && fs[1]>0) {
                return http_redirect(page + "/index.html", id);
            }
            else return 0;
        }
        id->misc->ivend->page=page-".html";
	string template;
        id->misc->ivend->type=get_type(id->misc->ivend->page, id);

        retval=Stdio.read_file(CONFIG->root + "/html/" + page);
        id->realfile=CONFIG->root+"/html/"+page;
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


string create_index(object id){
    string retval="";
    retval=Stdio.read_bytes(query("datadir")+"index.html");
    return retval;
}

mixed getsessionid(object id) {

    return id->misc->ivend->SESSIONID;

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

// we're login' in to the main config interface.
int get_auth(object id){
    array(string) auth=id->realauth/":";
    if(auth[0]!=query("config_user")) return 0;
    else if(crypt(auth[1], query("config_password")))
        return 1;
    else return 0;

}

int|mixed admin_auth(object id)

{
if(!admin_user_cache[STORE])  // if we don't have it already, make space for our store's cache.
  admin_user_cache[STORE]=([]);
if(id->cookies->admin_user && id->cookies->admin_user!="")
 { 
  if(admin_user_cache[STORE][id->cookies->admin_user] && 

(admin_user_cache[STORE][id->cookies->admin_user]==id->cookies->admin_auth))
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
admin_user_cache[STORE][upper_case(id->variables->user)]="";
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
	"<p>Copyright 1999 Bill Welliver</body></html>";

		}
		id->misc->ivend->admin_user=r[0]->username;
		id->misc->ivend->admin_user_level=r[0]->level;

 object md5 = Crypto.md5();
    md5->update(id->variables->password);
    md5->update(sprintf("%d", roxen->increase_id()));
    md5->update(sprintf("%d", time(1)));
    string SessionID = Crypto.string_to_hex(md5->digest());
    admin_user_cache[STORE][id->misc->ivend->admin_user]=SessionID;
    
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
	"<p>Copyright 1999 Bill Welliver</body></html>";

}



// Start of admin functions


int do_clean_sessions(object db){

    string query="SELECT sessionid FROM session_time WHERE timeout < "+time(0);
    array r;
	catch(r=db->query(query));
    foreach(r,mapping record){
        foreach(({"customer_info","payment_info","lineitems",
		"comments", "orderdata"}),
                string table)
        catch(db->query("DELETE FROM " + table + " WHERE orderid='"
                  + record->sessionid + "'"));

	catch(db->query("DELETE FROM sessions WHERE sessionid='" +
		record->sessionid + "'"));
	catch(db->query("DELETE FROM session_time WHERE sessionid='" +
		record->sessionid + "'"));
    }

    catch(db->query(query));

    return sizeof(r);
}

int clean_sessions(object id){

    int num=do_clean_sessions(DB);
    //   numsessions[STORE]+=num;
    return num;
}

void background_session_cleaner(){

    object d;
    mixed err;

    foreach(indices(config), string st){
        mapping store=config[st]->general;

        err=catch(d=db[st]->handle());
        if(err)
            perror("iVend: BackgroundSessionCleaner failed."
                   + describe_backtrace(err) + "\n");

        else {
            int num=do_clean_sessions(d);
            // if(num)
            //      perror("iVend: BackgroundSessionCleaner cleaned " + num +
            //         " sessions from database " + store->db + ".\n");
            //  numsessions[st]+=num;
        }
        db[st]->handle(d);
    }
    call_out(background_session_cleaner, 900);
}


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
                                         add_pre_state(id->not_query, (<"domodify=product">)),"groups",
                                         "product_groups", id, record[0])+"</table>\n";
    else if(type=="group")

        retval+="<table>\n"+DB->gentable("groups",
                                         add_pre_state(id->not_query,
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
    array i=indices(admin_handlers[STORE]);

    foreach(i, string h){
        int loc= sizeof(h);
        loc-=sizeof(type);
        loc--;
        catch{ if(search(h, type, loc)!=-1)
            type=h;
	};
    }

    if(admin_handlers[STORE][type] &&
                functionp(admin_handlers[STORE][type]->handler)){
	int security_level;
	if(admin_handlers[STORE][type]->security_level)
	  security_level=admin_handlers[STORE][type]->security_level;
	else security_level=0;
	if(my_security_level(id)>=security_level)
        return type;
	}

}

mixed handle_admin_handler(string type, object id){

    mixed rv;
    rv=admin_handlers[STORE][type]->handler(type, id);
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
		name + " ACTION=\"" + add_pre_state(id->not_query, (<mode>))
            +"\">";
    foreach(indices(options), string o){

        retval+="<input type=hidden name=\"" + o + "\" value=\"" + options[o] +
                "\">\n";
    }

    retval+="<input type=hidden name=id value=\"" +
       id->variables[DB->keys[options->type + "s"]] + "\">";
    retval+="<input type=hidden name=mode value=\""  +mode + "\">"
            "<input onclick=\"popup_" + id->misc->ivend->popup + "('"
		+name +"','" + add_pre_state(id->not_query,
                          (<mode>))  + "'," +(options->width||450)+ ","
		+(options->height||300)+
		")\" type=reset value=\""
		+ replace(name,"_"," ") + "\">"
            "</form>";

    return retval;

}



string return_to_admin_menu(object id){

                 return "<a href=\""  + 	   add_pre_state(id->not_query,
                         (<"menu=main">))+   "\">"
                        "Return to Store Administration</a>.\n";

             }

             string action_clearsessions(string mode, object id){

                 string retval="";

                 int r =clean_sessions(id);
                 retval+="<p>"+ r+ " Sessions Cleaned Successfully.<p>" +
                         return_to_admin_menu(id);

                 return retval;
             }

             mixed admin_handler(string filename, object id){
	       // perror("admin interface\n");
if(CONFIG->admin_enabled=="No")
  return 0;

                 string mode, type;
if(id->variables->logout){
   add_cookie(id, (["name":"admin_user",
                 "value":"", "seconds": 1]),([]));
   add_cookie(id, (["name":"admin_auth",
                 "value":"", "seconds": 1]),([]));
   admin_user_cache[STORE][id->cookies->admin_user]="";
return "You have logged out.<p><a href=\"./\">Click here to continue.</a>";
}
                 if(sizeof(id->prestate)==0) {
                     id->prestate=(<"menu=main">);
                     return http_redirect(id->not_query + (
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
                         + CONFIG->name+
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
                         add_pre_state(id->not_query,(<"menu=main">))+"\">Admin Main Menu</a>\n";


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

                 foreach(indices(admin_handlers[STORE]), string h)
                 if(search(h, mode + (type?"."+type:""))!=-1){
                     string m=h-(mode + (type?"."+type:""));
                     if((m+(mode + (type?"."+type:"")))!=h)
                         valid_handlers+=({h});
		foreach(valid_handlers, string vh)
			if(admin_handlers[STORE][vh]->security_level
>my_security_level(id)) valid_handlers-=({vh});
                 }
                 switch(mode){

                 case "doadd":
                     mixed xj=DB->addentry(id,id->referrer);
                     retval+="<br>";
                     if(!intp(xj)){
		       //                         destruct(DB);
                         return retval+= "<p>The following errors occurred:<p><ul><li>" + (xj*"<li>")
				+"</ul><p>"
	"Please return to the previous page to remedy this  "
"situation before continuing.</body></html>";
                     }
                     else{
                         type=(id->variables->table-"s");
			 //                         destruct(DB);
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
		       //                         destruct(DB);
                         return retval+= "The following errors occurred:<p><li>" + (xj*"<li>")
				+"</body></html>";
                     }
//                     destruct(DB);
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
                                                           add_pre_state(id->not_query,(<"doadd=product">)),"groups",
                                                           "product_groups", id)+"</table>\n";
                     else if(type=="group")
                         retval+="<table>\n"+
                                 DB->gentable("groups",add_pre_state(id->not_query,(<"doadd=group">)),0,0,id)+"</table>\n";
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
					add_pre_state(id->not_query,(<"dodelete=" + type>)) +"\">\n"
                                         + n +
                                         "<input type=hidden name=mode value=dodelete>\n"
                                         "<input type=submit value=Delete>\n</form>";
                             else retval+="<br>No " + capitalize(type +"s") + " found.";
                         }
                         else {
                                 retval+="<form name=form action=\"" +
                                         add_pre_state(id->not_query,(<"dodelete=" + type>))
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
                             add_pre_state(id->not_query,(<"dodelete=" + type>))+"\">\n"
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
                     start_store(STORE);
                     retval+="Store Restarted Successfully.<p>" +
                             return_to_admin_menu(id);
                     break;
                 case "clearsessions":
                     int r =clean_sessions(id);
                     retval+="<p>"+ r+ " Sessions Cleaned Successfully.<p>" +
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
add_pre_state(id->not_query,(<"dodelete=" + type >))  
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
                                         "<a href=\"" + add_pre_state(id->not_query,
                                                                      (<"getmodify=" + type>))+
                                         "?" +id->variables->primary_key + "=" +
                                         row[id->variables->primary_key] + "\">Modify</a> "
                                         "&nbsp; <a href=\"" +
                                         add_pre_state(id->not_query, (<"dodelete="+ type>)) +
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
                     retval+="<form name=form action=\""+add_pre_state(id->not_query,(<"getmodify=" + type>))+"\">\n"
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
			  //			  destruct(DB);
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
                             add_pre_state(id->not_query,(<"show=group">))
                             +"\">Show Groups</a>\n"
                             "<li><a href=\""+
                             add_pre_state(id->not_query,(<"add=group">))
                             +"\">Add New Group</a>\n"
                             "<li><a href=\""+
                             add_pre_state(id->not_query,(<"modify=group">))
                             +"\">Modify a Group</a>\n"
                             "<li><a href=\""+
                             add_pre_state(id->not_query,(<"delete=group">))
                             +"\">Delete a Group</a>\n"
                             "</font>"
                             "</obox>"
                             "<obox title=\"<font face=helvetica,arial>Products</font>\">\n"
                             "<font face=helvetica,arial>"
                             "<ul>"
                             "<li><a href=\""+
                             add_pre_state(id->not_query,(<"show=product">))
                             +"\">Show Products</a>\n"
                             "<li><a href=\""+
                             add_pre_state(id->not_query,(<"add=product">))
                             +"\">Add New Product</a>\n"
                             "<li><a href=\""+
                             add_pre_state(id->not_query,(<"modify=product">))
                             +"\">Modify a Product</a>\n"
                             "<li><a href=\""+
                             add_pre_state(id->not_query,(<"delete=product">))
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
                                 retval+="<li><a href=\"" + add_pre_state(id->not_query,
					(<replace(hn, mode+"."+(type||"")+".","")>)) + "\">"
                                         + replace(hn,({"_",mode + "." + (type||"") +"." +category
                                                        +"."}),({" ",""})) +
                                         "</a>\n";
                             retval+="</ul></font></obox>";
                         }

                         retval+="</td></tr></table>"
                                 "</ul><p><b>" + numsessions[STORE] + "</b> sessions created since last startup."
                                 "<br><b>" + numrequests[STORE] + "</b> requests handled since last startup."
				"<p>Logged in as " +
				id->misc->ivend->admin_user + ". [ <a "
"href=\"./?logout=1\">Logout</a> ] [ <a "
"href=\"./?change_password=1\">Change Password</a> ]";

                     }
                     else retval+="Sorry, couldn't find handler.";
                     break;

                 }
//		                  destruct(DB);
                 return retval;

             }



             mixed find_file(string file_name, object id){
// perror("REQUEST find_file: " + file_name + "\n");
                 id->misc["ivend"]=([]);
                 id->misc["ivendstatus"]="";
                 mixed retval;
                 id->misc->ivend->error=({});
                 id->misc->ivend->this_object=this_object();
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

                     break;

                 }


                 if(sizeof(config)==1 && getglobalvar("move_onestore")=="Yes") {
                     STORE=indices(config)[0];
                     id->misc->ivend->moveup=1;
                 }
                 else if(sizeof(request)==0 || (sizeof(request)>=1 && !config[request[0]]))

                 {
                     if(getglobalvar("create_index")=="Yes")
                         retval=create_index(id);
                     else  retval="you must enter through a store!\n";
                 }
                 else {
                     STORE=request[0];
                     request=request[1..];
                 }

                 if(retval) return return_data(retval, id);
                 else if(!config[STORE]) {
                     return return_data("NO SUCH STORE!", id);
                 }
                 else if(catch(request[0])) {
                     request+=({""});

                 }
                 // load id->misc->ivend with the good stuff...
                 id->misc->ivend->config=config[STORE];
                 id->misc->ivend->config->global=global;
                 mixed err;
                 if(!DB) {


if(STORE) 
                     DB=db[STORE]->handle();
//perror(sprintf("%O", mkmapping(indices(db), values(db))) + "\n");
			}
                 if(err || config[STORE]->error) {
                     error(err[0] || config[STORE]->error, id);
                     return return_data(retval, id);
                 }

                 if(!DB || !DB->db_info_loaded) {
		   return return_data("This store is currently unavailable.", id);
			}
                 MODULES=modules[STORE];
                 numrequests[STORE]+=1;
                 id->misc->ivend->storeurl=query("mountpoint")+
                                           (id->misc->ivend->moveup?"": STORE+ "/");


                 handle_sessionid(id);
                 if(request*"/" && have_path_handler(STORE, request*"/"))
                     retval= handle_path(STORE, request*"/" , id);

                 if(!retval)
                     switch(request[0]) {
                     case "":
		       string rx=replace((id->not_query + "/index.html" +
					  (id->query?("?"+id->query):"")),"//","/");
		       perror("redirecting to: " + rx + "\n");
		       db[STORE]->handle(DB);
		       return http_redirect(rx, id);
                     default:
                         retval=(handle_page(request*"/", id));

                     }
                 return return_data(retval, id);

             }

             mixed generic_tag_handler(string name, mapping args,
                                       object id, mapping defines){
                 string retval="";
                 mixed err;
                 if(functionp(library[STORE]->tag[name]))
                     err=catch(retval=library[STORE]->tag[name](name, args, id, defines));
                 else err=library[STORE]->tag[name];

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
                 if(functionp(library[STORE]->container[name]))
                     err=catch(retval=library[STORE]->container[name](name, args, contents, id));
                 else err=library[STORE]->container[name];
                 if(err)
                     return "an error occurred while processing tag " + name + ":<br>"
                            + describe_backtrace(err)
                            ;

                 return retval;

             }

             string|void container_ivml(string name, mapping args,
                                        string contents, object id)
             {
// perror("ivml!\n");

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
                                      "form":container_form,
                                      "icart":container_icart,
                                      "ivindex":container_ivindex,
                                      "category_output":container_category_output,
                                      "itemoutput":container_itemoutput
                                      ]);
                 mapping c=([]);
                 mapping t=([]);
if(STORE){

                 foreach(indices(
                             library[STORE]->tag), string n)
                 t[n]=generic_tag_handler;

                 foreach(indices(
                             library[STORE]->container), string n)
                 c[n]=generic_container_handler;
}

// perror("CONTAINERS: " + sprintf("%O\n", (c+containers)));
// perror("TAGS: " + sprintf("%O\n", (t+tags)));

                 contents= make_container("html", (["_parsed":"1"]),
				parse_html(contents,
                           t + tags,
                           c + containers, id));
// mapping defines=id->misc->defines;
// perror("DEFINES container_ivml 1: " + sprintf("%O\n", defines));
if(STORE)
                 MODULES=modules[STORE];
                 contents=parse_rxml(contents,id);
// perror("DEFINES container_ivml 2: " + sprintf("%O\n", id->misc->defines));
                 return contents;

             }

             mapping query_container_callers()
             {
             return ([ "ivml": container_ivml, "html": container_ivml ]); }

             mapping query_tag_callers()
             {
             return ([ "ivendlogo" : tag_ivendlogo, 
                       "sessionid" : tag_sessionid
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
                 return Dims.dims()->get(fop);

             }


             mixed stat_file( mixed f, mixed id )  {


                 if(catch(CONFIG) || !CONFIG)
                     return ({ 33204,0,time(),time(),time(),0,0 });

                 if(f=="." || f=="..")
                     f="/";

                 array fs;
                 if(!id->pragma["no-cache"] &&
                             (fs=cache_lookup("stat_cache", CONFIG->root+"/html/"
                                              +f)))
                     return fs[0];

                 object privs;



                 fs = file_stat(
                          CONFIG->root + "/html/" + f);

#ifndef THREADS
                 privs = 0;
#endif

                 cache_set("stat_cache", CONFIG->root+"/html/" +f, ({fs}));
                 return fs;

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
                 if(STORE && CONFIG)
                     retval=Stdio.read_file(
                                CONFIG->root+"/html/error.html");


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
                                 CONFIG->root+"/html/"+filename);
                 id->realfile=CONFIG->root+"/html/"+filename;

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
                     cookies = m->name+"="+http_encode_cookie(m->value||"");
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

                 if(t) cookies += "; expires="+http_date(t+time());

                 //obs! no check of the parameter's usability
                 cookies += "; path=" +(m->path||"/");

                 add_header(id, "Set-Cookie", cookies);

                 return;
             }

string generate_sessionid(object id){
 object md5 = Crypto.md5();
    md5->update((string)(id->remoteaddr));
    md5->update(sprintf("%d", roxen->increase_id()));
    md5->update(sprintf("%d", time(1)));
    string SessionID = Crypto.string_to_hex(md5->digest());

return SessionID;
}

             void handle_sessionid(object id) {

                 if(!id->cookies->SESSIONID && !id->variables->SESSIONID) {
                     id->misc->ivend->SESSIONID=
                         generate_sessionid(id);
                     num+=1;
                     numsessions[STORE]+=1;
             trigger_event("newsessionid", id, (["sessionid" :
                                                         id->misc->ivend->SESSIONID]) );

			DB->query("INSERT INTO session_time VALUES('" +
		id->misc->ivend->SESSIONID + "',"  +(time(0)+
                         (int)CONFIG->session_timeout)+ ")");
		
                 }

                 else if(id->variables->SESSIONID)
id->misc->ivend->SESSIONID=id->variables->SESSIONID;

                 else 
if(id->cookies->SESSIONID)
                     id->misc->ivend->SESSIONID=id->cookies->SESSIONID;

                 //   if(id->supports->cookies)
                 if(!id->cookies->SESSIONID)
             add_cookie(id, (["name":"SESSIONID",
                              "value":id->misc->ivend->SESSIONID, "seconds": 3600]),([]));

                 m_delete(id->variables,"SESSIONID");

             }

mixed return_data(mixed retval, object id){
// perror("DEFINES return_data start: " + sprintf("%O\n", id->misc->defines));
	if(sizeof(id->misc->ivend->error)>0 && !id->misc->ivend->handled_error)
		retval=handle_error(id);
	if(objectp(DB)) {
		db[STORE]->handle(DB);
		}
	if(mappingp(retval)) {
//		perror("RETURN return_data: got mapping.\n");
		return retval;
	}

	if(stringp(retval)){
		if(id->conf->type_from_filename(id->realfile || "index.html")
			=="text/html") {
// perror("DEFINES return_data preparse: " + sprintf("%O\n", id->misc->defines));
// perror("PARSE return_data: parsing rxml\n");
			retval=parse_rxml(retval, id);
// perror("PARSE return_data: done\n");
}
// perror("DEFINES return_data end: " + sprintf("%O\n", id->misc->defines));
// perror("RETURN return_data: returning a custom answer.\n");

int errno=200;
if(id->misc->defines && id->misc->defines[" _error"]) errno=id->misc->defines[" _error"];
if(id->misc->ivend->redirect) errno=302;
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


                         // Start of config functions.



                         mixed getglobalvar(string var){

                             if(catch(global["general"][var]))
                                 return 0;
                             else return global["general"][var];

                         }

                         int read_conf(){          // Read the config data.
                             object privs;
                             string current_config="";

                             c=iVend.config();
                             g=iVend.config();
                             if(!c->load_config_defs(Stdio.read_file(query("datadir")+"ivend.cfd")));
                             if(!g->load_config_defs(Stdio.read_file(query("datadir")+"global.cfd")));
                             string config_file;
                             privs=Privs("iVend: Reading Config File " +
                                         config_file);
                             config_file=Stdio.read_file(query("configdir") + "global");
                             global=Config.read(config_file);
                             privs=0;
                             if(!global->configurations)
                                 return 0;

                             array configfiles=global->configurations->active;
                             if(!configfiles || sizeof(configfiles)<1) return 0;

                             if(stringp(configfiles)) configfiles=({configfiles});
                             if(!global->general)
                                 global["general"]=([]);
                             global->general->root=query("root");

                             privs=Privs("iVend: Reading Config Files");

                             foreach(configfiles, string confname) {
                                 config_file= Stdio.read_file(query("configdir") + confname);
                                 mapping c;
                                 c=Config.read(config_file);
                                 if(c)
                                     config[confname]=c;
                                 config[confname]["global"]=global;
                             }
                             privs=0;
                             return 0;
                         }


                         mixed load_ivmodule(string c, string name){
                             perror("loading module " + name + " for store " + c + ".\n");
                             mixed err;
                             mixed m;

                             if(!modules[c]) modules[c]=([]);
                             string filen;
                             filen=query("root")+"/src/modules/"+name;
                             if(file_stat(filen));
                             else {
                                 filen=config[c]->general->root + "/modules/" + name;
                                 if(file_stat(filen));
                                 else return ({"Unable to find module " + name + "."});
                             }
				master()->set_inhibit_compile_errors(0);
				err=catch(compile_file(filen));
                             if(err) {
				perror(err*"\n");
                                 return (err);
                             }
				master()->set_inhibit_compile_errors(1);
                              m=(object)clone(compile_file(filen));
                         modules[c]+=([  m->module_name : m  ]);
                             mixed o=modules[c][m->module_name];
                             if(functionp(o->start)) {
                                 o->start(config[c]);
                             }
                             mixed p;

                             if(functionp(o->register_paths))
                                 p = o->register_paths();
                             if(p)
                                 foreach(indices(p), string np)
                                 register_path_handler(c, np, p[np]);
                             int need_to_save=0;
                             if(functionp(o->query_preferences)){
                                 array pr=o->query_preferences(config[c]);
                                 foreach(pr, array pref){
                                     if(!config[c]) config[c]=([]);
                                     if(!config[c][m->module_name])
                                         config[c][m->module_name]=([]);
                                     if(!config[c][m->module_name][pref[0]]){
                                         config[c][m->module_name][pref[0]]= pref[4];
                                         need_to_save=1;
                                     }
                                 }
                                 if(need_to_save) {
                                     object privs=Privs("iVend: Writing Config File " +
                                                        config[c]->general->config);

Config.write_section(query("configdir")+
                                                          config[c]->general->config, m->module_name,
                                                          config[c][m->module_name]);
                                     privs=0;
                                 }
                             }

                             if(functionp(o->register_admin))
                                 p = o->register_admin();
                             if(p)
                                 foreach(p, mapping np)
                                 register_admin_handler(c, np);

                             if(functionp(o->query_tag_callers))
                                 library[c]->tag+=o->query_tag_callers();
                             if(functionp(o->query_container_callers))
                                 library[c]->container+=o->query_container_callers();
                             if(functionp(o->query_event_callers))
                                 register_event(config[c]->general, o->query_event_callers());

                             return 0;

                         }


void start_db(mapping c){
  mixed err;
  perror("Creating DB connections for: " + c->config + "\n");
  db[c->config]=iVend.db_handler(c->dbhost, 4 );
  object s=db[c->config]->handle();
  if(s) {


if(sizeof(s->list_tables("comments"))!=1) {
  s->query("CREATE TABLE comments ("
    "orderid varchar(64) DEFAULT '' NOT NULL,"
    "comments blob)");
}

if(sizeof(s->list_fields("payment_info","Authorization"))!=1) {
  s->query("alter table payment_info add Authorization char(24)");
  }

  s->query("alter table sessions change sessionid sessionid char(64)");
  s->query("alter table activity_log change orderid orderid char(64) not null");
  s->query("alter table customer_info change orderid orderid char(64) not null");
  s->query("alter table payment_info change orderid orderid char(64) not null");
  s->query("alter table lineitems change orderid orderid char(64) not null");
  s->query("alter table session_time change sessionid sessionid char(64)");
  s->query("alter table shipments change orderid orderid char(64) not null");


if(sizeof(s->list_fields("sessions","autoadd"))!=1)
  s->query("alter table sessions add autoadd integer");


if(sizeof(s->list_fields("sessions","taxable"))!=1)
  s->query("alter table sessions add taxable char(1) default 'Y'");

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
if(s) db[c->config]->handle(s);

                             return;

                         }


                         void load_modules(string c){


                             mixed err;
                             if(!c) return;
                             if(!config[c]) return;
                             array mtl=({
                                    "checkout.pike", "addins.pike",
					"shipping.pike",
                                    "handleorders.pike", "admin.pike"});
                             if(config[c]->addins)
                                 foreach(indices(config[c]->addins), string miq)
                                 if(config[c]->addins[miq]=="load")
                                     mtl+=({miq});

 perror("1 Found " + sizeof(mtl) + " modules to load.\n");
object s=db[c]->handle();
//perror("got db.\n");
			if(s->local_settings->pricing_model==COMPLEX_PRICING) {
			       perror("adding complex_pricing to module startup list.\n");
			       mtl+=({"complex_pricing.pike"});
			     }
 perror("2 Found " + sizeof(mtl) + " modules to load.\n");
db[c]->handle(s);
                             foreach(mtl, string name) { 
perror("3 loading " + name + "\n");
                                 err=catch(load_ivmodule(c,name));
                                 if(err) perror("iVend: The following error occured while loading the module "
                                                    + name + "\n" +  describe_backtrace(err));
                             }

                             foreach(indices(config[c]->general), string n)
                             if(Regexp("._module")->match(n)) {
                                 err=load_ivmodule(c, config[c]["general"][n]);
                                 if(err) {
                                     perror("iVend: The following error occured while loading the module "
                                            + config[c]["general"][n] + " in configuration " +
                                            config[c]["general"]->name + ".\n\n"
                                            + describe_backtrace(err));
                                     config[c]["general"]->error=err;
                                 }
                             }
                             return;
                         }

                         mapping write_configuration(object id){
                             string config_file="";
                             array active=({});
				if(!global->configurations->active)

global->configurations->active=({});
                             if(global->configurations && global->configurations->active)
                                 if(!arrayp(global->configurations->active))
                                     active=({global->configurations->active});
                                 else active=global->configurations->active;
				active-=({0});
                             object privs=Privs("iVend: Writing Config Files");

                             foreach(({"global"}) + active, string confname){
                                 perror("making backup of " + confname +"...\n");
                                 mv(query("configdir")+ confname ,query("configdir")+ confname+"~");
                                 if(confname=="global")
                                     Stdio.write_file(query("configdir")+"global",
					Config.write(global));
                                 else {
                                     if(config[confname] && config[confname]->global)
                                         m_delete(config[confname], "global");
                                     Stdio.write_file(query("configdir")+confname,

Config.write(config[confname]));

                                 }
#if efun(chmod)
                                 chmod(query("configdir") + confname, 0640);
#endif

                             }
                             privs=0;
                             save_status=1;// We've saved.

                             stop();
                             start();// Reload all of the modules and crap.
                             return http_redirect(query("mountpoint") + "config/", id);


                         }

                         mapping configuration_interface(array(string) request, object id){
//perror("Started into config_interface!\n");
                             if(id->auth==0)
                                 return http_auth_required("iVend Configuration",
                                                           "Silly user, you need to login!", id);

                             else if(!get_auth(id))
                                 return http_auth_required("iVend Configuration",
                                                           "Silly user, you need to login!" ,id);
//perror("Passed Auth!\n");

                             if(!c) read_conf();
                             // perror(sprintf("%O\n" , global));
                             string retval="";
if(catch(request[0]))
return http_redirect(my_configuration()->query("MyWorldLocation")+
query("mountpoint") + "config/configs/", id);
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

                                     if(global->configurations && global->configurations->active
                                                 && arrayp(global->configurations->active))

                                         global->configurations->active=Array.uniq(global->configurations->active);
	if(arrayp(global->configurations->active) 
	  && sizeof(global->configurations->active)>0)
		global->configurations->active-=({0});
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

                                             if(!global) global=([]);
                                             if(!global->general) global->general=([]);
                         global->general+=([v : id->variables[v]]);
                                         }

                                         save_status=0;// we need to save.
                                     }

                                     retval+=
                                         "<TR HEIGHT=\"28\">\n"
                                         "<TD WIDTH=\"32\" HEIGHT=\"28\"><SPACER TYPE=\"BLOCK\" WIDTH=\"32\" HEIGHT=\"28\"></TD>\n"
                                         "<TD WIDTH=\"186\" HEIGHT=\"28\" COLSPAN=\"1\" ROWSPAN=\"1\" VALIGN=\"top\" ALIGN=\"left\" XPOS=\"32\"><A "
                                         " HREF=\""+query("mountpoint")+"config/configs\"><IMG SRC=\""+query("mountpoint")+"ivend-image/configurationsunselect.gif\" "
                                         " WIDTH=\"186\" HEIGHT=\"" "28\" BORDER=\"0\" ALT=\"/  Configurations  \\\"></A></TD>\n"
                                         "<TD WIDTH=\"6\" HEIGHT=\"28\"><SPACER TYPE=\"BLOCK\" WIDTH=\"6\" HEIGHT=\"28\"></TD>\n"
                                         "<TD WIDTH=\"186\" HEIGHT=\"28\" COLSPAN=\"1\" "
                                         "ROWSPAN=\"1\" VALIGN=\"top\" ALIGN=\"left\" "
                                         "XPOS=\"224\"><A "
                                         "HREF=\""+query("mountpoint")+"config/global\"><IMG "
                                         "SRC=\""+query("mountpoint")+"ivend-image/globalselect.gif\" WIDTH=\"186"
                                         "\" HEIGHT=\"28\""
                                         " BORDER=\"0\" ALT=\"/ Global Variables \\\"></A></TD>\n"
                                         "<TD WIDTH=\"6\" HEIGHT=\"28\"><SPACER TYPE=\"BLOCK\" WIDTH=\"6\" HEIGHT=\"28\"></TD>\n"
                                         "<TD WIDTH=\"186\" HEIGHT=\"28\" COLSPAN=\"1\" "
                                         "ROWSPAN=\"1\" VALIGN=\"top\" ALIGN=\"left\" XPOS=\"416\"><A "
                                         "HREF=\""+query("mountpoint")+"config/status\"><IMG "
                                         "SRC=\""+query("mountpoint")+"ivend-image/statusunselect.gif\" "
                                         "WIDTH=\"186\" HEIGHT=\"28\""
                                         " BORDER=\"0\" ALT=\"/        Status        \\\"></A></TD>\n"
                                         "<TD WIDTH=\"182\" HEIGHT=\"28\"><SPACER TYPE=\"BLOCK\" WIDTH=\"182\" HEIGHT=\"28\"></TD>\n</TR>\n"
                                         "<TD COLSPAN=6><BR><BLOCKQUOTE><P ALIGN=\"LEFT\"><FONT SIZE=+2 FACE=\"times\">"
                                         "Global Variables</FONT><P>\n"
                                         "<FORM METHOD=POST ACTION=\""+query("mountpoint")+"config/global/save\">\n"
                                         "<TABLE>" +

                                         (g->genform(
                                              global->general || 0,
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
                                         "<TD WIDTH=\"186\" HEIGHT=\"28\" COLSPAN=\"1\" ROWSPAN=\"1\" VALIGN=\"top\" ALIGN=\"left\" "
                                         "XPOS=\"32\"><A HREF=\""+query("mountpoint")+"config/configs\"><IMG "
                                         "SRC=\""+query("mountpoint")+"ivend-image/configurationsselect.gif\" "
                                         "WIDTH=\"186\" HEIGHT=\"28\""
                                         " BORDER=\"0\" ALT=\"/  Configurations  \\\"></A></TD>\n"
                                         "<TD WIDTH=\"6\" HEIGHT=\"28\"><SPACER TYPE=\"BLOCK\" WIDTH=\"6\" HEIGHT=\"28\"></TD>\n"
                                         "<TD WIDTH=\"186\" HEIGHT=\"28\" COLSPAN=\"1\" ROWSPAN=\"1\" VALIGN=\"top\" ALIGN=\"left\" XPOS=\"224\"><A "
                                         "HREF=\""+query("mountpoint")+"config/global\"><IMG SRC=\""+query("mountpoint")+
                                         "ivend-image/globalunselect.gif\" WIDTH=\"186\" "
                                         " HEIGHT=\"28\" BORDER=\"0\" ALT=\"/ Global Variables \\\"></A></TD>\n"
                                         "<TD WIDTH=\"6\" HEIGHT=\"28\"><SPACER TYPE=\"BLOCK\" WIDTH=\"6\" HEIGHT=\"28\"></TD>\n"
                                         "<TD WIDTH=\"186\" HEIGHT=\"28\" COLSPAN=\"1\" ROWSPAN=\"1\" VALIGN=\"top\" ALIGN=\"left\" XPOS=\"416\"><A "
                                         "HREF=\""+query("mountpoint")+"config/status\"><IMG SRC=\""+query("mountpoint") +
                                         "ivend-image/statusunselect.gif\" WIDTH=\"186\" "
                                         " HEIGHT=\"28\" BORDER=\"0\" ALT=\"/        Status        \\\"></A></TD>\n"
                                         "<TD WIDTH=\"182\" HEIGHT=\"28\"><SPACER TYPE=\"BLOCK\" WIDTH=\"182\" HEIGHT=\"28\"></TD>\n"
                                         "</TR>\n"
                                         "<TR>\n"
                                         "<TD WIDTH=\"32\" HEIGHT=\"28\"><SPACER "
                                         "TYPE=\"BLOCK\" WIDTH=\"32\" HEIGHT=\"28\"></TD>\n";


                                     if(request[0]=="reload"){
                                         stop();
                                         start();
                                         return http_redirect(query("mountpoint")+"config/configs",id);

                                     }

                                     if(request[0]=="delete"){

                                         object w=(object)clone(compile_file(query("root")+"/src/deletewiz.pike"));
                                         // perror(indices(w)*"\n");
                                         mixed res=w->wizard_for(id, "./");
                                         if(stringp(res)) retval+="<td colspan=6><p>&nbsp;<p>\n" + res +
                                                                      "</td></tr>\n";
                                         else return res;

                                     }

                                     else if(request[0]=="new"){

                                         object w=(object)clone(compile_file(query("root")+"/src/newaddwiz.pike"));

                                         mixed res=w->wizard_for(id, "./");
                                         if(stringp(res)) retval+="<td colspan=6><p>&nbsp;<p>\n" + res +
                                                                      "</td></tr>\n";
                                         else return res;                        }

                                     else if(catch(request[1])){// Haven't specified a configuration yet, so list 'em all.

                                         retval+="<TD COLSPAN=6><BR><BLOCKQUOTE><P ALIGN=\"LEFT\"><FONT SIZE=+2 FACE=\"times\">"
                                                 "All Configurations</FONT><P>\n";

                                         array(string) all_configs=indices(config);

                                         for(int i=0; i<sizeof(all_configs); i++){

                                             retval+="<LI><FONT SIZE=+1 FACE=\"helvetica,arial\"><A HREF=\""+query("mountpoint")+"config/configs/"+all_configs[i]+"\">"
                                                     +config[all_configs[i]]->general->name+"</A></FONT>\n";

                                         }
                                         retval+="<P><FONT FACE=\"times\" SIZE=+1>To View or Modify a Configuration, Click on it's name in the list above.</FONT><P>\n"
                                                 "<A HREF=\""+query("mountpoint")+"config/new\">New Configuration</A> &nbsp; "
                                                 "<A HREF=\""+query("mountpoint")+"config/reload\">Reload Configurations</A> &nbsp; ";
                                         if(save_status!=1)
                                             retval+="<A HREF=\""+query("mountpoint")+"config/save\">Save Changes</A>";
                                         else retval+="<A HREF=\""+query("mountpoint")+"config/delete\">Delete Configuration</A> &nbsp; ";

                                     }





                                     else {// OK, we know what we have in mind...

                                         if(id->variables->config_delete=="1") {

                                             int n=search(global->configurations->active, request[1]);
                                             if(n) global->configurations->active[n]="";
                                             if(arrayp(global->configurations->active))
                                                 global->configurations->active-=({""});

                                             config=m_delete(config,request[1]);
                                             save_status=0;
                                             mv(query("configdir")+ request[1], query("configdir") + request[1] + "~");

                                             return http_redirect(query("mountpoint")+"config/configs?"+time(),id);

                                         }

                                         else if(!catch(request[2]) && request[2]=="config_modify") {
                                             array(string) variables= (indices(id->variables)- ({"config_modify"}));
                                             for(int i=0; i<sizeof(variables); i++){
                                                 if(variables[i]=="config_password" &&
                                                             id->variables[variables[i]]!=config[id->variables->config]["general"][variables[i]])
                                                 {

                                                     id->variables[variables[i]]=crypt(id->variables[variables[i]]);
                                                 }
                                                 config[id->variables->config]["general"][variables[i]]=
                                                     id->variables[variables[i]];

                                             }

                                             save_status=0;
                                             return http_redirect(query("mountpoint")+"config/configs/"+request[1]+"?"+time(),id);


                                         }

                                         else retval+="<TD COLSPAN=6><BR><BLOCKQUOTE><P ALIGN=\"LEFT\"><FONT SIZE=+2 FACE=\"times\">"
                                                          "<a href=\""+ query("mountpoint")+
                                                          ((sizeof(config)==1 &&
                                                            getglobalvar("move_onestore")=="Yes")
                                                           ?"": request[1]+"/")
                                                          +"\">"
                                                          +config[request[1]]["general"]->name+"</a></FONT><P>\n"
                                                          "<FORM METHOD=POST ACTION=\""+query("mountpoint")+"config/configs/"+request[1]+"/config_modify\">\n"
                                                          "<TABLE>"

                                                          +(c->genform(config[request[1]]->general,query("lang"),
                                                                       query("root")+"src/modules")
                                                            ||"Error loading configuration definitions")+
                                                          "</TABLE><p><input type=submit value=\"Modify Configuration\"><p>";
                                         if(save_status!=1)
                                             retval+="<A HREF=\""+query("mountpoint")+"config/save\">Save Changes</A> &nbsp; ";
                                         retval+=
                                             "</FORM>"
                                             "</TD></TR>";

                                     }

                                     retval+="</TD></TR>\n";

                                     break;

                                 }




                             }


                             retval+=

                                 "</TABLE>\n"
                                 "</FONT></CENTER>\n"
                                 "</BODY>\n"
                                 "</HTML>\n";

                             return http_string_answer(retval, 0, id);

                         }




