#!NOMODULE

#include <ivend.h>
#include <messages.h>
inherit "roxenlib";

constant module_name = "Admin Interface";
constant module_type = "handler";

void start(mapping config){

return;
  
}

string return_to_admin_menu(object id){

return "<a href=\""  +     add_pre_state(id->not_query,
             (<"menu=main">))+   "\">"
         "Return to Store Administration</a>.\n";

}

void|mixed event_admindelete(string event, object id, mapping args){
if(args->type=="product")
  DB->query("DELETE FROM item_options WHERE product_id='" + args->id + "'");
return;
}

void|mixed tag_itemoptions(string tag_name, mapping args, object id,
mapping defines) {
 
  string retval=""; 

  array r=DB->query("SELECT * FROM item_options WHERE product_id='" +
args->item + "' GROUP BY option_type ORDER BY option_type ASC");

  if(!r || sizeof(r)<1) return 0;

retval+="<input type=hidden name=options value=1>\n";
  foreach(r, mapping row){
  retval+="  <select name=\"" +  row->option_type + "\">\n";
    foreach(DB->query("SELECT * FROM item_options WHERE product_id='" +
      args->item + "' AND option_type='" + row->option_type + 
      "' ORDER BY surcharge ASC, option_code " + (args->order || "ASC")),
	mapping row2)
        retval+="<option value=\"" + row2->option_code + "\">" +
row2->description + 
((float)(row2->surcharge)!=0.00? " " + MONETARY_UNIT + (sprintf("%.2f",
(float)(row2->surcharge))) + " surcharge":"") + "\n"; 
 
  retval+="</select>\n";
  }

return retval;
}


mixed action_itemoptions(string mode, object id){
string retval="<html><head><title>Item Options</title></head>\n"
	"<body bgcolor=white text=navy>\n"
	"<font face=helvetica>";
mapping v=id->variables;
ADMIN_FLAGS=NO_BORDER;
if(!v->id) retval+= "You have not specified a item ID number.";
else {
retval+="Options for " + v->id +"<p>";

if(v->add) {
  if(!catch(DB->query("INSERT INTO item_options VALUES('" + v->id + "','"
+ upper_case(v->option_type) + "','" + upper_case(v->option_code) + "','"
+ DB->quote(v->description)  + "'," + (v->surcharge||0.00) + ")")))
    retval+="<font size=1>Item Option Added Successfully.</font><br>";
  else retval+="<font size=1>An error occurred while adding this option:<br>"
   + DB->error() + "\n<br>";
}

if(v->delete) {
  if(!catch(DB->query("DELETE FROM item_options WHERE product_id='" +
   v->id + "' AND option_type='" + v->option_type + "' AND option_code='"
   + v->option_code + "'"))) 
    retval+="<font size=1>Item Option Deleted Successfully.</font><br>";
}

retval+="<form action=\"./\">\n"
  "<input type=hidden name=id value=\"" + v->id + "\">\n";

array r=DB->query("SELECT * FROM item_options WHERE product_id='" + v->id
+ "' ORDER BY option_type, option_code");

  retval+="<table border=1>\n<tr><th>Option Type</th><th>Option Code</th>"
   "<th>Option Name</th><th>Surcharge</th><td></td></tr>\n";
if(!r || sizeof(r)<1) retval+="<tr><td colspan=5 align=center>No Item "
  "Options Defined.</td></tr>\n";

else {

  foreach(r,mapping row)
   retval+="<tr><td>" + row->option_type + "</td><td>" + row->option_code
    + "</td><td>" + row->description + "</td><td>" + sprintf("%.2f",
    (float)(row->surcharge)) + "</td><td><font size=1><a href=\"./?id=" +
	v->id + "&option_type=" + row->option_type + "&option_code=" +
	row->option_code + "&delete=1\">Delete</a></font></td></tr>\n";
}

retval+="<tr><td><input type=text name=option_type size=10></td><td>"
  "<input type=text name=option_code size=10></td><td>"
  "<input type=text name=description size=30></td><td>"
  "<input type=text value=0.00 name=surcharge size=6</td><td><font size=2><input "
  "type=submit name=add value=add></font></td></tr>\n";
  retval+="</table>";
retval+="</form>"
  "<b>Instructions</b><br>"
  "To add a new item option, complete the form above and click on 'Add'.<br>"
  "To delete an item option, click on the 'Delete' link next to the "
  "option you wish to remove.<p>";

   retval+="<font size=0>"
  "<b>Option Type</b> is the type of item option you are adding, for "
  "example <i>SIZE</i>. Options will be displayed with others of the "
  "same type.<br>"
  "<b>Option Code</b> is the code for the individual option you are adding, "
  "for example <i>XL</i>.<br>"
  "<b>Option Name</b> is a description of the option you are adding, for "
  "example, <i>Extra Large</i>. The Option Name of each option will be "
  "displayed to the user.<br>"
  "<b>Surcharge</b> is an additional charge for each unit of product "
  "selected with this option. For example, a surcharge of <i>1.50</i> "
  "will add 1.50 for each item for which the particular option is chosen."
  "<p></font>\n";
}
retval+="<center><font size=-1>"
	"<form><input type=reset onclick=window.close() value=Close></form>"
	"</font></center>";
retval+="</font></body></html>";
return retval;
}

