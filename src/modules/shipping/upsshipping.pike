#!NOMODULE

constant module_name = "UPS Zone Shipping";
constant module_type = "shipping";

#define CONFIG id->misc->ivend->config
#define DB id->misc->ivend->db

mapping(string:object) u;	// The ups zone machine.

int started;
int initialized=0;

int initialize_db(object db, mapping config) {

  perror("initializing ups shipping module!\n");
catch(db->query("drop table shipping_ups"));
if(catch(db->query(
  "CREATE TABLE shipping_ups ("
  " type int(11) DEFAULT '0' NOT NULL,"
  " charge float(5,2) DEFAULT '0.00' NOT NULL,"
  " chargetype char(1) DEFAULT 'C' NOT NULL,"
  " field_name char(64) DEFAULT 'products.shipping_weight' NOT NULL, "
  " calctype char(1) DEFAULT 'T' NOT NULL, "
  " zonefile blob NOT NULL, "
  " ratefile blob NOT NULL, "
  " id int NOT NULL AUTO_INCREMENT PRIMARY KEY"
  " ) ")))
    return 0;
initialized=1;
return 0;

}

void load_zone(mapping row, mapping config){
perror("Loading UPS Zone...\n");
if(!u) u=([]);
u+=([row->type: Commerce.UPS.zone()]);
if(!u[row->type]->load_zonefile(row->zonefile))
  perror("Error Loading Zonefile for " + row->type + ".\n");
if(!u[row->type]->load_ratefile(row->ratefile))
  perror("Error Loading ratefile for " + row->type + ".\n");

}

void load_zones(object db, mapping config){
if(started && initialized){
 array r=db->query("SELECT * FROM shipping_ups");
 foreach(r, mapping row)
    load_zone(row, config);
}
  return;
}


mixed findrate(string zip, string weight, object id){

  float rate;
array r=DB->query("SELECT * FROM shipping_ups WHERE type="
 + id->variables->showtype);
  rate=u[r[0]->type]->findrate((string)zip, weight);
perror(rate + "\n");

string chargetype=r[0]->chargetype;

if(chargetype=="C")
  rate= rate + (float)r[0]->charge;
else rate=rate + ((float)r[0]->charge*rate);

return rate;

}


void start(mapping config){

perror("Starting UPS Shipping...\n");
object db;

if(catch(db=iVend.db(config->general->dbhost, config->general->db,
  config->general->dblogin, config->general->dbpassword))) {
    perror("iVend: UPSShipping: Error Connecting to Database.\n");
    return;
  }
if((sizeof(db->list_tables("shipping_ups")))==1)
 initialized=1;
else
  initialize_db(db, config);

started=1;
// u=Commerce.UPS.zone();
load_zones(db, config);
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
if(!initialized)
  start(id->misc->ivend->config);
    mixed j=id->misc->ivend->db->query("INSERT INTO shipping_ups "
				       "values(" + id->variables->type+
				       ","+id->variables->charge +
				       ",'"+id->variables->chargetype +
"','" + id->variables->field_name + "','" +
id->variables->calctype + 
					"','" +
DB->make_safe(id->variables->zonefile) + "','" +
DB->make_safe(id->variables->ratefile) +
"',NULL)");

  start(id->misc->ivend->config);
}
  string retval="";

  array r=id->misc->ivend->db->query("SELECT * FROM shipping_ups WHERE type="
                                     + row->type + " ORDER BY type");
  if(sizeof(r)<1) {
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
	"Markup: <INPUT TYPE=TEXT SIZE=5 NAME=charge> (Amount or Percent)<br>\n"
	"Markup Type: <SELECT NAME=chargetype>\n"
	"<OPTION VALUE=\"C\">Cash\n"
	"<OPTION VALUE=\"P\">Percentage\n"
	"</SELECT>\n<br>"
 	"<SELECT NAME=\"field_name\">\n";

  array f=DB->list_fields("products");
  foreach(f, mapping field){
    if(field->type=="integer" || field->type=="float" ||
	field->type=="long" || field->type=="decimal")
	retval+="<option value=\"products." + field->name + "\">"
	  + "products." + field->name + "\n";
    }

  retval+="</SELECT><br>\nCalculation Type: <SELECT NAME=calctype>\n"
	"<OPTION VALUE=\"T\">Use Total Shipping Weight\n"
	"<OPTION VALUE=\"S\">Calculate Each Item Seperatly\n"
	"</SELECT>\n<br>"
	"<input type=hidden name=dosetup value=dosetup>\n"
	"<input type=submit value=\"Set Up Shipper\">\n"
	"</form>";
}
else foreach(r, mapping row) {

    retval+="<p><form action=\"./\" method=post>\n"
	"<input type=hidden name=mode value=showtype>"
	"<input type=hidden name=dolookup value=dolookup>"
	"<input type=hidden name=showtype value=" +
	id->variables->showtype + ">"
	"<b>Look up Shipping: <input type=text size=5 name=zip_code> "
	"Zip Code <input type=text size=4 name=shipping_weight> "
	"Shipping Weight <input type=submit value=LookUp>"
	"</form></b><p>";

if(id->variables->dolookup)
  retval+="<b>Calculated Shipping cost: " +
findrate((string)id->variables->zip_code,
	id->variables->shipping_weight, id) + "</b><p>"; 
  
    retval+="<b>Zone File:</b> <p><pre>" +
	(row->zonefile/"\n")[0] + "</pre><br>" +
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


float calculate_shippingcost(mixed type, mixed orderid, object id){

array r;
float rate;
string shipping_weight;
string chargetype;
float charge;

r=DB->query("SELECT * from shipping_ups WHERE type='" + type + "'");

if(sizeof(r)!=1) {
  perror("ERROR GETTING SHIPPINGCOST!\n");
  return -1.00;
  }

shipping_weight=r[0]->field_name;
chargetype=r[0]->chargetype;
charge=(float)r[0]->charge;

if(r[0]->calctype=="T") {  // We calculate everything as if it were in a big box.

  array n=DB->query("SELECT SUM(sessions.quantity * "
	+ shipping_weight + ") AS weight FROM products,sessions WHERE "
	"products." + DB->keys["products"] + 
	"=sessions.id and sessions.sessionid='" + 
	orderid + "'");

  float w=n[0]->weight;
  n=DB->query("SELECT zip_code from customer_info where orderid='" +
	orderid + "' AND type=0");
  if(sizeof(n)==0)
	return -1.00;
  string zip=n[0]->zip_code;

  rate=u[type]->findrate((string)zip, (string)w);

  }

else { // We calculate as though everything were in a seperate box.
 float ratecalc=0.00;

 array n=DB->query("SELECT " + shipping_weight + 
	" AS weight,sessions.quantity FROM "
	"products,sessions WHERE products." + DB->keys["products"] +
	"=sessions.id AND"
	" sessionid='" + orderid
	+ "'");
// perror("got " + sizeof(n) + " rows\n");
 foreach(n, mapping row){
// perror(sprintf("%O\n", row));
  float w=row["weight"];
  n=DB->query("SELECT zip_code from customer_info where orderid='" +
	orderid + "' AND type=0");
  if(sizeof(n)==0)
	return -1.00;
  string zip=n[0]->zip_code;

  if(catch(rate=u[type]->findrate((string)zip, (string)w)))
	return -1.00;;
  ratecalc+=((float)rate*(float)(row->quantity));
  }
 rate=ratecalc;
 }

if(chargetype=="C")
  rate= rate + (float)charge;
else rate=rate + ((float)charge*rate);

return (float)rate;

}

