#!NOMODULE

#include <ivend.h>

inherit "roxenlib";

constant module_name = "Search Handler";
constant module_type = "addin";    

array groupsearchfields=({});
array productsearchfields=({});
array stopwords=({});
mapping idmappings=([]);

void start(object mo, object db)
{
perror("start in search.\n");

if(mo->config[module_name]->idmappingfile!="" && 
file_stat(mo->config[module_name]->idmappingfile)) {
perror("we have specified an idmapping file.\n");
array r=Stdio.read_file(mo->config[module_name]->idmappingfile)/"\n";
foreach(r, string line){
 array l=(replace(line,({" ", "\m", "\r"}),({"","",""}) ) )/"\t";
 if(sizeof(l)==2)
   idmappings+=([ l[0] : l[1] ]);
	}
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
if(id->variables->stype=="id"){
if(idmappings[((id->variables->q)-" ")]) q=idmappings[((id->variables->q)-" ")];
else q=(id->variables->q)-" ";
  // we're searching by catalog id.
	if(sizeof(DB->query("SELECT " + DB->keys->products + " FROM products "
	" WHERE " + DB->keys->products + "='" + (q) + "'"))==1)

{


  string r = (T_O->query("mountpoint") + id->variables->q + ".html");

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

string query="SELECT id, type, (sum(occ)*count(id)*(length(word)*1.1)) as occ, word FROM searchwords WHERE ";
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
	mapping grow=DB->query("SELECT name "
	", description FROM groups WHERE " + DB->keys->groups + "='" +
row->id + "'")[0];
	groupresults+="<dt><a href=\"" + T_O->query("mountpoint") + row->id + ".html\">" +
grow->name + "</a> (" + row->occ + " / " +maxocc +  ")</dt><dd>" +
grow->description + "</dd><p>";
	}
    else {
	if(numproducts>15) continue;
	numproducts++;
	mapping grow=DB->query("SELECT " +
CONFIG_ROOT[module_name]->productnamefield + 
	", description FROM products WHERE " + DB->keys->products + "='" +
row->id + "'")[0];
	productresults+="<dt><a href=\"" + T_O->query("mountpoint") + row->id + ".html\">" +
grow[CONFIG_ROOT[module_name]->productnamefield] +
"</a> (" + row->occ + " / " + maxocc  +  ")</dt><p>";

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
	retval+="<input type=radio name=stype value=key " +
(id->variables->stype=="key"|!id->variables->stype?"checked":"") +
">&nbsp;Keywords "
		"<input type=radio name=stype value=id " +
(id->variables->stype=="id"?"checked":"") + ">&nbsp;" + 
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

mixed query_tag_callers(){

  return ([ "searchform": tag_searchform,
		"searchresults": tag_searchresults
	]);

}

array query_preferences(void|object id) {
  string swfile="";

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

	({"productnamefield", "Product Name Field", 
	"Fields to be displayed when viewing a product name.",
	VARIABLE_SELECT,
	"name",
	productsearchfields
	}) ,

	({"productsearchfields", "Product Search Fields", 
	"Fields to be included when searching for products.",
	VARIABLE_MULTIPLE,
	"name",
	productsearchfields
	}) ,

	({"idmappingfile", "Catalog ID mapping File", 
	"Path to a file that contains mappings from one catalog number to another (optional). file format is one mapping per line, tab separated in the format: <p>SEARCHEDID<i>(tab)</i>RETURNEDID<i>(newline)</i>",
	VARIABLE_STRING,
	""
	})

	});

}

