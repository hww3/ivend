#!NOMODULE

#include <ivend.h>

inherit "roxenlib";

constant module_name = "Search Handler";
constant module_type = "addin";    

array groupsearchfields=({});
array productsearchfields=({});
array stopwords=({});
mapping idmappings=([]);

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

void start(mapping config)
{
perror("start in search.\n");
// perror(sprintf("%O\n", config));

if(sizeof(stopwords)==0 && 
	config[module_name]["stopwordfile"]!="" && 
	file_stat(config[module_name]["stopwordfile"])){
	perror("Reading stopwords file: " + config[module_name]["stopwordfile"]+ "...");
stopwords=(lower_case(Stdio.read_file(config[module_name]["stopwordfile"])-"\r"))/"\n";
stopwords-=({""});
}

if(config[module_name]->idmappingfile!="" && file_stat(config[module_name]->idmappingfile)) {
perror("we have specified an idmapping file.\n");
array r=Stdio.read_file(config[module_name]->idmappingfile)/"\n";
foreach(r, string line){
 array l=(replace(line,({" ", "\m", "\r"}),({"","",""}) ) )/"\t";
 if(sizeof(l)==2)
   idmappings+=([ l[0] : l[1] ]);
	}
}
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

#define _stat defines[" _stat"]
#define _error defines[" _error"]
#define _extra_heads defines[" _extra_heads"]
#define _rettext defines[" _rettext"]
#define _ok     defines[" _ok"]



string tag_searchresults(string tag_name, mapping args,
                  object id, object file, mapping defines) {
defines=([]);
string q="";
string results="";
if(!id->variables->q || !id->variables->stype)
	return "<!-- Incorrectly configured search query or no query -->";
if(id->variables->stype==DB->keys->products){
if(idmappings[((id->variables->q)-" ")]) q=idmappings[((id->variables->q)-" ")];
else q=(id->variables->q)-" ";
  // we're searching by catalog id.
	if(sizeof(DB->query("SELECT " + DB->keys->products + " FROM products "
	" WHERE " + DB->keys->products + "='" + (q) + "'"))==1)

{


  string r = (T_O->query("mountpoint") + (id->misc->ivend->moveup?"": STORE+ "/") + id->variables->q + ".html");

  results=("<redirect to=\"" + r + "\">"
	"<!-- should have been a redirect to " + r + ". -->") ;
id->misc->ivend->redirect=1;
// + sprintf("<pre>%O</pre>\n", mkmapping(indices(id),values(id))));
//perror(sprintf("<pre>%O</pre>\n", defines));

}
else results="No " + replace(DB->keys->products, "_", " ") + " " + upper_case(id->variables->q) + " found.";
}
else {

// we're searching by keyword.
int reqflag=0;
array k=(lower_case(id->variables->q)/" ")-({""});
perror("found " + sizeof(k) + " words.\n");
foreach(k, string w){
 string nw="";
  if(w[0..0]=="+") { nw=w[1..]; reqflag=1; }
  else nw=w;
  if(search(stopwords, nw)>=0) {perror("found a stopword in query.\n"); k-=({w});}
}
perror("found " + sizeof(k) + " searchable words.\n");
// are we left with any good words?
if(sizeof(k)<1) return "No searchable words supplied for search. Please try again with more specific words.";

string query="SELECT id, type, sum(occ) as occ, word FROM searchwords WHERE ";
array qp=({});
foreach(k, string word) {
  if(word[0..0]=="+") word=word[1..];
  qp+=({"'" + word + "'"});
}
query+="word IN(" + (qp*",") + ") ";

if(reqflag==1) query +=" GROUP BY id,type,word ORDER BY occ DESC";
else query +="GROUP BY id,type ORDER BY occ DESC";
perror("QUERY: " + query + "\n");
array res=DB->query(query);
if(sizeof(res)==0) return "Your search returned zero results. Please try again.";
if(reqflag==1){
  array i=({});
  foreach(res, mapping row)
    i+=({row->id});
  }
else // we aren't requiring words to be present...
  {

  string groupresults="";
  string productresults="";
  int numproducts,numgroups=0;
  int maxocc=(int)(res[0]->occ);
  
  foreach(res, mapping row){ // look at each result record.
    if(row->type=="g") {
	if(numgroups>4) continue;
	numgroups++;
	mapping grow=DB->query("SELECT name, description FROM groups WHERE " + DB->keys->groups + "='" + row->id + "'")[0];
	groupresults+="<dt><a href=\"" + T_O->query("mountpoint") + (id->misc->ivend->moveup?"": STORE+ "/") + row->id + ".html\">" + grow->name + "</a> (" +  (string)(((int)((float)(row->occ)/(float)(maxocc))*4))  +  " stars)</dt><dd>" + grow->description + "</dd><p>";
	}
    else {
	if(numproducts>15) continue;
	numproducts++;
	mapping grow=DB->query("SELECT name, description FROM products WHERE " + DB->keys->products + "='" + row->id + "'")[0];
	productresults+="<dt><a href=\"" + T_O->query("mountpoint") + (id->misc->ivend->moveup?"": STORE+ "/") + row->id + ".html\">" + grow->name + "</a> (" +  (string)(((int)((float)(row->occ)/(float)(maxocc))*4))  +  " stars)</dt><p>";

      }
    }
if(groupresults=="") groupresults="No groups found that match your query.";
if(productresults=="") productresults="No products found that match your query.";
results="<h2>Top Group Results</h2>\n" + groupresults + "<p>";
results+="<h2>Top Product Results</h2>\n" + productresults + "\n"; 
  }
}

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
	retval+="<input type=text name=q size=" + size +" VALUE=\"" + upper_case((id->variables->q||"")) + "\">\n";
	retval+="<input type=radio name=stype value=key " + (id->variables->stype=="key"|!id->variables->stype?"checked":"") + "> Keywords "
		"<input type=radio name=stype value=id " + (id->variables->stype=="id"?"checked":"") + "> " + 
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
stopwords=(lower_case(Stdio.read_file(CONFIG_ROOT[module_name]["stopwordfile"])-"\r"))/"\n";
stopwords-=({""});

}


string wordstoadd="";
foreach(indices(r), string f){
 if(search(f,".")>=0) continue;
 wordstoadd+=" ";
 wordstoadd+=r[f];
}

wordstoadd=lower_case(wordstoadd);

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
	"Path to a file that contains words to exclude from search database. (optional but recommended)",
	VARIABLE_STRING,
	""
	}),

	({"idmappingfile", "Catalog ID mapping File", 
	"Path to a file that contains mappings from one catalog number to another (optional). file format is one mapping per line, tab separated in the format: <p>SEARCHEDID<i>(tab)</i>RETURNEDID<i>(newline)</i>",
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
