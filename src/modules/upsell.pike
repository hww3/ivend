#include "../include/ivend.h"


mixed upsell_handler(string mode, object id){
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

  retval+="<form action= " + id->not_query + ">\n"
	"<input type=hidden name=mode value=upsell>\n"
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

mixed register_admin(){

  return ([ "upsell":upsell_handler ]);
}