string action_dropdown(string mode, object id){
  string retval="";
   if(id->variables->commit){
   object privs=Privs("iVend: Copying store files ");
   rm(CONFIG->root + "/db/" + id->variables->edit);
   Stdio.write_file(CONFIG->root + "/db/" + id->variables->edit,
	id->variables->contents);
   privs=0;
   }
   if(id->variables->delete){
    object privs=Privs("iVend: deleting dropdown file");
    rm(CONFIG->root + "/db/" + id->variables->delete);
    privs=0;
   }
  retval+="<font face=helvetica,arial>";
  if(!id->variables->edit){
    array f=get_dir(CONFIG->root + "/db");
    if(sizeof(f)>0)
      retval+="You have configured dropdown boxes for the following "
	"Table : Fields:<p><ul>";
    foreach(f, string file){
     if(file!="CVS")
      retval+="<li><a href=\"./?edit=" +  file + "\">" +
 	 file +"</a> <font size=1>(<a href=./?delete=" + file +
	 ">Delete</a>)</font>\n";
    }

    if(sizeof(f)>0) retval+="</ul>";
    else retval+="You have not configured any dropdowns yet.<p>";
    retval+="Create New Dropdown:<br>\n"
     "<form action=./>\n";
//     "<select name=edit>\n";

    retval+="<input name=edit type=text size=15 value=\"table.field\"> "
//"</select>"
"<input type=submit value=Add></form>\n";
  }
  else { 
    retval+="Editing " + id->variables->edit + ":<p>";
    retval+="<form action=\"./\">\n"
	"<input type=hidden name=edit value=\"" + id->variables->edit 
	+ "\">\n";
    string f=Stdio.read_file(CONFIG->root + "/db/" + id->variables->edit);
    retval+="<textarea name=contents rows=15 cols=80 wrap>" + (f||"") +
	"</textarea>\n";
    retval+="<input type=submit name=commit value=\"Commit\"></form>\n";
  }
  return retval;
}

