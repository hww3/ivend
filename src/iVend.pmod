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

string|int genform(void|mapping config){

string retval="";
perror(sprintf("%O",config));
if(sizeof(config_setup)<1) return 0;
array vars=sort(indices(config_setup));
for(int i=0; i<sizeof(vars); i++){
  write(vars[i]);
  retval+="<tr>\n<td>";
  retval+=config_setup[vars[i]]->name+" &nbsp \n</td><td>";
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

    case "string":
    default:
    if(config)
      retval+="<input type=\"text\" name=\""+(vars[i]||"")+"\" value=\""+
      (config[vars[i]]||config_setup[vars[i]]->default_value ||"")+"\">";      
    else
      retval+="<input type=\"text\" name=\""+(vars[i]||"")+"\" value=\""+
      (config_setup[vars[i]]->default_value ||"")+"\">";
    break;

    }
  retval+="</td>\n</tr>\n"
          "<tr>\n<td colspan=2><i><font size=-1 face=helvetica,arial>\n"
          +(config_setup[vars[i]]->description||"")
          +"</i></font>\n<p></td></tr>\n";

  }

return retval;
}

void create(){
return;
}


}


class db {
object s;	//  sql db connection...
string host;
string db;
string user;
string password;

int addentry(object id, string referrer){
array(mapping(string:mixed)) r=s->list_fields(id->variables->table);
string query="INSERT INTO "+id->variables->table+" VALUES(";
for (int i=0; i<sizeof(r); i++){

  if(r[i]->name=="image"){

  if(sizeof(id->variables[r[i]->name])>3)
    {
    string filename=id->misc->ivend->config->root+"/images/"+id->variables->id+".gif";
    rm(filename);
    Stdio.write_file(filename,id->variables[r[i]->name]);
    query+="'"+id->variables->id+"',";
    }
  else query+="NULL,";
  }

 else if(r[i]->type=="string" || r[i]->type=="var string" || 
    r[i]->type=="blob") query+="'"+id->variables[r[i]->name]+"',";

  else query+=id->variables[r[i]->name]+",";

  }
query=query[0..sizeof(query)-2]+")";
s->query(query);
 if(id->variables->jointable) {
 array jointable=id->variables[id->variables->jointable]/"\000";
 for(int i=0; i<sizeof(jointable); i++){
    query="INSERT INTO "
      + id->variables->joindest +" VALUES('"+
	jointable[i]+ "','"
        +id->variables->id+"')";
    s->query(query);
    }
 }
return 1;

}

string|int gentable(string table, string return_page, 
    string|void jointable,string|void joindest , string|void SESSIONID){
string retval="";
array(mapping(string:mixed)) r=s->list_fields(table);


retval+="<FORM ACTION=\""+return_page+"\" ENCTYPE=multipart/"
	"form-data>\n"
        "<INPUT TYPE=HIDDEN NAME=table VALUE=\""+table+"\">\n"
        "<INPUT TYPE=HIDDEN NAME=mode VALUE=\"doadd\">\n";
if(SESSIONID)
  retval+="<INPUT TYPE=HIDDEN NAME=SESSIONID " 
	"VALUE=\""+SESSIONID+"\">\n"
        "<TABLE>\n";

for(int i=0; i<sizeof(r);i++){          // Generate form from schema
if(r[i]->name=="image"){
    retval+="<TR>\n"
    "<TD VALIGN=TOP ALIGN=RIGHT><FONT FACE=helvetica,arial SIZE=-1>\n"
    +replace(r[i]->name,"_"," ")+
    "</FONT></TD>\n"
    "<TD>\n"
    "<input type=file name=image></td></tr>\n";
}

else if(r[i]->type=="blob"){
    retval+="<TR>\n"
    "<TD VALIGN=TOP ALIGN=RIGHT><FONT FACE=helvetica,arial SIZE=-1>\n"
    +replace(r[i]->name,"_"," ")+
    "</FONT></TD>\n"
    "<TD>\n"
    "<TEXTAREA NAME=\""+r[i]->name+"\" COLS=70 ROWS=5></TEXTAREA>\n";
        }

else if(r[i]->type=="decimal" || r[i]->type=="float"){
    retval+="<TR>\n"
    "<TD VALIGN=TOP ALIGN=RIGHT><FONT FACE=helvetica,arial SIZE=-1>\n"
    +replace(r[i]->name,"_"," ")+
    " <b>$</b></FONT></TD>\n"
    "<TD>\n"
    "<INPUT TYPE=TEXT NAME=\""+r[i]->name+"\" SIZE="+r[i]->length+
    " MAXLEN="+r[i]->length+">\n";
    
    if(r[i]->flags->not_null) retval+="&nbsp;<FONT FACE=helvetica,arial "
      "SIZE=-1><I> Required\n";
        }

else if(r[i]->type=="var string"){
    retval+="<TR>\n"
    "<TD VALIGN=TOP ALIGN=RIGHT><FONT FACE=helvetica,arial SIZE=-1>\n"
    +replace(r[i]->name,"_"," ")+
    "</FONT></TD>\n"
    "<TD>\n";


    retval+="<INPUT TYPE=TEXT NAME=\""+r[i]->name+
      "\" SIZE="+r[i]->length+" MAXLEN="+r[i]->length+">\n";
    
    if(r[i]->flags->not_null) retval+="&nbsp;<FONT FACE=helvetica,arial "
      "SIZE=-1><I> Required\n";
        }

else if(r[i]->type=="string"){
    retval+="<TR>\n"
    "<TD VALIGN=TOP ALIGN=RIGHT><FONT FACE=helvetica,arial SIZE=-1>\n"
    +replace(r[i]->name,"_"," ")+
    "</FONT></TD>\n"
    "<TD>\n";
      
   if(r[i]["default"]=="N")
   retval+="<SELECT NAME=\""+r[i]->name+"\"><OPTION VALUE=\"N\">"
      "No\n<OPTION VALUE=\"Y\">Yes\n</SELECT>\n";
   else if(r[i]["default"]=="Y")
      retval+="<SELECT NAME=\""+r[i]->name+"\"><OPTION VALUE=\"Y\">"
        "Yes\n<OPTION VALUE=\"N\">No\n</SELECT>\n";
   else retval+="<INPUT TYPE=TEXT NAME=\""+r[i]->name+"\" MAXLEN="
      +r[i]->length+" SIZE="+(r[i]->length+20)+">\n";
    }       

else if(r[i]->type=="long" && r[i]->flags["not_null"]){
    retval+="<TR>\n"
    "<TD VALIGN=TOP ALIGN=RIGHT>&nbsp;</TD>\n<TD>\n";
    retval+="<INPUT TYPE=HIDDEN NAME=\""+r[i]->name+
      "\" MAXLEN="+r[i]->length+" SIZE="+r[i]->length+" VALUE=NULL>\n";

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

  array j=s->query("SELECT name,id FROM "+jointable);
  retval+="<tr><td valign=top align=right><font "
    "face=helvetica,arial size=-1>"+jointable+"</td><td>"
    "<select multiple size=5 name="+jointable+">\n";
  for(int i=0; i<sizeof(j); i++)
    retval+="<option value=\""+j[i]->id+"\">"+j[i]->name+"\n";
  retval+="</select>\n<input type=hidden name=jointable value=\""
    +jointable+"\">\n<input type=hidden name=joindest value=\""
    +joindest+"\">"
    "</td></tr>\n";

}

retval+="</TABLE>\n"
    "<INPUT TYPE=SUBMIT VALUE=Add>\n"
    "<INPUT TYPE=HIDDEN VALUE=" + return_page + ">\n"
    "</FORM>\n";

return retval;
 

}

string|int showdepends(string type, string id){
string query="";
if(type=="" || id=="")
return "Delete unsuccessful.\n";
string retval="";

if(type=="group"){
  query="SELECT * FROM groups WHERE id='"+id+"'";
  array j=s->query(query);
  if(sizeof(j)!=1) return 0;
  else {
    retval+="Group "+j[0]->id+" ( "+j[0]->name+" ) is linked to the following"
      " products:<p>";
    query="SELECT product_groups.product_id,products.name FROM "
	"products,product_groups WHERE product_groups.group_id='"
        +id+"' AND products.id=product_groups.product_id";
    j=s->query(query);
    if(sizeof(j)==0) retval+="<blockquote>No Products in this group.</blockquote>";
    else {
      retval+="<blockquote>\n";
      for(int i=0; i<sizeof(j); i++)
        retval+=j[i]->product_id+" ( "+j[i]->name+" )<br>";
      }
    }
  }

else if(type=="product") {
  query="SELECT id,name FROM products WHERE id='"+id+"'";
  array j=s->query(query);
  if(sizeof(j)!=1) return 0;
  else retval+="<blockquote>"+j[0]->id+" ( "+j[0]->name+" )<br>\n";
  }

retval+="</blockquote>\n";
return retval; 
}
string dodelete(string type, string id){
string query="";

if(type=="" || id=="")
return "Delete unsuccessful.\n";

if(type=="group") {
  query="DELETE FROM groups WHERE id='"+id+"'";
  s->query(query);
  query="DELETE FROM product_groups WHERE group_id='"+id+"'";
  s->query(query);
  }

else if(type="product") {
  query="DELETE FROM products WHERE id='"+id+"'";
  s->query(query);
  query="DELETE FROM product_groups WHERE product_id='"+id+"'";
  s->query(query);
  }
return capitalize(type)+" "+id+" deleted successfully.\n";

}



void create(string|void host, string|void db, string|void user, 
string|void password){
s=Sql.sql(host,db,user,password);
return;
}

}
