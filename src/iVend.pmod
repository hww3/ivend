#include "include/messages.h"
// #define perror(X) werror(X)
// for translations

class config {


mapping (string:mixed) config_setup=([]);

int load_config_defs(string defs){
if(!(defs)) return 0;
if(defs[0..3]!="iVcd") return 0;
defs=defs[search(defs,"\n")+1..];
array entries=defs/"\n\n";
if(sizeof(entries)<1) return 0;	// no entries in this file...
for(int i=0; i<sizeof(entries); i++){
  array lines=entries[i]/"\n";
  string name;
  for(int j=0; j<sizeof(lines); j++){
    array v=lines[j]/"=";
    if(sizeof(v)!=2) continue;
    switch((v[0]-"$")){
      case "varname":
      config_setup+=([v[1]:([])]);
      name=(v[1]-"$");
      break;

      default:
      config_setup[name]+=([ (v[0]-"$"):v[1] ]);
      }
    }
  }
return 1;
}

mapping scan_modules(string mtype, string moddir){
mapping(string:string) m=([]);
array d=get_dir(moddir);
string name;
string desc;
string type;
program p;
foreach(d,name){
  if(name=="CVS") continue;
  if(catch(p=compile_file(moddir+"/"+name)))
  { perror("iVend error: can't compile "+name+"\n");
  continue;
  }
  desc=p()->module_name;
  type=p()->module_type;
  
if(desc && type==mtype)
  m+=([name:desc]);
  }
return m;
}

string|int genform(void|mapping config, void|string lang, void|string moddir){
if(!lang) lang="en";
if(!config) config=([]);
string retval="";
if(sizeof(config_setup)<1){perror("config setup < 1\n"); return 0;}
array vars=sort(indices(config_setup));
for(int i=0; i<sizeof(vars); i++){
  write(vars[i]);
  retval+="<tr>\n<td>";
  retval+=config_setup[vars[i]][lang+"name"]+" &nbsp \n</td><td>";
  switch(config_setup[vars[i]]->type){

    case "multiple":
    retval+="<select name=\""+vars[i]+"\">\n";
    string opt;
    foreach(config_setup[vars[i]]->options/"|",opt) {
       retval+="<option";
       if(config && opt==config[vars[i]])
	 retval+=" selected";
       else if(opt==config_setup[vars[i]]->default_value)
         retval+=" selected";
       retval+=">"+opt+"\n";
       }
    retval+="</select>";
    break;

    case "password":
    if(!stringp(config))
      retval+="<input type=\"password\" name=\""+(vars[i]||"")+"\" value=\""+
      (config[vars[i]]||config_setup[vars[i]]->default_value ||"")+"\">";      
    else
      retval+="<input type=\"password\" name=\""+(vars[i]||"")+"\" value=\""+
      (config_setup[vars[i]]->default_value ||"")+"\">";
    break;

    case "module":
      retval+="<select name=\""+ (vars[i]||"")+"\">\n";
      string module;
        mapping modules=
	  scan_modules(config_setup[vars[i]]->module_type,moddir);

      foreach(indices(modules), module){
        
	if(mappingp(config) && config[vars[i]]==module)
	retval+="<option selected value=\""+module+"\">"
	  +modules[module]+"\n";
	else retval+="<option value=\""+module+"\">"
	  +modules[module]+"\n";
	  }
      retval+="</select>\n";
    break;

    case "string":
    default:
    if(!stringp(config))
      retval+="<input type=\"text\" name=\""+(vars[i]||"")+"\" value=\""+
      ( config[vars[i]] ||
	config_setup[vars[i]]->default_value ||"")+"\">";      
    else
      retval+="<input type=\"text\" name=\""+(vars[i]||"")+"\" value=\""+
      (config_setup[vars[i]]->default_value ||"")+"\">";
    break;

    }
  retval+="</td>\n</tr>\n"
          "<tr>\n<td colspan=2><i><font size=-1 face=helvetica,arial>\n"
          +(config_setup[vars[i]][lang+"description"]||"")
          +"</i></font>\n<p></td></tr>\n";

  }

return retval;
}

void create(){
return;
}


}


