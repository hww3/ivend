#!NOMODULE

constant module_name = "Order Total Shipping";
constant module_type = "shipping";

mapping query_tag_callers2();
mapping query_container_callers2();    

int started;

int initialize_db(object db) {

  perror("initializing order total shipping module!\n");
catch(db->query("drop table shipping_ot"));
catch(db->query(
  "CREATE TABLE shipping_ot ("
  " type int(11) DEFAULT '0' NOT NULL,"
  " charge float(5,2) DEFAULT '0.00' NOT NULL,"
  " min float(5,2) DEFAULT '0.00' NOT NULL, "
  " max float(5,2) DEFAULT '0.00' NOT NULL,"
  " id int NOT NULL AUTO_INCREMENT PRIMARY KEY"
  " ) "));

return 0;

}

void start(mapping config){

started=0;

object db;

if(catch(db=iVend.db(config->general->dbhost, config->general->db,
  config->general->dblogin, config->general->dbpassword)))
  {
    perror("iVend: OTShipping: Error Connecting to Database.\n");
    return;
  }

if(sizeof(db->list_tables("shipping_ot"))==1);
else initialize_db(db);
started=1;
return;

}

void stop(mapping config){

return;

}

 mixed deletetype(object id){
   
    mixed j=id->misc->ivend->db->query("DELETE FROM shipping_ot "
                                       "WHERE type=" + 
				       id->variables->deletetype);
    return "<br>Shipping Type Deleted Successfully.<br>\n";
  }  




string addrangemenu(string type, object id){

  string retval="<form action=./><tr></tr>\n"+
    "<tr><td><font face=helvetica><b>From $</b></font></td>\n"
    "<td><font face=helvetica><b>To $</b></font></td>\n"
    "<td><font face=helvetica><b>Charge</b></font></td></tr>\n"
    "<tr><td><input type=text size=10 name=min></td>\n"
    "<td><input type=text size=10 name=max></td>\n"
    "<td><input type=text size=10 name=charge></td>\n"
    "</tr></table><input type=hidden value="+ type+ " name=type>"
    "<input type=hidden name=doaddrange value=1>"
    "<input type=hidden name=mode value=showtype>"
    "<input type=hidden name=showtype value=" + type + ">"
    "<input type=submit value=Add>";

  retval+="</form>";

  return retval;

}

mixed addrange(object id) {

    mixed j=id->misc->ivend->db->query("INSERT INTO shipping_ot "
				       "values(" + id->variables->type+
				       ","+id->variables->charge + "," +
				       id->variables->min + "," +
				       id->variables->max +",NULL)");

    return "<br>Shipping Range Added Successfully.<br>\n";
 
}

mixed deleterange(object id) {

    mixed j=id->misc->ivend->db->query("DELETE FROM shipping_ot "
				       "WHERE id=" + id->variables->id);

    return "<br>Shipping Range Deleted Successfully.<br>\n";
}


string showtype(object id, mapping row){
  int type=row->type;
  string retval="<tr><td><b>Method:</b></td><td>Charge based on order total</td></tr>"
	"</table>\n";
  if(id->variables->doaddrange)
   retval+=addrange(id);
  if(id->variables->dodelete)
   retval+=deleterange(id);
  array r=id->misc->ivend->db->query("SELECT * FROM shipping_ot WHERE type="
                                     + row->type + " ORDER BY min,max");
  if(sizeof(r)<1)
    retval+="<ul><font size=2><b>No Rules exist for this "
      "shipping type.</b></font><table>\n";    
  else {
    retval+="<ul><table><tr><td><font face=helvetica><b>From $</td><td>"
      "<font face=helvetica><b>To $</td><td><font face=helvetica><b>"
      "Charge</td></tr>\n";
    foreach(r, mapping row) {
      retval+="<tr><td>" + row->min + "</td><td>"+ row->max + "</td><td>"
	+ row->charge + " <font size=2 face=helvetica>(<a href=\"./?mode=showtype&showtype=" + type;
      retval+="&id=" +row->id +"&dodelete=1\">Delete</a>)</font></td></tr>";
    }


  }
  retval+=addrangemenu(row->type, id) + "</ul>";

  return retval;

}


float calculate_shippingtotal(object id, mixed orderid, mixed type){

float subtotal=0.00;
array r;



r=id->misc->ivend->db->query("SELECT "
  "SUM(sessions.price*sessions.quantity) as "
  "shippingtotal FROM sessions WHERE sessions.sessionid='" +
  orderid + "'");

if (sizeof(r)!=1) {
  perror( "Unable to calculate Order Subtotal.");
  return -1.00;
  }

return (float)(r[0]->shippingtotal);

}


float|string calculate_shippingcost(mixed type, mixed orderid, object id){

array r;
float amt=calculate_shippingtotal(id, orderid, type);

if(amt<0.00) {
  perror("Error Getting shipping total.!\n");
  return -1.00;
  }

 perror("type: " + type + " amt: " + sprintf("%.2f", amt)+"\n");

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

