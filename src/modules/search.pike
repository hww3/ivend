#!NOMODULE

#include <ivend.h>

inherit "roxenlib";

constant module_name = "Search Handler";
constant module_type = "addin";    

array groupsearchfields=({});
array productsearchfields=({});
array stopwords=({});

void initialize_db(object db) {
  perror("initializing search module!\n");
catch(db->query("drop table searchwords"));
db->query(
"CREATE TABLE searchwords ("
"  id char(16) DEFAULT '' NOT NULL,"
"  type char(1) DEFAULT 'p' NOT NULL,"
"  occ int DEFAULT 0 NOT NULL,"
"  word char(64) DEFAULT '' NOT NULL"
") ");

return;

}   


mixed searchadmin_handler(string mode, object id)
{ 

// return sprintf("<pre>%O</pre>",
// mkmapping(indices(id->misc->ivend),
// values(id->misc->ivend))); 

if(id->variables->initialize) {
	initialize_db(DB);
   return "Search module initialized. To use this feature, please "
    " close this window and start again.<p>\n"
	+T_O->return_to_admin_menu(id);
  }
if(sizeof(DB->list_tables("searchwords"))!=1)
  return "You have not configured the search handler."
	"<p><a href=./?initialize=1>Click here</a>"
	" to do this now.";
if(id->variables->build_database) {
build_database(id);
}

string retval="<title>Search Configuration</title>\n"
	"<body bgcolor=white text=navy>"
	"<font face=helvetica, arial>";

if((int)(DB->query("SELECT COUNT(*) as c FROM searchwords")[0]->c)>0)
  {
  retval+="The search database has been generated.<p>";
  retval+=T_O->return_to_admin_menu(id);
  }
else
  {
  retval+="<form action=./>\n";
  retval+="The searchwords database has not been built yet. Press the build "
	"button below to build the initial search database. This process "
	"will build the search database for products and groups already in "
	"the store database. <p>"
	"If you have not yet added any groups or stores to your database, "
	"you do not need to perform this step. Search words will be "
	"generated automatically.<p>";
  retval+="<input type=hidden name=build_database value=1>"
	"<input type=submit value=\"Build\">";
  retval+="</form>\n";
  }
return retval;

}

void build_database(object id){
perror("Building searchwords database.\n");
  array r=DB->query("SELECT " + KEYS->groups + " from groups order by " + KEYS->groups);
  foreach(r, mapping row){
	event_adminadd("adminadd", id, (["id": row[KEYS->groups], "type": "group"]));
  }
  array r=DB->query("SELECT " + KEYS->products + " from products order by " + KEYS->products);
  foreach(r, mapping row){
	event_adminadd("adminadd", id, (["id": row[KEYS->products], "type": "product"]));
  }



}

string tag_searchresults(string tag_name, mapping args,
                  object id, mapping defines) {
string results="";

return results;

}

string tag_searchform(string tag_name, mapping args,
                  object id, mapping defines) {
// perror("DB: " + sprintf("%O\n", DB) );
  string action="";
  string size="20";
  if(args->action) action=args->action;
  else action=id->not_query;
  if(args->size) size=args->size;
  else if(args->big) size="50";
  else if(args->small) size="25";

   string retval="<form action=\"" + action + "\">\n";
	retval+="<input type=text name=q size=" + size + ">\n";
	retval+="<input type=radio name=stype value=key selected> Keywords "
		"<input type=radio name=stype value=id> " + 
		replace(DB->keys->products, "_", " ");
	retval+=" <input type=submit value=\"Search\">\n";
	retval+="</form>\n";

   return retval;

}

string cleanword(string word){

  word=replace(word, 
	({".", ",", "!", "-", "[", "]", "{", "}", "|", "\\",
	"/", "<", ">", "-", "_", "+", "=", "(", ")", "`", "~", 
	"!", "@", "#", "$", "%", "^", "&", "&", "*", ":", "'" 
	}),	
	({" ", " ", " ", " ", " ", " ", " ", " ", " ", " ",
	" ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ",
	" ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " "
	})
	);

  return word;
}

void event_adminadd(string event, object id, mapping args){

array f=CONFIG_ROOT[module_name][args->type + "searchfields"];

mapping r;

r=DB->query("SELECT " + (f*",") + " FROM " + args->type + 
			  "s WHERE " + DB->keys[args->type + "s"] + "='" + 
			  args->id + "'")[0];
mixed e;
if(e) { 
	perror("Error selecting searchfields for " + args->type + " " + args->id + ".\n");
	return;
	}

if(sizeof(stopwords)==0 && 
	CONFIG_ROOT[module_name]["stopwordfile"]!="" && 
	file_stat(CONFIG_ROOT[module_name]["stopwordfile"])){
	perror("Reading stopwords file: " + CONFIG_ROOT[module_name]["stopwordfile"]+ "...");
stopwords=(Stdio.read_file(CONFIG_ROOT[module_name]["stopwordfile"])-"\r")/"\n";
stopwords-=({""});

}


string wordstoadd="";
foreach(indices(r), string f){
 if(search(f,".")>=0) continue;
 wordstoadd+=" ";
 wordstoadd+=r[f];
}



wordstoadd=replace(wordstoadd, ({"\n", "\r", "\t"}), ({" ", " ", " "}));
array w=wordstoadd/" ";
w-=({""});
mapping wc=([]);
foreach(w, string word){
word=cleanword(word);

 if(search(stopwords, word)>=0) continue;
 if(wc[word]) wc[word]++;
 else wc[word]=1;
 }
foreach(indices(wc), string word){
  DB->query("INSERT INTO searchwords VALUES('" + args->id + "','" 
	+ args->type + "'," + wc[word] + ",'" + word + "')");
}
}

void event_adminmodify(string event, object id, mapping args){

// first we delete the existing searchwords.

  event_admindelete(event, id, args);

// now we add searchwords with the modified object.

  event_adminadd(event, id, args);

}

void event_admindelete(string event, object id, mapping args){

// delete the searchwords for the object we are deleting.

  DB->query("DELETE FROM searchwords WHERE id='" + args->id + "'" 
	" AND type='" + args->type[0..0] + "'");

}

mixed query_tag_callers(){

  return ([ "searchform": tag_searchform,
		"searchresults": tag_searchresults
	]);

}

mixed register_admin(){

return ({

	([ "mode": "menu.main.Store_Administration.Search_Engine",
		"handler": searchadmin_handler,
		"security_level": 7 ])
	});

}

array query_preferences(void|object id) {

  if(!catch(DB) && sizeof(groupsearchfields)<=0) {

     array f2=DB->list_fields("groups");
     foreach(f2, mapping m)
	groupsearchfields +=({m->name});
    }

  if(!catch(DB) && sizeof(productsearchfields)<=0) {

     array f2=DB->list_fields("products");
     foreach(f2, mapping m)
	productsearchfields +=({m->name});
    }

   
  return ({ 
	({"groupsearchfields", "Group Search Fields", 
	"Fields to be included when searching for groups.",
	VARIABLE_MULTIPLE,
	"name",
	groupsearchfields
	}) ,

	({"productsearchfields", "Product Search Fields", 
	"Fields to be included when searching for products.",
	VARIABLE_MULTIPLE,
	"name",
	productsearchfields
	}) ,

	({"stopwordfile", "Stop Word File", 
	"Path to a file that contains words to exclude from search database.",
	VARIABLE_STRING,
	""
	})

	});

}

mixed query_event_callers(){
 
  return ([	"adminadd" : event_adminadd,
		"adminmodify" : event_adminmodify,
 		"admindelete" : event_admindelete]);

}
