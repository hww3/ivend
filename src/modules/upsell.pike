#include "../include/ivend.h"

inherit "roxenlib";

constant module_name = "Upsell Handler";
constant module_type = "addin";    

void initialize_db(object db) {

  perror("initializing order total shipping module!\n");
catch(db->query("drop table upsell"));
db->query(
"CREATE TABLE upsell ("
"  id char(16) DEFAULT '' NOT NULL,"
"  upsell char(16) DEFAULT '' NOT NULL"
") ");

return;

}   

mixed upsell_handler(string mode, object id){

// return sprintf("<pre>%O</pre>", mkmapping(indices(id->misc->ivend),
// values(id->misc->ivend))); 

if(id->variables->initialize)
	initialize_db(DB);

if(sizeof(DB->list_tables("upsell"))!=1)
  return "You have not configured the upsell handler."
	"<p><a href=./?initialize=1",(<"upsell">))+">Click here</a>"
	" to do this now.";

if(id->variables->action=="AddUpsell")
  DB->query("INSERT INTO upsell VALUES('" + id->variables->id + "','" + 
	id->variables->upsell + "')");
else {

  foreach(indices(id->variables), string vname)
    if(id->variables[vname]=="Delete")
      DB->query("DELETE FROM upsell WHERE id='" + id->variables->id + 
	"' AND upsell='" + vname + "'"); 

}

string retval="<title>Upsell</title>\n"
	"<body bgcolor=white text=navy>"
	"<font face=helvetica, arial>";

array r=DB->query("SELECT * FROM products WHERE " + KEYS->products + "='"
	+ id->variables->id + "'");
if(!r) return "Cannot Find Product " + id->variables->id + ".";
  retval+= "Upsell: <b>" + r[0]->name + "</b><p>";

  retval+="<form action=./>\n"
	"<input type=hidden name=id value=" + id->variables->id + ">\n"
	"<select name=upsell>\n";	
  array r=DB->query("SELECT * FROM products ORDER BY " + KEYS->products);
	foreach(r, mapping row)
	  retval+="<option value=\"" + row[KEYS->products] + "\">"
	    + row[KEYS->products] +": "+ row->name + "\n";
  retval+="</select> <input type=submit value=AddUpsell name=action>"
  "<p>Currently associated Upsells:<br>";

  array r=DB->query("SELECT * FROM products,upsell WHERE upsell.id='" +
	id->variables->id + "' and upsell.upsell=products." + KEYS->products);
  if(r)
  foreach(r, mapping row)
    retval+="<input type=submit name=\"" + row->upsell
	+ "\" value=Delete>" + row->name + "<br>";
  else retval+="No Upsell Items Currently Assigned.";
  retval+="</form>\n";

return retval;

}

string tag_upsell(string tag_name, mapping args,
                  object id, mapping defines) {

   string retval="";

   array r=DB->query("SELECT upsell.id,products.* FROM upsell,products "
                     "WHERE upsell.id='" + id->misc->ivend->page +
                     "' AND products.id=upsell.upsell");

   if(sizeof(r)>0) {
      retval+="<table width=220>\n"
              "<tr><td colspan=2 bgcolor=black><font color=white>Must "
                "Have Accessories</td></tr>\n"
              "<input type=hidden name=ADDITEM VALUE=1>\n";
      foreach(r, mapping row) {
         retval+="<tr><td><input type=checkbox value=\"ADDITEM\" name=\""
                 + row->id + "\"></td><td>"
                 "<a href=\"/" + row->id + ".html\">"
                 "<font size=-1>"+ row->name +"</a><br><font color=maroon>$" +
                 row->price + "</td></tr>\n";
      }
         retval+="<tr><td colspan=2><font size=1>Check one or more of"
                  "these great accessories to be added to your cart when "
                  "you order this item."
                 "</td></tr>\n</table>";
   }

   return retval;

}

mixed query_tag_callers(){

  return ([ "upsell": tag_upsell ]);

}

mixed register_admin(){

  return ([ "upsell":upsell_handler ]);
}