mixed action_template(string mode, object id){
  string retval="";
  if(id->variables->delete){
   object privs=Privs("iVend: Copying store files ");
   if(id->variables->delete=="DEFAULT") {
     mv(CONFIG->root + "/html/" + id->variables->type + "_template.html",
	CONFIG->root + "/html/" + id->variables->type + "_template.html~");
    } else {
     mv(CONFIG->root + "/templates/" + id->variables->delete + ".html",
	CONFIG->root + "/templates/" + id->variables->delete + ".html~");
    }
   array f=Stdio.read_file(CONFIG->root + "/db/groups.template")/"\n";
   f-=({""});
   f-=({id->variables->delete});
//   f=Array.uniq(f);
   rm(CONFIG->root + "/db/groups.template");
   Stdio.write_file(CONFIG->root + "/db/groups.template", f*"\n");

   f=Stdio.read_file(CONFIG->root + "/db/products.template")/"\n";
   f-=({""});
   f-=({id->variables->delete});
//   f=Array.uniq(f);
   rm(CONFIG->root + "/db/products.template");
   Stdio.write_file(CONFIG->root + "/db/products.template", f*"\n");
   privs=0;
  
  }
  if(id->variables->commit){
   object privs=Privs("iVend: Copying store files ");
   if(id->variables->create){
   array f=Stdio.read_file(CONFIG->root + "/db/" + id->variables->type + "s.template")/"\n";
   f-=({""});
   f-=({id->variables->edit});
   f+=({id->variables->edit});
//   f=Array.uniq(f);
   rm(CONFIG->root + "/db/" + id->variables->type + "s.template");
   Stdio.write_file(CONFIG->root + "/db/" + id->variables->type +
    "s.template", f*"\n");
    
    }

   if(id->variables->edit=="DEFAULT") {
     mv(CONFIG->root + "/html/" + id->variables->type + "_template.html",
	CONFIG->root + "/html/" + id->variables->type + "_template.html~");

     Stdio.write_file(CONFIG->root + "/html/" + id->variables->type +
	"_template.html", id->variables->contents);
    } else {
     mv(CONFIG->root + "/templates/" + id->variables->edit + ".html",
	CONFIG->root + "/templates/" + id->variables->edit + ".html~");
     Stdio.write_file(CONFIG->root + "/templates/" + id->variables->edit +
	".html", id->variables->contents);
    }
   privs=0;
   }
  if(!id->variables->edit){
    array f=(Stdio.read_file(CONFIG->root +
	"/db/groups.template")||"")/"\n";
    f-=({""});
    if(sizeof(f)>0)
      retval+="You have configured the following group templates:<p><ul>";
    foreach(f, string file){
     if(file!="CVS") {
      retval+="<li><a href=\"./?edit=" + file  + "&type=group\">" +
 	file +"</a>";
      if(file!="DEFAULT")
       retval+="<font size=1>( <a href=\"./?delete="+ file +"&type=group" 
	"\">Delete</a> )</font>\n";
      }
    }

    if(sizeof(f)>0) retval+="</ul>";
    else retval+="You have not configured any group templates yet.<p>";

    f=(Stdio.read_file(CONFIG->root +
"/db/products.template")||"")/"\n";
    f-=({""});
    
    if(sizeof(f)>0)
      retval+="You have configured the following product templates:<p><ul>";
    foreach(f, string file){
     if(file!="CVS")
      retval+="<li><a href=\"./?edit=" + file  + "&type=product\">" +
 	file +"</a>\n";
      if(file!="DEFAULT")
       retval+="<font size=1>( <a href=\"./?delete="+ file +"&type=product" 
	"\">Delete</a> )</font>\n";
    }

    if(sizeof(f)>0) retval+="</ul>";
    else retval+="You have not configured any product templates yet.<p>";
   retval+="<p>Create a new template:<br>\n" 
    "<form action=./>\n"
    "<select name=type><option value=group>Group\n"
    "<option value=product>Product\n</select>\n"
    " <input type=text size=20 name=edit> \n"
    " <input type=hidden value=1 name=create> \n"
    "<input type=submit value=Create></form>\n";
  }
  else { 
    retval+="Editing " + capitalize(id->variables->type) + " template " +
	id->variables->edit + ":<p>";
    retval+="<form action=\"./\">\n"
	"<input type=hidden name=edit value=\"" + id->variables->edit 
	+ "\">\n"
	"<input type=hidden name=type value=\"" + id->variables->type 
	+ "\">\n";
  string fy="";
    perror(CONFIG->root + "/html/" +
	id->variables->type + "_template.html\n");
  if(id->variables->edit=="DEFAULT")
    fy=Stdio.read_file(CONFIG->root + "/html/" +
	id->variables->type + "_template.html");
   else
    fy=Stdio.read_file(CONFIG->root + "/templates/" +
	id->variables->edit + ".html");
   if(id->variables->create)
    retval+="<input type=hidden name=create value=1>\n";

   retval+="<noparse><textarea name=contents rows=15 cols=80 wrap>" 
	+ (fy||"<html>\n</html>") + "</textarea></noparse><br>\n"
        "<input type=submit name=commit value=\"Commit\"></form>\n";
  }
  return http_string_answer(retval);
}

