#!NOMODULE

#define DB id->misc->ivend->db

constant module_name = "Shipping Handler";
constant module_type = "shipping";

mapping handlers=([]);

mapping query_tag_callers2();
mapping query_container_callers2();    

int initialized;

object|void load_module(string type, mapping config){

object m;

string moddir=config->global->root + "/src/modules/shipping";

catch(m=(object)clone(compile_file(moddir+"/"+type)));
if(m && objectp(m))
  return m;
else error("iVend: the module " + type + " did not load properly.\n");

return;

}

void start(mapping config){

initialized=0;
object db;

if(catch(db=iVend.db(config->dbhost, config->db,
  config->dblogin, config->dbpassword)))
  {
    perror("iVend: Shipping: Error Connecting to Database.\n");
    return;
  }

if((sizeof(db->list_tables("shipping_types")))==1)
  initialized=1;

array r=db->query("select * from shipping_types");

foreach(r, mapping row){
	// load modules
  if(objectp(handlers[row->type])); // already loaded that one.
  else handlers[row->type]=load_module(row->type, config);
  }

return;

}

void stop(mapping config){

return;

}

mapping available_modules(mapping config){
object m;
string moddir=config->global->root + "/src/modules/shipping";
mapping am=([]);

foreach(get_dir(moddir), string name){
  catch(m=(object)clone(compile_file(config->global->root + 
    "/src/modules/shipping/" + name));
  
  if(m && objectp(m)) {
  string desc=m->module_name;
  string type=m->module_type;
  if(type=="shipping")
    am[name] = desc;
  }

  else perror("iVend: the module " + name + " did not load properly.\n");
  }

return am;
}

int initialize_db(object id) {

  perror("initializing shipping module!\n");

if(sizeof(DB->list_tables("shipping_types"))!=1)
  catch(DB->query("CREATE TABLE shipping_types ("
  "  type int(11) DEFAULT '0' NOT NULL auto_increment,"
  "  name varchar(32) DEFAULT '' NOT NULL,"
  "  description blob,"
  "  module varchar(32),"
  "  PRIMARY KEY (type)"
  ") "));
return 0;

}

mixed shipping_admin (object id){ 

string retval="";

retval+="<font face=\"helvetica,arial\">";

if(id->variables->showtype){
  array r=DB->query("SELECT * FROM shipping_types WHERE id=" +
    id->variables->showtype );
  retval+="<b>Type: " + r[0]->name + "</b>"; 

  
}

else {

retval+="<b>Configured Shipping Types</b><p>";

array r=DB->query("SELECT * FROM shipping_types ORDER BY id");
if(sizeof(r)==0)
    retval+="No Shipping Types Configured.";
else {
    foreach(r, mapping row)
      retval+= "<A HREF=\"./shipping?showtype=" + row->id + "\">"
        +row->name + "</a>: " + row->module;

  }
}
return retval;

}
