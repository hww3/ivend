#!NOMODULE

constant module_name = "UPS Zone Shipping";
constant module_type = "shipping";

#define CONFIG id->misc->ivend->config

object u;	// The ups zone machine.

int started;

int initialize_db(object db, mapping config) {

  perror("initializing order total shipping module!\n");
catch(db->query("drop table shipping_ups"));
if(catch(db->query(
  "CREATE TABLE shipping_ups ("
  " type int(11) DEFAULT '0' NOT NULL,"
  " charge float(5,2) DEFAULT '0.00' NOT NULL,"
  " chargetype char(1) DEFAULT 'C' NOT NULL,"
  " zonefile blob NOT NULL, "
  " ratefile blob NOT NULL, "
  " id int NOT NULL AUTO_INCREMENT PRIMARY KEY"
  " ) ")))
    return 0;
rm(config->general->root + "/db/shipping_ups_chargetype.val");
catch(Stdio.write_file(config->general->root +
  "/db/shipping_ups_chargetype.val","Cash\nPercentage\n")); 
return 0;

}

void load_zone(mapping row, mapping config){

if(!u->load_zonefile(row->zonefile))
  perror("Error Loading Zonefile for " + row->type + ".\n");
if(!u->load_ratefile(row->ratefile))
  perror("Error Loading ratefile for " + row->type + ".\n");

}

void load_zones(object db, mapping config){

  foreach(db->query("SELECT * FROM shipping_ups"), mapping row)
    load_zone(row, config);

  return;
}

void start(mapping config){

object db;

if(catch(db=iVend.db(config->general->dbhost, config->general->db,
  config->general->dblogin, config->general->dbpassword))) {
    perror("iVend: UPSShipping: Error Connecting to Database.\n");
    return;
  }
if((sizeof(db->list_tables("shipping_ups")))==1);
else
  initialize_db(db, config);

u=Commerce.UPS.zone();
load_zones(db, config);
started=1;
return;

}

void stop(mapping config){

return;

}

mixed addtype(object id){

 return 0;

}

string showtype (object id,mapping row){

  string retval="";

  array r=id->misc->ivend->db->query("SELECT * FROM shipping_ups WHERE type="
                                     + row->type + " ORDER BY type");
  if(sizeof(r)<1)
    retval+="<ul><font size=2><b>This "
      "shipping type has not been set up yet.</b></font><table>\n"
  "<p><b>Set up Shipping Handler</b>"
	"<form action=\"./\" method=post>"
	"<input type=hidden name=mode value=showtype>\n"
	"<input type=hidden name=type value=" + id->variables->type +">\n"
	"<input type=hidden name=dosetup value=dosetup>\n"
	"<input type=submit value=\"Set Up Shipper\">\n"
	"</form>";
  else foreach(r, mapping row) {

    retval+="<b>Zone File:</b> " + 
	((row->zonefile/"\n")[0]) + "<br>" +
	"<b>Rate File:</b> " + ((row->ratefile/"\n")[0]);

  }


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
	retval+=showtype(id, row->type);

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