int saved=1;

string action_preferences(string mode, object id){
  string retval="";

  // we haven't selected a module, so show the options.

  if(!id->variables->_module) {
     retval+="<obox title=\"<font face=helvetica,arial>Preferences</font>\">\n"
	"<font face=helvetica,arial>\n"
	"To edit preferences for a particular module, please "
	"select the module from the list below.<p><ul>";
     int have_prefs=0;
     foreach(sort(indices(MODULES)), string m){
       array p=({});
       
       if(MODULES[m]->query_preferences && functionp(MODULES[m]->query_preferences))
	 p=MODULES[m]->query_preferences(id);

       if(sizeof(p)!=0) {
           retval+="<li><a href=\"./?_module=" + m +
             "\">" + MODULES[m]->module_name + "</a><br>";
           have_prefs=1; 
      }
     }
       if(!have_prefs)
           retval+="Sorry, there are no preference options available.";
       retval+="</ul><p></font></obox>";
  }

else {

// show the preference options for this module.

// each preference should contain the following elements:
//
//
//  0: the variable name (no spaces)
//  1: a short description of the variable
//  2: help text
//  3: variable type
//  4: default value (optional)
//  5: a string or array containing valid values (optional)

array  p=MODULES[id->variables->_module]->query_preferences(id);
if(sizeof(p)==0) return "";
mapping pton=([]);
foreach(p, array pref){
  pton+=([pref[0]: pref]);
}
if(!CONFIG_ROOT[id->variables->_module])
  CONFIG_ROOT[id->variables->_module]=([]);
if(!id->variables->_varname) {

  retval+="<obox title=\"<font face=helvetica,arial>" +
	id->variables->_module + "</font>\"><font face=helvetica,arial>";
    foreach(p, array pref){

      retval+=(pref[3]!=VARIABLE_UNAVAILABLE?"<a href=\"./?_module=" +
id->variables->_module +
		"&_varname=" + pref[0] + "\">" + pref[1] + "</a>:" :
"<font color=gray>" + pref[0] +"</font>: ")
	+ (CONFIG_ROOT[id->variables->_module]?
(arrayp(CONFIG_ROOT[id->variables->_module][pref[0]])? 
(CONFIG_ROOT[id->variables->_module][pref[0]]*", ")
:CONFIG_ROOT[id->variables->_module][pref[0]]):"")
+ 
	"<br>";

    }

    retval+="</font></obox>";

  }

  else {  // we've got the varname specified.

  if(id->variables->_action=="Cancel") {

  mapping z;
object privs=Privs("iVend: Writing Config File ");
z=Config.read(Stdio.read_file(id->misc->ivend->this_object->query("configdir")+
  CONFIG->config));
privs=0;

CONFIG_ROOT[id->variables->_module][id->variables->_varname]=z[id->variables->_module][id->variables->_varname];
id->variables[id->variables->_varname]=CONFIG_ROOT[id->variables->_module][id->variables->_varname];
  }


if(id->variables[id->variables->_varname])
switch(pton[id->variables->_varname][3]){  
case VARIABLE_INTEGER: 
	int dx;
	if(sscanf(id->variables[id->variables->_varname],"%d",dx)!=1) {
	  retval+="<b>You must supply an integer value for this preference.</b><p>";
	id->variables[id->variables->_varname]=id->variables["_" + 
		id->variables->_varname];
	}

  break;
case VARIABLE_FLOAT: 
	float d;
	if(sscanf(id->variables[id->variables->_varname],"%f",d)!=1) {
	  retval+="<b>You must supply a float value for this preference.</b><p>";
	id->variables[id->variables->_varname]=id->variables["_" + 
		id->variables->_varname];
	}

  break;

  }

  if(id->variables->_action=="Apply" || id->variables->_action=="Save") {


    if(id->variables[id->variables->_varname]!=
	id->variables["_" + id->variables->_varname]) {
    if(pton[id->variables->_varname][3]==VARIABLE_MULTIPLE) {
m_delete(CONFIG_ROOT[id->variables->_module], id->variables->_varname);
catch(CONFIG_ROOT[id->variables->_module][id->variables->_varname]=id->variables[id->variables->_varname]/"\000");
	}
    else
    CONFIG_ROOT[id->variables->_module][id->variables->_varname]=
	id->variables[id->variables->_varname];
    saved=0;
    }
  }

  if(id->variables->_action=="Save" && !saved) {

  object privs=Privs("iVend: Writing Config File ");
Config.write_section(id->misc->ivend->this_object->query("configdir")+
  CONFIG->config, id->variables->_module,
	CONFIG_ROOT[id->variables->_module]);
privs=0;
  saved=1;

  }

  retval+="<obox><title><font face=helvetica,arial><a href=\"" 
	"?_module="+ id->variables->_module + "\">" +
	id->variables->_module + "</a> : " +
	pton[id->variables->_varname][1]
        + "</font></title><font face=helvetica,arial>"
	  "<form method=post action=\"./?_module=" +
	  id->variables->_module + 
	  "&_varname=" + id->variables->_varname + "\">\n";

    retval+=(pton[id->variables->_varname][2] ||"") + "<br>";

    switch(pton[id->variables->_varname][3]){
      case VARIABLE_UNAVAILABLE:
        retval+="This option is currently unavailable.";
      break;

      case VARIABLE_INTEGER:
	retval+="<input type=hidden name=\"_" +id->variables->_varname
	  + "\" value=\"" +
	( CONFIG_ROOT[id->variables->_module][id->variables->_varname]
	 || "~BLANK_VALUE~" ) + "\">\n";
	retval+="<input type=text size=20 name=\"" +
	  id->variables->_varname + "\" value=\"" +
	( CONFIG_ROOT[id->variables->_module][id->variables->_varname]
                || pton[id->variables->_varname][4] || "" ) + "\">\n";
	retval+=" <i>(An Integer Value)</i><p>"; 
      break;

      case VARIABLE_FLOAT:
	retval+="<input type=hidden name=\"_" +id->variables->_varname
	  + "\" value=\"" +
	( CONFIG_ROOT[id->variables->_module][id->variables->_varname]
	 || "~BLANK_VALUE~" ) + "\">\n";
	retval+="<input type=text size=20 name=\"" +
	  id->variables->_varname + "\" value=\"" +
	( CONFIG_ROOT[id->variables->_module][id->variables->_varname]
                || pton[id->variables->_varname][4] || "" ) + "\">\n";
	retval+=" <i>(A Float Value)</i><p>"; 
      break;

      case VARIABLE_STRING:
	retval+="<input type=hidden name=\"_" +id->variables->_varname
	  + "\" value=\"" +
	( CONFIG_ROOT[id->variables->_module][id->variables->_varname]
		|| "~BLANK_VALUE~" ) + "\">\n";
	retval+="<input type=text size=40 name=\"" +
	  id->variables->_varname + "\" value=\"" +
	( CONFIG_ROOT[id->variables->_module][id->variables->_varname]
                || pton[id->variables->_varname][4] || "" ) + "\">\n";
	retval+=" <i>(A String)</i><p>"; 
      break;

      case VARIABLE_MULTIPLE:
      case VARIABLE_SELECT:

	retval+="<input type=hidden name=\"_" + id->variables->_varname
	  + "\" value=\"" + ( CONFIG_ROOT[id->variables->_module] && 
CONFIG_ROOT[id->variables->_module][id->variables->_varname]?
(arrayp(CONFIG_ROOT[id->variables->_module][id->variables->_varname])?
	(CONFIG_ROOT[id->variables->_module][id->variables->_varname] *
"\000"):CONFIG_ROOT[id->variables->_module][id->variables->_varname])
               :"~BLANK_VALUE~") + "\">\n";

	retval+="<SELECT " + 
	  (pton[id->variables->_varname][3]==VARIABLE_MULTIPLE? 
		"MULTIPLE SIZE=5":"") +
          " NAME=\"" +
	  id->variables->_varname + "\">";
	array selected_options=({});

if(arrayp(CONFIG_ROOT[id->variables->_module][id->variables->_varname]))
 selected_options=CONFIG_ROOT[id->variables->_module][id->variables->_varname];
else
if(zero_type(CONFIG_ROOT[id->variables->_module][id->variables->_varname])==1)
 selected_options=({pton[id->variables->_varname][4]});
else
selected_options=({CONFIG_ROOT[id->variables->_module][id->variables->_varname]});
	multiset selected=mkmultiset(selected_options);
        foreach(pton[id->variables->_varname][5], string choice){

	  retval+="<option " +(selected[choice]?"SELECTED":"") +">" +
choice
	+ "\n";
	}
	retval+="</select><p>";

      break;    

    }

    retval+="<input type=submit name=_action value=\"Cancel\"> "
	"<input type=submit name=_action value=\"Apply\">\n";
    if(!saved)
      retval+="<input type=submit name=_action value=\"Save\">";
    retval+="</form></font></obox>";

  }

}

  return retval;

}

