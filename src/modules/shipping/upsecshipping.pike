#!NOMODULE

constant module_name = "UPS EC Shipping";
constant module_type = "shipping";

#define CONFIG id->misc->ivend->config
#define DB id->misc->ivend->db
#define KEYS id->misc->ivend->keys

#define ECURL "http://www.ups.com:80/using/services/rave/qcost_dss.cgi"
#define ECHOST "www.ups.com"
#define ECPORT 80
#define ECPATH "/using/services/rave/qcost_dss.cgi"

// A list of the valid UPS Service Levels
mapping ServiceLevelCodes=([
	"Next Day Air Early AM": "1DM",
	"Next Day Air": "1DA",
	"Next Day Air Intra (Puerto Rico)": "1DAPI",
	"Next Day Air Saver": "1DP",
	"2nd Day Air AM": "2DM",
	"2nd Day Air": "2DA",
	"3 Day Select": "3DS",
	"Ground": "GND",
	"Worldwide Express": "XPR",
	"Worldwide Express Plus": "XDM",
	"Worldwide Expedited" : "XPD"
	]);

// A list of the valid UPS Rate Charts
mapping RateCharts=([
	"Customer Counter": "Customer Counter",
	"Letter Center": "Letter Center",
	"On Call Air": "On Call Air",
	"One Time Pickup": "One Time Pickup",
	"Regular Daily Pickup": "Regular Daily Pickup"
	]);

mixed findrate(string zip, string weight, mapping|void options, object id){

  float rate;

  mapping query_variables=([]);

  query_variables->PackageActualWeight=weight;
  query_variables->ConsigneePostalCode=zip;
  query_variables->ConsigneeCountry="US";

  if(options)
    query_variables+=options;
mapping request_headers;

string q="AppVersion=1.2&AcceptUPSLicenseAgreement=YES&\r\n"
	"ResponseType=application/x-ups-rrs&ActionCode=3&\r\n"
//	"ResidentialInd=" + (options->ResidentialInd||"0") + "&" +
//	"PackagingType=" + (options->PackagingType||"00") 
//+"&" + Protocols.HTTP.http_encode_query(query_variables) + "\r\n";
+"ServiceLevelCode=1DA&RateChart=Regular+Daily+Pickup&\r\n"
"ShipperPostalCode=30008&ConsigneePostalCode=10190&\r\n"
"ConsigneeCountry=US&PackageActualWeight=10&\r\n"
"ResidentialInd=1&PackagingType=00";

object con=master()->resolv("Protocols")["HTTP"]["Query"]();
   con->sync_request(ECHOST,ECPORT,
                     "POST "+ ECPATH +" HTTP/1.0",
                     (["user-agent":
                       "Mozilla/4.0 compatible (Pike HTTP client)"]) |
                     (["content-type":
                       "application/x-www-form-urlencoded"]),
                     q);

perror("Request: " + q + "\n");
   if (!con->ok) return -2.00;
mixed result=con->data();
  perror("UPSEC RESULT: " + sprintf("<pre>%O</pre>", result)+ "\n");
  return sprintf("<pre>%O</pre>", result);

}


void start(mapping config){

perror("Starting UPS Online Shipping...\n");

return;

}

void stop(mapping config){

return;

}