class db {

inherit Sql.sql;

// object s;	//  sql db connection...

string host;
string db;
string user;
string password;

inherit "roxenlib";

void create(mixed host, mixed db, mixed user, mixed password){

::create(host, db, user, password);

}

mixed list_fields(string t) {

  perror("iVend.db: List_fields\n");
  return ::list_fields(t);
}

mixed query(string q){

//  perror("iVend.db: Query\n");
  return ::query(q);

}



string make_safe(string s){
if(!s || !stringp(s)) return s;
s=(string)s;
return replace( (s || ""),({"'","\""}),({"\\'","\\\""}));

}     

mixed insert_id(){

  
  if(functionp(::master_sql->insert_id))
    return ::master_sql->insert_id();

  else return -1;

}

mixed showmatches(string type, string id, string field) {

string retval;

string q="SELECT " + field + ",name FROM " + type + "s WHERE name like '%" 
  + id + "%' or " + field +" like '%" + id + "%' group by "+ field;

array r=query(q);

if(sizeof(r)==0) return 0; 

retval="<input type=hidden name=type value=" + type +">\n"
  "<table><tr><td>Delete?</td><td>" + field +"</td><td>Name</td></tr>";

foreach(r, mapping row)
  retval+="<tr><td><input type=checkbox name=" + field +" value=\"" +
	row[field] + 
    "\"></td><td> " + row[field] + "</td><td>" + row->name + "</td></tr>\n";

retval+="</table>";

return retval;

}

mixed addentry(object id, string referrer){
array errors=({});
array(mapping(string:mixed)) r=list_fields(id->variables->table);
for (int i=0; i<sizeof(r); i++)
	r[i]->name=lower_case(r[i]->name);  // lower case it all...

if(id->misc->ivend->clear_oldrecord){	// get rid of existing record.
array index=query("SHOW INDEX FROM " + id->variables->table );

if(sizeof(index)==1 && index[0]->Non_unique=="0") {
//  perror("UNIQUE KEY ON " + id->variables->table + "\n");
  query("DELETE FROM " + id->variables->table + " WHERE " +
	index[0]->Column_name + "='" +
	id->variables[lower_case(index[0]->Column_name)] + "'");
  }

else if(sizeof(index)>1)	// we've got keys in this table!
  {
//  perror("MULTIPLE KEY ON " + id->variables->table + "\n");

  string q="DELETE FROM " + id->variables->table + " WHERE " + 
	index[0]->Column_name + "='" +
	id->variables[lower_case(index[0]->Column_name)] + "' ";
  for(int i=1; i<sizeof(index); i++)
     q+="AND " + index[i]->Column_name + "='" + 
	id->variables[lower_case(index[i]->Column_name)] + "' ";
  query(q);
  }

else perror("Got NON-UNIQUE SINGLE FIELD KEY on " + id->variables->table +
"\n");
}

string q="INSERT INTO "+id->variables->table+" VALUES(";
for (int i=0; i<sizeof(r); i++){
	r[i]->name=lower_case(r[i]->name);  // lower case it all...

  if(lower_case(r[i]->name[0..4])=="image"){

  if(sizeof(id->variables[r[i]->name])>3)
    {

string f=	id->variables[ r[i]->name+".filename"];
if(f){
string e= extension(f);
    string filename=id->variables->id+
	r[i]->name[5..]+"."+e;


    rm(filename);
if(file_stat(id->misc->ivend->config->root+"/images/"+id->variables->table));
else mkdir(id->misc->ivend->config->root+ "/images/" + id->variables->table);
Stdio.write_file(id->misc->ivend->config->root+"/images/"+
	id->variables->table+"/"+filename,id->variables[r[i]->name]);
    q+="'"+filename+"',";
}
else perror("ARGH! Can't get image's original filename from browser!\n");
    }
  else q+="NULL,";
  }

 else if(id->variables[r[i]->name]=="" && r[i]->flags["not_null"])
    errors+=({replace(r[i]->name,"_"," ")+" needs a value."});

 else if(r[i]->type=="string" || r[i]->type=="var string" || 
    r[i]->type=="enum" || r[i]->type=="blob" ||
	stringp(r[i]->name)
	) q+="'"+make_safe(id->variables[r[i]->name])+"',";


  else q+=(id->variables[r[i]->name]||"NULL")+",";

  }
q=q[0..sizeof(q)-2]+")";
if (sizeof(errors)>0) return errors;
query(q);
 if(id->variables->jointable) {
 array jointable;
catch(jointable=id->variables[id->variables->jointable]/"\000");
if(jointable)
 for(int i=0; i<sizeof(jointable); i++){
    q="REPLACE INTO "
      + id->variables->joindest +" VALUES('"+
	jointable[i]+ "','"
        +id->variables->id+"')";
    query(q);
    }
 }
return 1;

}

mixed modifyentry(object id, string referrer){
array errors=({});
array(mapping(string:mixed)) r=list_fields(id->variables->table);
string q="UPDATE "+id->variables->table+" SET ";
for (int i=0; i<sizeof(r); i++){
	r[i]->name=lower_case(r[i]->name);  // lower case it all...

  if(lower_case(r[i]->name[0..4])=="image"){

  if(sizeof(id->variables[r[i]->name])>3)
    {

	string f=id->variables[ r[i]->name+".filename"];
	if(f){
		string e= extension(f);
    	string filename=id->variables->id+
		r[i]->name[5..]+"."+e;
        rm(filename);
if(file_stat(id->misc->ivend->config->root+"/images/"+id->variables->table));
else mkdir(id->misc->ivend->config->root+ "/images/" + id->variables->table);

rm(id->misc->ivend->config->root + "/images/" + id->variables->table + "/" +
filename );


Stdio.write_file(id->misc->ivend->config->root+"/images/"+
	id->variables->table+"/"+filename,id->variables[r[i]->name]);
 // perror("Wrote " + sizeof ( id->variables[r[i]->name] ) + " to " +
// id->misc->ivend->config->root + "/images/" + id->variables->table + "/"
// + filename +  ".\n");
    q+=r[i]->name+"='"+filename+"',";
}
else perror("ARGH! Can't get image's original filename from browser!\n");
    }
  }

 else if(id->variables[r[i]->name]=="" && r[i]->flags["not_null"])
    errors+=({replace(r[i]->name,"_"," ")+" needs a value."});

 else if(r[i]->type=="string" || r[i]->type=="var string" || 
    r[i]->type=="enum" || r[i]->type=="blob" ||
	stringp(r[i]->name)
	) q+=r[i]->name+"='"+make_safe(id->variables[r[i]->name])+"',";


  else q+=r[i]->name+"="+(id->variables[r[i]->name]||"NULL")+",";

  }
q=q[0..sizeof(q)-2]+" WHERE " + 
	id->misc->ivend->keys[id->variables->table] 
+"='" + id->variables[id->misc->ivend->keys[id->variables->table]] +
	"'";
// if (sizeof(errors)>0) return errors;
// perror("running query\n" + q);
query(q);
 if(id->variables->jointable) {
 array jointable;
catch(jointable=id->variables[id->variables->jointable]/"\000");
// perror(id->variables[id->variables->jointable]+"\n\n");
 query("DELETE FROM " + id->variables->joindest + " WHERE " +
(id->variables->table-"s") +"_id='" + id->variables->id
+ "'");
if(jointable && sizeof(jointable)>0)
 for(int i=0; i<sizeof(jointable); i++){
    q="REPLACE INTO "
      + id->variables->joindest +" VALUES('"+
	jointable[i]+ "','"
        +id->variables->id+"')";
    query(q);
    }
 }
return 1;

}

string generate_query(mapping data, string table, object s){

array(mapping(string:mixed)) r=s->list_fields(table);
for (int i=0; i<sizeof(r); i++)
	r[i]->name=lower_case(r[i]->name);  // lower case it all...

string q="REPLACE INTO "+table+" VALUES(";
for (int i=0; i<sizeof(r); i++){

 if(r[i]->type=="string" || r[i]->type=="var string" || 
    r[i]->type=="enum" || r[i]->type=="blob" ||
	stringp(r[i]->name)
	) q+="'"+make_safe(data[r[i]->name])+"',";


  else q+=(data[r[i]->name]||"NULL")+",";

  }
q=q[0..sizeof(q)-2]+")";

return q;

}

string|int gentable(string table, string return_page, 
    string|void jointable,string|void joindest , object|void id, mapping|void record){
string retval="";
array(mapping(string:mixed)) r=list_fields(table);

array vals;

retval+="<FORM ACTION=\""+return_page+"\" "
"ENCTYPE=multipart/"
	"form-data "
"method=post>\n"
        "<INPUT TYPE=HIDDEN NAME=table VALUE=\""+table+"\">\n"
        "<INPUT TYPE=HIDDEN NAME=mode VALUE=\""+
	(record?"domodify":"doadd") +"\">\n";
        "<TABLE>\n";

if(!record) record=([]);
// perror(sprintf("%O",record));
for(int i=0; i<sizeof(r);i++){          // Generate form from schema
if(record[r[i]->name]) record[lower_case(r[i]->name)]=record[r[i]->name];
r[i]->name=lower_case(r[i]->name);
// perror("existing data for " + r[i]->name +": " + record[r[i]->name] + "\n");
if(r[i]->name[0..4]=="image"){
    retval+="<TR>\n"
    "<TD VALIGN=TOP ALIGN=RIGHT><FONT FACE=helvetica,arial SIZE=-1>\n"
    +replace(r[i]->name,"_"," ")+
    "</FONT></TD>\n"
    "<TD>\n";
   if (record[r[i]->name])
	retval+="<img src=\"images/" + table + "/" + record[r[i]->name] 
	+ "\"><br>";
	retval+="<input type=file name=\""+r[i]->name+"\"></td></tr>\n";

}

else if(lower_case(r[i]->name)=="taxable"){

    retval+="<TR>\n"
    "<TD VALIGN=TOP ALIGN=RIGHT><FONT FACE=helvetica,arial SIZE=-1>\n"
    +"taxable?"+
    "</FONT></TD>\n"
    "<TD>\n"
    "<input type=checkbox name=taxable value=Y " +
	(record[r[i]->name]!="Y"?"":"CHECKED") +">\n";

}

else if(r[i]->type=="blob"){
    retval+="<TR>\n"
    "<TD VALIGN=TOP ALIGN=RIGHT><FONT FACE=helvetica,arial SIZE=-1>\n"
    +replace(r[i]->name,"_"," ")+
    "</FONT></TD>\n"
    "<TD>\n"
    "<TEXTAREA NAME=\""+r[i]->name+"\" COLS=70 ROWS=5>"
	+ (record[r[i]->name]||"")+ "</TEXTAREA>\n";
        }

else if(r[i]->type=="decimal" || r[i]->type=="float"){
    retval+="<TR>\n"
    "<TD VALIGN=TOP ALIGN=RIGHT><FONT FACE=helvetica,arial SIZE=-1>\n"
    +replace(r[i]->name,"_"," ")+
    " <b>$</b></FONT></TD>\n"
    "<TD>\n"
    "<INPUT TYPE=TEXT NAME=\""+r[i]->name+"\" SIZE="+r[i]->length+
    " MAXLEN="+r[i]->length+" VALUE=\"" 
	+ (record[r[i]->name] ||"") +"\">\n";
    
    if(r[i]->flags->not_null) retval+="&nbsp;<FONT FACE=helvetica,arial "
      "SIZE=-1><I> "+ REQUIRED +"\n";
        }

else if(file_stat(id->misc->ivend->config->root + "/db/" +
	lower_case(table) + 
	"_" + lower_case(r[i]->name) + ".val"))

{
    retval+="<TR>\n"
    "<TD VALIGN=TOP ALIGN=RIGHT><FONT FACE=helvetica,arial SIZE=-1>\n"
    +replace(r[i]->name,"_"," ")+
    "</FONT></TD>\n"
    "<TD>\n";

    retval+="<select name=\""+lower_case(r[i]->name)+"\">\n";

  array vals;
   if(!catch( vals=Stdio.read_file(id->misc->ivend->config->root+"/"+
	"db/"+lower_case(table)+"_"+lower_case(r[i]->name)+".val")/"\n")){
	vals-=({""});
    if(sizeof(vals)>0) {
	for(int j=0; j<sizeof(vals); j++)
	  retval+="<option " +((record &&
		record[r[i]->name]==vals[j])?"SELECTED":"")+ // this is the one.
		" value=\""+vals[j]+"\">"+vals[j]+"\n";
	}
    else retval+="<option>" + NO_OPTIONS_AVAILABLE + "\n";
   
	}
    else retval+="<option>"+ NO_OPTIONS_AVAILABLE +"\n";
    retval+="</select></td></tr>";


}


else if(r[i]->type=="var string"){
    retval+="<TR>\n"
    "<TD VALIGN=TOP ALIGN=RIGHT><FONT FACE=helvetica,arial SIZE=-1>\n"
    +replace(r[i]->name,"_"," ")+
    "</FONT></TD>\n"
    "<TD><!-- var string -->\n";


    retval+="<INPUT TYPE=TEXT NAME=\""+r[i]->name+
      "\" SIZE="+r[i]->length+" MAXLEN="+r[i]->length+" VALUE=\""
	+( record[r[i]->name]||"") + "\">\n";
    
    if(r[i]->flags->not_null) retval+="&nbsp;<FONT FACE=helvetica,arial "
      "SIZE=-1><I> "+REQUIRED+"\n";
        }

else if(r[i]->type=="string"){
    retval+="<TR>\n"
    "<TD VALIGN=TOP ALIGN=RIGHT><FONT FACE=helvetica,arial SIZE=-1>\n"
    +replace(r[i]->name,"_"," ")+
    "</FONT></TD>\n"
    "<TD><!-- string -->\n";
      
   if(r[i]["default"]=="N")
   retval+="<SELECT NAME=\""+r[i]->name+"\"><OPTION VALUE=\"N\">"
      "No\n<OPTION VALUE=\"Y\">Yes\n</SELECT>\n";
   else if(r[i]["default"]=="Y")
      retval+="<SELECT NAME=\""+r[i]->name+"\"><OPTION VALUE=\"Y\">"
        "Yes\n<OPTION VALUE=\"N\">No\n</SELECT>\n";
   else if(r[i]->flags["primary_key"] && record[r[i]->name])
     retval+="<input type=hidden NAME=\"" + r[i]->name + "\" VALUE=\"" +
	record[r[i]->name] + "\"> " + record[r[i]->name] + "\n";
   else retval+="<INPUT TYPE=TEXT NAME=\""+r[i]->name+"\" MAXLEN="
      +r[i]->length+" SIZE="+(r[i]->length)+" VALUE=\""+
	(record[r[i]->name]||"") +"\">\n";
    }       

else if(r[i]->type=="long" && r[i]->flags["not_null"]){
    retval+="<TR>\n"
    "<TD VALIGN=TOP ALIGN=RIGHT>&nbsp;</TD>\n<TD><!-- long / not null -->\n";
    retval+="<INPUT TYPE=HIDDEN NAME=\""+r[i]->name+
      "\" MAXLEN="+r[i]->length+" SIZE="+r[i]->length+" VALUE=\"NULL\">\n";

        }
else if(r[i]->type=="long"){
    retval+="<TR>\n"
    "<TD VALIGN=TOP ALIGN=RIGHT><FONT FACE=helvetica,arial SIZE=-1>\n"
    +replace(r[i]->name,"_"," ")+
    "</FONT></TD>\n<td><!-- long -->"  ;
    retval+="<INPUT TYPE=TEXT NAME=\""+r[i]->name+
      "\" MAXLEN="+r[i]->length+" SIZE="+r[i]->length+" value=\"" 
      + (record[r[i]->name] ||"") +"\">\n";

        }
 
else if(r[i]->type=="unknown")  {
    retval+="<TR>\n"
    "<TD VALIGN=TOP ALIGN=RIGHT><FONT FACE=helvetica,arial SIZE=-1>\n"
    "&nbsp; </FONT></TD>\n"
    "<TD>\n";

    retval+="<INPUT TYPE=HIDDEN NAME=\""+r[i]->name+"\" VALUE=NULL>\n";
    }

retval+="</TD>\n"
    "</TR>\n";
  }

if(jointable){

  array j=query("SELECT name,id FROM "+jointable);
  retval+="<tr><td valign=top align=right><font "
    "face=helvetica,arial size=-1>"+jointable+"</td><td>"
    "<select multiple size=5 name="+jointable+">\n";
  for(int i=0; i<sizeof(j); i++)
    retval+="<option " + ( (record->group_id &&
	  record->group_id[j[i]->id])?"SELECTED":"" ) +
	" value=\""+j[i]->id+"\">"+j[i]->name+"\n";
  retval+="</select>\n<input type=hidden name=jointable value=\""
    +jointable+"\">\n<input type=hidden name=joindest value=\""
    +joindest+"\">"
    "</td></tr>\n";

}

retval+="</TABLE>\n"
    "<INPUT TYPE=SUBMIT VALUE=\""+(sizeof(record)>0?"Modify":"Add")+"\">\n"
    "<INPUT TYPE=HIDDEN VALUE=" + return_page + ">\n"
    "</FORM>\n";

return retval;
 

}

string|int showdepends(string type, string id, string field, string|void 
field2){
string q="";
if(type=="" || id=="")
return DELETE_UNSUCCESSFUL +"\n";
string retval="";

if(type=="group"){
  q="SELECT * FROM groups WHERE "+ field
	+"='"+id+"'";
  array j=query(q);
  if(sizeof(j)!=1) return 0;
  else {
    retval+= GROUP + j[0]->id+" ( "+j[0]->name+" ) " + IS_LINKED +
      PRODUCTS +":<p>";
    q="SELECT product_groups.product_id,products.name FROM "
	"products,product_groups WHERE product_groups.group_id='"
        +id+"' AND products." + field2  +
	"=product_groups.product_id";
    j=query(q);
    if(sizeof(j)==0) retval+="<blockquote>"+ NO_PRODUCTS +"</blockquote>";
    else {
      retval+="<blockquote>\n";
      for(int i=0; i<sizeof(j); i++)
        retval+=j[i]->product_id+" ( "+j[i]->name+" )<br>";
      }
    }
  }

else if(type=="product") {
  q="SELECT " + field +  
	",name FROM products WHERE " + field + "='"+id+"'";
  array j=query(q);
  if(sizeof(j)!=1) return 0;
  else retval+="<blockquote>"+j[0][ field ] +" "
	"( "+j[0]->name+" )<br>\n";
  }

retval+="</blockquote>\n";
return retval; 
}


string dodelete(string type, string id, string field){
string q="";

if(type=="" || id=="")
return DELETE_UNSUCCESSFUL+"\n";

if(type=="group") {
  q="DELETE FROM groups WHERE " + field +
	"='"+id+"'";
  query(q);
  q="DELETE FROM product_groups WHERE group_id='"+id+"'";
  query(q);
  }

else if(type="product") {
  q="DELETE FROM products WHERE " + field +
	"='"+id+"'";
  query(q);
  q="DELETE FROM product_groups WHERE product_id='"+id+"'";
  query(q);
  }
return capitalize(type)+" "+id+ DELETED_SUCCESSFULLY +"\n";

}


string generate_form_from_db(string table, array|void exclude,
object|void id, array|void pulldown, mapping|void record){

// perror(sprintf("table: %O\n\n", table));
// perror(sprintf("exclude: %O\n\n", exclude));
// perror(sprintf("id: %O\n\n", id));
// perror(sprintf("pulldown: %O\n\n", pulldown));
// perror(sprintf("record: %O\n\n", record));

string retval="";

if(!table) return "";

if(!record) record=([]);


array(mapping(string:mixed)) r=list_fields(table);
for (int i=0; i<sizeof(r); i++)
	r[i]->name=lower_case(r[i]->name);  // lower case it all...

if(exclude)
for(int i=0; i<sizeof(exclude); i++)
  exclude[i]=lower_case(exclude[i]);
else exclude=({""});
if(pulldown) {
for(int i=0; i<sizeof(pulldown); i++)
  pulldown[i]=lower_case(pulldown[i]-" ");
  // perror("pulldown!\n");
}
else pulldown=({""});
// perror(sprintf("%O", pulldown)+"\n");
for(int i=0; i<sizeof(r);i++){		// Generate form from schema

if((r[i]->type=="string" || r[i]->type=="var string") && r[i]->length >25)
  r[i]->length=25;


if(search(exclude,lower_case(r[i]->name))!=-1) continue;

if(search(pulldown,lower_case(r[i]->name))!=-1) {
perror("doing the pulldown thing...\n");
    retval+="<tr>\n"
	"<td valign=top align=right><font face=helvetica,arial size=-1>\n"
	+replace(r[i]->name,"_"," ")+
	"</font></td>\n"
	"<td>\n";

    retval+="<select name=\""+lower_case(r[i]->name)+"\">\n";

  array vals;
   if(!catch( vals=Stdio.read_file(id->misc->ivend->config->root+"/"+
	"db/"+lower_case(table)+"_"+lower_case(r[i]->name)+".val")/"\n")){
	vals-=({""});
    if(sizeof(vals)>0) {
	for(int j=0; j<sizeof(vals); j++)
	  retval+="<option " +((record &&
		record[r[i]->name]==vals[j])?"SELECTED":"")+ // this is the one.
		" value=\""+vals[j]+"\">"+vals[j]+"\n";
	}
    else retval+="<option>" + NO_OPTIONS_AVAILABLE + "\n";
   
	}
    else retval+="<option>"+ NO_OPTIONS_AVAILABLE +"\n";
    retval+="</select></td></tr>";
    
    }

else if(r[i]->name == id->misc->ivend->keys[table]) {
	retval+="<tr>\n"
	"<td valign=top align=right><font face=helvetica,arial size=-1>\n"
	+ replace(r[i]->name, "_", " ")+
	"</font></td>\n"
	"<td><font face=helvetica,arial size=-1>" + (record[r[i]->name]
		|| ("<INPUT TYPE=TEXT NAME=\""+
        lower_case(r[i]->name)+"\" SIZE="
          +
        (r[i]->length)
        +"  VALUE=\""+  record[r[i]->name]||"" + "\">\n")) +
	"</td></tr>\n" ;
	}
else if(r[i]->type=="blob"){
	retval+="<TR>\n"
	"<TD VALIGN=TOP ALIGN=RIGHT><FONT FACE=helvetica,arial SIZE=-1>\n"
	+replace(r[i]->name,"_"," ")+
	"</FONT></TD>\n"
	"<TD>\n";

	retval+="<TEXTAREA NAME=\""
	+lower_case(r[i]->name)+"\" COLS=70 ROWS=5>"+
	record[r[i]->name]||""
	+"</TEXTAREA>\n";
	}

else if(r[i]->type=="var string"){
	retval+="<TR>\n"
	"<TD VALIGN=TOP ALIGN=RIGHT><FONT FACE=helvetica,arial SIZE=-1>\n"
	+replace(r[i]->name,"_"," ")+
	"</FONT></TD>\n"
	"<TD>\n";

	retval+="<INPUT TYPE=TEXT NAME=\""+
	lower_case(r[i]->name)+"\" SIZE="
	  +
	(r[i]->length)
	+"  VALUE=\""+ 	(record[r[i]->name]||"") + "\">\n";
	if(r[i]->flags->not_null) 
	  retval+="&nbsp;<FONT FACE=helvetica,arial SIZE=-1><I>"+REQUIRED+"\n";	
	}

else if(r[i]->type=="string"){
	retval+="<TR>\n"
	"<TD VALIGN=TOP ALIGN=RIGHT><FONT FACE=helvetica,arial SIZE=-1>\n"
	+replace(r[i]->name,"_"," ")+
	"</FONT></TD>\n"
	"<TD>\n";

	if(r[i]["default"]=="N")
	retval+="<SELECT NAME=\""+
	lower_case(r[i]->name)+"\">"
	"<OPTION VALUE=\"N\"" + ((record &&
                record[r[i]->name]=="N")?"SELECTED":"")+ 
	">No\n<OPTION VALUE=\"Y\"" +((record &&
                record[r[i]->name]=="Y")?"SELECTED":"")+
	">Yes\n</SELECT>\n";
	else if(r[i]["default"]=="Y")
	retval+="<SELECT NAME=\""
	+lower_case(r[i]->name)+"\">"
	"<OPTION VALUE=\"Y\" "+((record &&
                record[r[i]->name]=="Y")?"SELECTED":"")+">Yes\n"
	"<OPTION VALUE=\"N\"" +((record &&
                record[r[i]->name]=="N")?"SELECTED":"")+ 
	">No\n</SELECT>\n";
	else {
	  retval+="<INPUT TYPE=TEXT VALUE=\"" + (record[r[i]->name]||"") +
	"\" NAME=\""+
	lower_case(r[i]->name)+"\" SIZE="+
	(r[i]->length)+">\n";
	  if(r[i]->flags->not_null) retval+="&nbsp;<FONT FACE=helvetica,arial SIZE=-1><I> "+REQUIRED+"\n";	
	  }
	}

else if(r[i]->type=="long" && r[i]->flags["not_null"]){
	retval+="<TR>\n"
	"<TD VALIGN=TOP ALIGN=RIGHT>&nbsp;</TD>\n<TD>\n";
	retval+="<INPUT TYPE=HIDDEN NAME=\""+
	lower_case(r[i]->name)+"\" SIZE="+r[i]->length+" VALUE=NULL>\n";

	}

else if(r[i]->type=="enum" ){
    retval+="<tr>\n"
	"<td valign=top align=right><font face=helvetica,arial size=-1>\n"
	+replace(r[i]->name,"_"," ")+
	"</font></td>\n"
	"<td>\n";

    retval+="<select name=\""+lower_case(r[i]->name)+"\">\n";

  array vals;
   if(!catch( vals=Stdio.read_file(id->misc->ivend->config->root+"/"+
	"db/"+lower_case(table)+"_"+lower_case(r[i]->name)+".val")/"\n")){
	vals-=({""});
    if(sizeof(vals)>0) {
	for(int j=0; j<sizeof(vals); j++)
	  retval+="<option value=\""+vals[j]+"\""
	+((record && 
	record[r[i]->name]==vals[j])?"SELECTED":"")+">"+vals[j]+"\n";
	}
    else retval+="<option>"+ NO_OPTIONS_AVAILABLE +"\n";
   
	}
    else retval+="<option>"+ NO_OPTIONS_AVAILABLE +"\n";
    retval+="</select></td></tr>";
    
    }


else if(r[i]->type=="unknown")	{
	retval+="<TR>\n"
	"<TD VALIGN=TOP ALIGN=RIGHT><FONT FACE=helvetica,arial SIZE=-1>\n"
	"&nbsp; </FONT></TD>\n"
	"<TD>\n";

	retval+="<INPUT TYPE=HIDDEN NAME=\""
	+lower_case(r[i]->name)+"\" VALUE=NULL>\n";
	}
retval+="</TD>\n"
	"</TR>\n";

}


return retval; 

}

}

