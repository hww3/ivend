#!NOMODULE

constant module_name = "UPS Zone Shipping";
constant module_type = "shipping";

#define CONFIG id->misc->ivend->config

object u;	// The ups zone machine.

int started;

void start(mapping config){

object db;

if(catch(db=iVend.db(config->general->dbhost, config->general->db,
  config->general->dblogin, config->general->dbpassword)))
    perror("iVend: UPSShipping: Error Connecting to Database.\n");
if((sizeof(db->list_tables("shipping_ups")))==1);
else
  initialize_db(db);

u=Commerce.UPS.zone();
started=1;
return;

}

void stop(mapping config){

return;

}

int initialize_db(object db) {

  perror("initializing order total shipping module!\n");
catch(db->query("drop table shipping_ups"));
catch(db->query(
  "CREATE TABLE shipping_ups ("
  " type int(11) DEFAULT '0' NOT NULL,"
  " charge float(5,2) DEFAULT '0.00' NOT NULL,"
  " chargetype char(1) DEFAULT 'C' NOT NULL,"
  " zonefile char(12) NOT NULL, "
  " id int NOT NULL AUTO_INCREMENT PRIMARY KEY"
  " ) "));
rm(CONFIG->general->root + "/db/shipping_ups_chargetype.val");
catch(Stdio.write_file(CONFIG->general->root +
  "/db/shipping_ups_chargetype.val","Cash\nPercentage\n")); 
return 0;

}

string addtype(object id){

  string retval="<table>\n"+
  id->misc->ivend->db->gentable("shipping_types","shipping",0,id);
  return retval;

}


string addrange(string type, object id){

  string retval="<form action=./><tr></tr>\n"+
    "<tr><td><font face=helvetica><b>From $</b></font></td>\n"
    "<td><font face=helvetica><b>To $</b></font></td>\n"
    "<td><font face=helvetica><b>Charge</b></font></td></tr>\n"
    "<tr><td><input type=text size=10 name=min></td>\n"
    "<td><input type=text size=10 name=max></td>\n"
    "<td><input type=text size=10 name=charge></td>\n"
    "</tr></table><input type=hidden value="+ type+ " name=type>"
    "<input type=hidden name=doaddrange value=1>"
    "<input type=submit value=Add>";

  foreach(({"viewtype","showall"}), string var)
    retval+="<input type=hidden name=" + var + " value=" + 
	  id->variables[var] + ">\n";

  retval+="</form>";

  return retval;

}



string show_type(string type, object id){

  string retval="";

  array r=id->misc->ivend->db->query("SELECT * FROM shipping_ups WHERE type="
                                     + type + " ORDER BY type");
  if(sizeof(r)<1)
    retval+="<ul><font size=2><b>No Rules exist for this "
      "shipping type.</b></font><table>\n";    
  else {
    retval+="<ul><table><tr><td><font face=helvetica><b>From $</td><td>"
      "<font face=helvetica><b>To $</td><td><font face=helvetica><b>"
      "Charge</td></tr>\n";
    foreach(r, mapping row) {
      retval+="<tr><td>" + row->min + "</td><td>"+ row->max + "</td><td>"
	+ row->charge + " <font size=2 face=helvetica>(<a href="
	"./?";
      foreach(({"showall", "viewtype"}), string var)
	retval+=var+"="+id->variables[var]+"&";
      retval+="&id=" +row->id + "&dodelete=1>Delete</a>)</font></td></tr>";
    }


  }
  retval+=addrange(type, id) + "</ul>";

  return retval;

}


mixed shipping_admin(object id){
string retval="";     

  if(id->variables->mode=="doadd") {

    mixed j=id->misc->ivend->db->addentry(id,id->referrer);
    retval+="<br>";
    if(stringp(j))
      return retval+= "The following errors occurred:<p>" + j;

    string type=(id->variables->table/"_"*" ");
    retval+=type+" Added Successfully.<br>\n";
    }

  if(id->variables->doaddrange) {

    mixed j=id->misc->ivend->db->query("INSERT INTO shipping_ot "
				       "values(" + id->variables->type+
				       ","+id->variables->charge + "," +
				       id->variables->min + "," +
				       id->variables->max +",NULL)");

    retval+="<br>Shipping Range Added Successfully.<br>\n";
    }

  if(id->variables->dodelete) {

    mixed j=id->misc->ivend->db->query("DELETE FROM shipping_ot "
				       "WHERE id=" + id->variables->id);

    retval+="<br>Shipping Range Deleted Successfully.<br>\n";
    }

 if(id->variables->dodeletetype) {

    mixed j=id->misc->ivend->db->query("DELETE FROM shipping_types "
                                       "WHERE type=" + 
				       id->variables->dodeletetype);

    mixed j=id->misc->ivend->db->query("DELETE FROM shipping_ot "
                                       "WHERE type=" + 
				       id->variables->dodeletetype);
    retval+="<br>Shipping Type Deleted Successfully.<br>\n";
    }  


  if(id->variables->addtype)
    retval+=addtype(id);
  else {
    retval+="<ul>\n<li>Shipping Types <font size=2>(<a href=shipping"
      + (id->variables->showall=="1" ?">Collapse All":"?showall=1>Expand All") + 
      "</a>)</font>\n<ul>";

    array r=id->misc->ivend->db->query("SELECT * FROM shipping_types");
    foreach(r, mapping row) {
      retval+="<li><a href=shipping?viewtype="+row->type+ ">" + row->name
        +"</a>\n<font size=2>( <a href=./?dodeletetype="+
	row->type +">Delete"+"</a> )"
        "<dd>"+ row->description+"</font>\n\n";
      if (row->type==id->variables->viewtype || id->variables->showall=="1")
	retval+=show_type(row->type, id);

    }
    retval+="</ul><font size=2><a href=shipping?addtype=1>"
      "Add New Type</font></a>\n</ul>\n";
    }

return "Method: Shipping Cost Based on Order Total\n<br>" + retval;

}

float|string calculate_shippingcost(float amt, mixed type, object id){

array r;

r=id->misc->ivend->db->query("SELECT charge FROM shipping_ot WHERE type=" +
  (string)type +  " AND min <= " + 
  sprintf("%.2f",amt) + " AND max >= " +
  sprintf("%.2f",amt) );

if(sizeof(r)!=1) {
  perror("ERROR GETTING SHIPPINGCOST!\n");
  return -1.00;
  }
else return (float)(r[0]->charge);

}