string action_useradmin(string mode, object id){
 string retval="";

 if(!id->variables->mode){

   array r=DB->query("SELECT * FROM admin_users order by level desc");

   if(!r || sizeof(r)<1) retval+="No Users Defined.";
   else {
     retval+="<table>"
	"<tr><th>Username</th><th>Real Name</th><th>Security " 
	"Level</th></tr>\n";
     foreach(r, mapping user)
      retval+="<tr><td><a href=\"./?username=" + user->username +
	"&mode=view\">" 
	+ user->username + "</a></td><td>" + user->real_name +
      "</td><td align=right>" + user->level + "</td>"
	"<td><font size=1><a href=\"./?username=" + user->username + 
	"&mode=delete\">Delete</a></td></tr>\n";

    retval+="</table>\n";
   }

   retval+="<p><a href=\"./?mode=newuser\">Add New User</a>";
 }

 else {

  switch(id->variables->mode){

   case "delete":
    if(id->variables->username)
      {
        DB->query("DELETE FROM admin_users WHERE username='" +
	  id->variables->username + "'");
	retval+="User <b>" + id->variables->username + "</b>"
		" deleted successfully.<p>"
		"<a href=\"./\">Click Here to continue.</a>";
      }
   break;
   case "newuser":
    if(id->variables->add)
     {
	if(id->variables->username=="" || id->variables->email=="" ||
		id->variables->password=="")
		retval+="A required value is missing.";
        else {
       DB->query("INSERT INTO admin_users VALUES('" +
upper_case(id->variables->username) + "','" + id->variables->real_name +
"','" + id->variables->email + "','" + crypt(id->variables->password) +
"'," + (id->variables->level||"0") + ")");     
         retval+="User <b>" + upper_case(id->variables->username) + 
		"</b> added successfully.";
        }
	retval+="<p><a href=\"./?mode=newuser\">Click Here to continue.</a>";

     }
    else 
     {
		 retval+="<form action=\"./\" method=post>"
			"<input type=hidden name=add value=\"add\">"
			"<input type=hidden name=mode value=\"newuser\">"
			"<table>\n"
			"<tr><th>Username</th>\n"
			"<td>"
			"<input type=text size=16 name=username value=\""
			"\">"
			"</td></tr>\n"
			"<tr><th>Real Name</th>\n"
			"<td><input type=text size=40 name=real_name " 
			"value=\"\"></td></tr>\n"
			"<tr><th>Email</th>\n"
			"<td><input type=text size=40 name=email "
			"value=\"\"></td></tr>\n"
			"<tr><th>Password</th>\n"
			"<td><input type=text size=16 name=password "
			"value=\"\"></td></tr>\n"
			"<tr><th>Security Level</th>\n"
			"<td><select name=level>"
			"<option>0\n"
			"<option>1\n"
			"<option>2\n"
			"<option>3\n"
			"<option>4\n"
			"<option>5\n"
			"<option>6\n"
			"<option>7\n"
			"<option>8\n"
			"<option>9\n"
			"</select></td></tr>\n"
			"</table><p>"
			"<input type=submit value=\"Add User\">"
			"</form>";
     }
   break;
   case "view":
    if(id->variables->username)
	{
	 array r=DB->query("SELECT * FROM admin_users WHERE username='" +
	   id->variables->username + "'");
	 if(r && sizeof(r)==1) 
		{
		 if(id->variables->update){
			if(r[0]->password!=id->variables->password)
			  id->variables->password=crypt(id->variables->password);
			DB->query("UPDATE admin_users SET " 
				"real_name='" +
DB->quote(id->variables->real_name) + "', email='" + id->variables->email
+ "', password='" + id->variables->password + "', level=" +
	(id->variables->level||"0") + " WHERE username='" +
id->variables->username + "'");
retval+="User updated successfully.<p>";
	 r=DB->query("SELECT * FROM admin_users WHERE username='" +
	   id->variables->username + "'");
			}
		 retval+="<form action=\"./\" method=post>"
			"<input type=hidden name=username value=\"" +
			r[0]->username + "\">"
			"<input type=hidden name=mode value=\"view\">"
			"<input type=hidden name=update value=\"update\">"
			"<table>\n"
			"<tr><th>Username</th>\n"
			"<td>" + r[0]->username + "</td></tr>\n"
			"<tr><th>Real Name</th>\n"
			"<td><input type=text size=40 name=real_name " 
			"value=\"" + r[0]->real_name + "\"></td></tr>\n"
			"<tr><th>Email</th>\n"
			"<td><input type=text size=40 name=email "
			"value=\"" + r[0]->email + "\"></td></tr>\n"
			"<tr><th>Password</th>\n"
			"<td><input type=password name=password "
			"value=\"" + r[0]->password + "\"></td></tr>\n"
			"<tr><th>Security Level</th>\n"
			"<td><input type=text size=2 name=level "
			"value=\"" + r[0]->level + "\"></td></tr>\n"
			"</table><p>"
			"<input type=submit value=\"Update User\">"
			"</form>";
		}
	 else retval+="Unable to find user <b>" + id->variables->username
		+ "</b>.<p>"
		"<a href=\"./\">Click Here to continue.</a>";
	}
   break;

  }
 }
 return retval;
}