#if constant(thread_create)
static inherit Thread.Mutex;
#define THREAD_SAFE
#define LOCK() do { object key; catch(key=lock())
#define UNLOCK() key=0; } while(0)
#else
#undef THREAD_SAFE
#define LOCK() do {
#define UNLOCK() } while(0)
#endif

class db_handler
{
#ifdef THREAD_SAFE
  static inherit Thread.Mutex;
#endif
  array (object) dbs = ({});
  string db_name, db_user, db_password, host;
  int num_dbs;  
  void create(string|void _host, string _db, int num, string|void _user,
	string|void _password) {
    db_name = _db;
    host = _host;
    db_user = _user;
    db_password = _password;
    num_dbs=num;
    for(int i = 0; i < num; i++) {
     catch( dbs += ({ db(host, db_name, db_user, db_password) }));
    }
  }
  
  void|object handle(void|object d)
  {
    LOCK();
    int count;
    dbs -= ({0});
    if(objectp(d)) {
werror("returning a db object...\n");
      if(search(dbs, d) == -1) {
        if(sizeof(dbs)>(2*num_dbs)) {
          werror("Dropping db because of inventory...\n");
//          destruct(d);
          }
        else {
	  dbs += ({d});
	werror("Handler ++ ("+sizeof(dbs)+")\n");
	}
        }
      else {
	werror("Handler: duplicate return: \n");
      }
//      destruct(d);
    } 

else {
werror("requesting a db object...\n");
      if(!sizeof(dbs)) {
	werror("Handler: New DB created (none left).\n");
	d = db(host, db_name, db_user, db_password);
//	d->set_timeout(60);
      } else {
	d = dbs[0];
	dbs -= ({d});
	werror("Handler -- ("+sizeof(dbs)+")\n");
      }
    }
    UNLOCK();
    return d;
  }
}