string showtype (object id,mapping row){
  mapping vars;
	vars=id->variables;
  string retval="";
  mapping row;

  if(id->variables->dodelete) {

    }

  if(id->variables->doadd) {
	m_delete(vars, "mode");
	m_delete(vars, "showtype");
	m_delete(vars, "doadd");
	m_delete(vars, "dosetup");
	m_delete(vars, "SESSIONID");

  CONFIG["ShippingType_" + vars->type]=vars;
Config.write_section(id->misc->ivend->this_object->query("configdir")+
  CONFIG->general->config, "ShippingType_" + vars->type,
        CONFIG["ShippingType_" + vars->type]);
  start(id->misc->ivend->config);
vars->showtype=vars->type;
}

if(CONFIG && CONFIG["ShippingType_" + vars->showtype])
{
	row=CONFIG["ShippingType_" + vars->showtype];
//perror(sprintf("%O\n", row));
    retval+="<p><form action=\"./\" method=post>\n"
	"<input type=hidden name=mode value=showtype>"
	"<input type=hidden name=dolookup value=dolookup>"
	"<input type=hidden name=showtype value=" +
	id->variables->showtype + ">"
	"<b>Look up Shipping: <input type=text size=5 name=zip_code> "
	"Zip Code <input type=text size=4 name=shipping_weight> "
	"Shipping Weight <input type=submit value=LookUp>"
	"Oversize? <input type=checkbox name=oversize value=Y>\n"
	"Residential/Commercial? <select name=residentialind>"
	"<option value=0>Commercial\n"
	"<option value=1>Residential\n"
	"</select>\n"
	"Packaging Type? <select name=packagingtype>"
	"<option value=00>Shipper Supplied Packaging\n"
	"<option value=01>UPS Letter Envelope\n"
	"<option value=03>UPS Tube\n"
	"<option value=21>UPS Express Box\n"
	"<option value=24>International UPS 25KG Box\n"
	"<option value=25>International UPS 10KG Box\n"
	"</select>\n"
	"</form></b><p>";

mapping options=(["PackagingType": id->variables->packagingtype,
	"ResidentialInd": id->variables->residentialind,
	"OversizeInd": (id->variables->oversize||"N"),
	"ServiceLevelCode": row->service_level,
	"ShipperPostalCode": row->origin,
	"RateChart": replace(row->rate_chart," ", "+")
	]);

if(id->variables->dolookup)
  retval+="<b>Calculated Shipping cost: " +
findrate((string)id->variables->zip_code,
	id->variables->shipping_weight,
	options,
	id) + "</b><p>"; 
  
    retval+=
	"<b>Service Level:</b> " +
search(ServiceLevelCodes, row->service_level) + "<br>\n"
	"<b>Rate Chart:</b> " + 
search(RateCharts, row->rate_chart) + "<br>\n"
	"<b>Origin ZIP:</b> " + row->origin + "\n"
	"<b>Oversize Field:</b> " + row->oversize_field + "\n"
	"<b>Weight Field:</b> " + row->field_name + "\n"
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


  else {
    retval+="<ul><font size=2><b>This "
      "shipping type has not been set up yet.</b></font><table>\n"
  "<p><b>Set up Shipping Handler</b>"
	"<form action=\"./\" method=\"post\">"
	"<input type=hidden name=mode value=\"showtype\">\n"
	"<input type=hidden name=showtype value=" +id->variables->showtype +">\n"
	"<input type=hidden name=doadd value=\"doadd\">\n"
	"<input type=hidden name=type value=" + id->variables->showtype +">\n"
	"Service Level: <SELECT NAME=\"service_level\"";
  foreach(indices(ServiceLevelCodes), string slc)
	retval+="<OPTION VALUE=\"" + ServiceLevelCodes[slc] + "\">" + slc
	+ "\n";
  retval+="</SELECT>\n<br>"
	"Rate Chart: <SELECT NAME=\"rate_chart\"";
  foreach(indices(RateCharts), string rc)
	retval+="<OPTION VALUE=\"" + RateCharts[rc] + "\">" + rc
	+ "\n";
  retval+="</SELECT>\n<br>"
	"Package Origin: <INPUT TYPE=TEXT SIZE=5 NAME=origin> (ZIP Code)<br>\n"
	"Markup: <INPUT TYPE=TEXT SIZE=5 NAME=charge> (Amount or Percent)<br>\n"
	"Markup Type: <SELECT NAME=chargetype>\n"
	"<OPTION VALUE=\"C\">Cash\n"
	"<OPTION VALUE=\"P\">Percentage\n"
	"</SELECT>\n<br>"
 	"Weight Field: <SELECT NAME=\"field_name\">\n"
	"<option value=\"NONE\">None\n";

  array f=DB->list_fields("products");
  foreach(f, mapping field){
    if(field->type=="integer" || field->type=="float" ||
	field->type=="long" || field->type=="decimal")
	retval+="<option value=\"products." + field->name + "\">"
	  + "products." + field->name + "\n";
    }

 retval+="</SELECT>"
	"Oversize Indicator: <SELECT NAME=\"oversize_field\">\n"
	"<option value=\"NONE\">None\n";
  array f=DB->list_fields("products");
  foreach(f, mapping field){
    if( field->type!="float" &&
	field->type!="long" && field->type!="decimal")
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
	"products." + KEYS["products"] + 
	"=sessions.id and sessions.sessionid='" + 
	orderid + "'");

  float w=n[0]->weight;
  n=DB->query("SELECT zip_code from customer_info where orderid='" +
	orderid + "' AND type=0");
  if(sizeof(n)==0)
	return -1.00;
  string zip=n[0]->zip_code;

  rate=findrate((string)zip, (string)w, 0, id);

  }

else { // We calculate as though everything were in a seperate box.
 float ratecalc=0.00;

 array n=DB->query("SELECT " + shipping_weight + 
	" AS weight,sessions.quantity FROM "
	"products,sessions WHERE products." + KEYS["products"] +
	"=sessions.id AND"
	" sessionid='" + orderid
	+ "'");

 foreach(n, mapping row){
  float w=row["weight"];
  n=DB->query("SELECT zip_code from customer_info where orderid='" +
	orderid + "' AND type=0");
  if(sizeof(n)==0)
	return -1.00;
  string zip=n[0]->zip_code;

  if(catch(findrate((string)zip, (string)w, 0, id)))
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