string action_reloadstore(string mode, object id){

	string retval="";
	id->misc->ivend->this_object->stop_store();
	id->misc->ivend->this_object->start_store();
         retval+="Store Restarted Successfully.<p>" +
                return_to_admin_menu(id); 
//	ADMIN_FLAGS=NO_BORDER;
	return retval;

}

mixed register_admin(){

return ({
	([ "mode": "menu.main.Store_Maintenance.User_Admin",
		"handler": action_useradmin,
		"security_level": 8 ]),
	([ "mode": "menu.main.Store_Maintenance.Reload_Store",
		"handler": action_reloadstore,
		"security_level": 9 ]),
	([ "mode": "menu.main.Store_Maintenance.Preferences",
		"handler": action_preferences,
		"security_level": 9 ]),
	([ "mode": "menu.main.Store_Administration.Drop_Down_Menus",
		"handler": action_dropdown,
		"security_level": 5 ]),
	([ "mode": "menu.main.Store_Administration.Templates",
		"handler": action_template,
		"security_level": 5 ]),
	([ "mode": "add.product.Item_Options",
		"handler": action_itemoptions,
		"security_level": 0 ]),
	([ "mode": "getmodify.product.Item_Options",
		"handler": action_itemoptions,
		"security_level": 0 ])
	});


}

mapping query_tag_callers(){
  
  return (["itemoptions": tag_itemoptions]);

}

mapping query_event_callers() {

  return (["admindelete": event_admindelete ]);
}

mixed query_preferences(object id){

return ({

        ({"email", "Administrator Email",
        "Email address of store administrator; emails are addressed from this email.",
        VARIABLE_STRING,
        "address@mydomain.com"
        }),  

        ({"productnamefield", "Product Name Field",
        "Name of field in products table that contains a product name.",
        VARIABLE_STRING,
        "name"
        }),  

        ({"minqtyfield", "Minimum Quantity Field",
        "Name of field in products table that contains the minimum "
		"quantity of a product available for purchase at a time.",
        VARIABLE_STRING,
        "min_order_qty"
        })

});

}
