#!NOMODULE

constant module_name = "UPS Zone Shipping";
constant module_type = "shipping";

#define CONFIG id->misc->ivend->config
#define DB id->misc->ivend->db
object u;	// The ups zone machine.

int started;

int initialize_db(object db, mapping config) {

  perror("initializing ups shipping module!\n");
catch(db->query("drop table shipping_ups"));
if(catch(db->query(
  "CREATE TABLE shipping_ups ("
  " type int(11) DEFAULT '0' NOT NULL,"
  " charge float(5,2) DEFAULT '0.00' NOT NULL,"
  " chargetype char(1) DEFAULT 'C' NOT NULL,"
  " calctype char(1) DEFAULT 'T' NOT NULL, "
  " zonefile blob NOT NULL, "
  " ratefile blob NOT NULL, "
  " id int NOT NULL AUTO_INCREMENT PRIMARY KEY"
  " ) ")))
    return 0;
return 0;

}

void load_zone(mapping row, mapping config){
perror("Loading UPS Zone...\n");
if(!u->load_zonefile(row->zonefile))
  perror("Error Loading Zonefile for " + row->type + ".\n");
if(!u->load_ratefile(row->ratefile))
  perror("Error Loading ratefile for " + row->type + ".\n");

}

void load_zones(object db, mapping config){

 array r=db->query("SELECT * FROM shipping_ups");
    load_zone(r[0], config);

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

string showtype (object id,mapping row){

  if(id->variables->dodelete) {
    DB->query("DELETE FROM shipping_ups WHERE type=" +
id->variables->showtype );

    }

  if(id->variables->doadd) {

    mixed j=id->misc->ivend->db->query("INSERT INTO shipping_ups "
				       "values(" + id->variables->type+
				       ","+id->variables->charge +
				       ",'"+id->variables->chargetype +
"','" + id->variables->calctype + 
					"','" +
DB->make_safe(id->variables->zonefile) + "','" +
DB->make_safe(id->variables->ratefile) +
"',NULL)");

}
  string retval="";

  array r=id->misc->ivend->db->query("SELECT * FROM shipping_ups WHERE type="
                                     + row->type + " ORDER BY type");
  if(sizeof(r)<1)
    retval+="<ul><font size=2><b>This "
      "shipping type has not been set up yet.</b></font><table>\n"
  "<p><b>Set up Shipping Handler</b>"
	"<form action=\"./\" method=post enctype=multipart/form-data>"
	"<input type=hidden name=mode value=showtype>\n"
	"<input type=hidden name=showtype value=" +id->variables->showtype +">\n"
	"<input type=hidden name=doadd value=doadd>\n"
	"<input type=hidden name=type value=" + id->variables->showtype +">\n"
	"UPS Zone File (CSV Format Only): <input type=file name=zonefile><br>\n"
	"UPS Rate File (CSV Format Only): <input type=file name=ratefile><br>\n"
	"Markup: <INPUT TYPE=TEXT SIZE=5 NAME=charge><br>\n"
	"Markup Type: <SELECT NAME=chargetype>\n"
	"<OPTION VALUE=\"C\">Cash\n"
	"<OPTION VALUE=\"P\">Percentage\n"
	"</SELECT>\n<br>"
	"Calculation Type: <SELECT NAME=calctype>\n"
	"<OPTION VALUE=\"T\">Use Total Shipping Weight\n"
	"<OPTION VALUE=\"S\">Calculate Each Item Seperatly\n"
	"</SELECT>\n<br>"
	"<input type=hidden name=dosetup value=dosetup>\n"
	"<input type=submit value=\"Set Up Shipper\">\n"
	"</form>";
  else foreach(r, mapping row) {

    retval+="<b>Zone File:</b> <p><pre>" + 
	(row->zonefile) + "</pre><br>" +
	"<b>Rate File:</b> " + ((row->ratefile/"\n")[0]) +
	"<br><b>Markup:</b> " + row->charge + " (" +
(row->chargetype=="C"?"Cash":"Percentage") + ")"
	"<br><b>Calculation Type:</b> " + (row->calctype=="T"?
		"Total all shipping weights":
		"Calculate shipping for each item seperately");

retval+="<p><form action=\"./\" method=post>\n"
	"<input type=hidden name=mode value=showtype>"
	"<input type=hidden name=dodelete value=dodelete>"
	"<input type=hidden name=showtype value=" +
id->variables->showtype + ">"
	"<input type=submit value=\"Delete Shipper Config\">"
	"</form>";

  }


  return retval;

}


float|string calculate_shippingcost(mixed type, object id){

array r;

r=DB->query("SELECT * FROM shipping_ups WHERE type="
 + type);

if(sizeof(r)!=1) {
  perror("ERROR GETTING SHIPPINGCOST!\n");
  return -1.00;
  }

if(r[0]->calctype=="T") {

  array n=DB->query("SELECT SUM(sessions.quantity * "
	"products.shipping) AS weight FROM products,sessions WHERE "
	"products.id=sessions.id and sessions.sessionid='" + 
	id->misc->ivend->SESSIONID + "'");

  perror("total shipping weight: " + n[0]->weight + "\n");
  float w=n[0]->weight;
  n=DB->query("SELECT zip_code from customer_info where orderid='" +
	id->misc->ivend->SESSIONID + "' AND type=0");
  string zip=n[0]->zip_code;
  perror("zip code: " + zip + "\n");

  mixed rate=u->findrate(zip, w);
  perror(sprintf("%O",rate )+ "\n");

  }

return 100.00;

}
