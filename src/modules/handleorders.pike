#!NOMODULE

#include <ivend.h>

#define CONFIG id->misc->ivend->config

inherit "roxenlib";

constant module_name = "Stock Order Handler";
constant module_type = "order";

int saved=1;
array fields=({});
array cc_fields=({});


string|int show_orderdetails(string orderid, object s, object id);

string create_panel(string name, string color, string contents, object id){
string fontcolor;
  if(id->variables->print) { color="white"; fontcolor="black"; }
  else { fontcolor="white"; }
  string retval="";

   retval+="<table valign=top width=80%><tr><td colspan=1 bgcolor=" +
color +">\n";
   retval+=" &nbsp; <font face=helvetica color=\"" + fontcolor + "\"><b>"+
	name +"</font></b> &nbsp; </td></tr>\n";
   retval+="<tr><td>\n" + contents + "\n</td></tr>\n</table>\n";

  return retval;
}

string|int genpayment(object id, object s){
string retval="";
string key="";
object privs=Privs("Reading Key File");
if(id->misc->ivend->config->general->privatekey)
  key=Stdio.read_file(id->misc->ivend->config->general->privatekey);
privs=0;
// perror(key);
array r=DB->query("SELECT payment_info.*, status.name as status from "
	 "payment_info,status WHERE orderid=" + id->variables->orderid +
	 " AND status.status=payment_info.status");

array f=DB->list_fields("payment_info");

if(!r || sizeof(r)==0) return create_panel("Payment Information", "maroon", 
	      "Unable to find Payment Info for Order ID " + 
		   id->variables->orderid, id);

retval="<table valign=top width=100%>";
 foreach(f, mapping field){
     if(field->name=="updated" || field->name=="type" || field->name=="orderid") continue;
   retval+="<tr><td width=30%><font face=helvetica>"+ replace(field->name,"_"," ")
     +"</font>\n</td>\n<td>"+
  ((r[0][field->name] && r[0][field->name][0..3]=="iVEn")?

(Commerce.Security.decrypt(r[0][field->name],key)+"*"):(string)(r[0][field->name]))
  	+"</td></tr>\n";
 
   }


retval+="</table>\n";


return create_panel("Payment Information", "maroon", retval, id);

}

string|void ordercomments(object id, object s) {
string retval="";

array r=DB->query("SELECT * FROM comments WHERE orderid='" +
  id->variables->orderid + "'");
if(r && sizeof(r)>0)
  {
  foreach(r, mapping row)
    retval+="<autoformat>" + row->comments +
"</autoformat><p>&nbsp;<p>\n";
  return create_panel("Order Comments", "darkpurple", retval, id);
  }
else return "";
}

string|int gentable(object id, object s, string table, string ignore, void|int worrytype){

string retval="";
array r=DB->query("SELECT "+table+".*, type.name as type FROM "
		+table+",type "
		 "WHERE orderid="+ id->variables->orderid +
		 " AND type.type=" + table + ".type");

array f=DB->list_fields(table);

if(sizeof(r)==0) return "<p><b><i>Unable to find "+table+" for Order ID " + 
		   id->variables->orderid+"</b></i><p>\n";

 foreach(r, mapping row){

   string d="<table width=100% valign=top>";
   string type=row->type;
   m_delete(row, "type");
array wx=DB->query("SELECT status FROM orders WHERE id='" +
id->misc->ivend->orderid + "'");
if(((int)(wx[0]->status) > 1)|| id->variables->print);

else if(!id->variables->edit_data || id->variables->edit_data!=type)
  retval+="<a href=\"./?orderid="
        + id->misc->ivend->orderid + "&edit_data=" + type +
        "\"><img src=\"" + T_O->query("mountpoint") +
"ivend-image/edit.gif\" alt=\"Edit\" border=0></a>\n";
   if(id->variables->edit_data && id->variables->edit_data==type)
	{
	d+=DB->generate_form_from_db(table, ({}), id, ({}), row);
	}
   else 
	{
	   foreach(f, mapping field){
	     if(field->name=="updated" || field->name=="type" || field->name=="orderid" || row[field->name]==ignore) continue;
	     d+="<tr><td width=30%><font face=helvetica>"+replace(field->name, "_"," ")+"</td><td>\n";
	     if(Regexp(".@.*\.*")->match((string)row[field->name]))
	       d+="<a href=\"mailto:"+row[field->name]+"\">"+
		 row[field->name]+"</a></td></tr>\n";
	     else d+=row[field->name]+"</td></tr>\n";
	}
   }
   d+="</table>";

  retval+=create_panel(type, "navy", d, id);

 }

 return retval;

}


string|int listorder(object id, object s){

  string manifestfields="";
array mf=({});
  if(CONFIG_ROOT[module_name] && CONFIG_ROOT[module_name]->manifestfields)
{
    if(!arrayp(CONFIG_ROOT[module_name]->manifestfields)) {
      manifestfields=", products." +
CONFIG_ROOT[module_name]->manifestfields;
	mf=({CONFIG_ROOT[module_name]->manifestfields});
      }
    else {
	mf=CONFIG_ROOT[module_name]->manifestfields;
      foreach(mf, string f)
        manifestfields += ", products." + f ;
      }
  }
  string retval="<table valign=top width=100%>\n";

  array r=DB->query("SELECT orderdata.*, status.name as status " 
	+ manifestfields +" FROM "
	   "products,orderdata,status WHERE orderdata.orderid=" + 
	   id->variables->orderid + " AND status.status=orderdata.status " 
	   " AND products." + id->misc->ivend->keys->products +
	"=orderdata.id");
  if(sizeof(r)==0)
    return create_panel("Order Manifest", "darkgreen", 
			"Unable to find data for this order.", id);
  retval+="<tr><td><font face=helvetica size=-1>Select</td>\n<td align=left>"
    "<font face=helvetica size=-1>Qty</font></td>\n"
    "<td align=left><font face=helvetica size=-1>Item</font></td>\n";
foreach(mf,string f)
  retval+="<td align=left><font face=helvetica size=-1>" + 
    replace(f,"_"," ") +"</font></td>\n";
retval+="<td align=left><font face=helvetica size=-1>Options</font></td>\n";
retval+="<td align=right><font face=helvetica size=-1>Unit Price</font></td>\n"
    "<td align=right><font face=helvetica size=-1>Item Total</font></td>\n";

  foreach(r, mapping row) {
perror(sprintf("%O", id->misc->ivend->keys));
perror(sprintf("%O", row));

    retval+="<tr><td>" + (row->status=="Shipped"?"(S)" : 
	"<input type=checkbox value=ship name=\"" + 
	row->id+
      "." + row->series + "\">")+ "</td>"
      "<td>" + row->quantity + "</td><td>" + row->id 
      + "</td>";
     foreach(mf, string f) retval+="<td>" + row[f] + "</td>";
retval+="<td>\n";
array o=row->options/"\n";

  array eq=({});
foreach(o, string opt){
  array o_=opt/":";
catch(  eq+=({DB->query("SELECT description FROM item_options WHERE "
   "product_id='" + row->id + "' AND option_type='" +
   o_[0] + "' AND option_code='" + o_[1] + "'")[0]->description}));
}
        retval+=(eq*"<br>") +  "</td>\n";

retval+=	"<td align=right>" + row->price +
	"</td><td align=right>"
      + sprintf("%.2f", (float)row->price * (float)row->quantity) 
      + "</td></tr>\n";
  }

retval+="<tr><td colspan=5> &nbsp; </td></tr>\n";

// perror(sprintf("%O", id->variables) + "\n");

if(id->variables["commitli.x"]){ // commit the lineitem change
  DB->query("UPDATE lineitems SET value=" +
id->variables[id->variables->commit] + " WHERE orderid='" +
id->variables->orderid + "' AND lineitem='" + id->variables->commit +
"'");
T_O->report_status("Changed Lineitem " + id->variables->commit + ": " +
id->variables[id->variables->commit],
                id->variables->orderid || "NA", "handleorders", id);

 }

r=DB->query("select * from lineitems where orderid='"+
id->variables->orderid + "'");

   foreach(r, mapping row) {

 retval+="<tr>\n"
	"<td colspan=" + (sizeof(mf) + 5) + " align=right><font "
	"face=helvetica>" +
 capitalize((row->extension || row->lineitem)) 
	+"</td>\n<td align=right>";
array wx=DB->query("SELECT status FROM orders WHERE id='" +
id->variables->orderid + "'");
if(((int)(wx[0]->status) > 1)|| id->variables->print) retval+= row->value
+
  "</td><td></td></tr>\n";

else if(!id->variables->editli || id->variables->editli!=row->lineitem)
  retval+= row->value + "</td><td><a href=\"./?orderid="
	+ id->variables->orderid + "&editli=" + row->lineitem + 
	"\"><img src=\"" + T_O->query("mountpoint") +
"ivend-image/edit.gif\" alt=\"Edit\" border=0></a></td></tr>\n";
 else  {
  retval+="<input type=text size=7 name=\"" + row->lineitem +
   "\" value=\"" + row->value + "\"></td><td><input alt=\"Commit\""
   " type=image name=\"commitli\" value=\"" + row->lineitem +
   "\" src=\"" + T_O->query("mountpoint") +
   "ivend-image/commit.gif\" border=0>"
   "<input type=hidden name=commit value=\"" + row->lineitem 
	+ "\"></td></tr>\n";  
  } 
 }

float tax=T_O->get_tax(id, id->variables->orderid);

  retval+="<tr>\n"
	"<td colspan=" + (sizeof(mf) + 5) + " align=right><font "
	"face=helvetica>Sales Tax</td>"
	"<td align=right>" + sprintf("%.2f", tax) + "</td></tr>\n";

float gt=T_O->get_grandtotal(id, id->variables->orderid);
  retval+="<tr>\n"
	"<td colspan=" + (sizeof(mf) + 5) + " align=right><font "
	"face=helvetica><b>Grand Total</b></td>"
	"<td align=right><b>" + sprintf("%.2f", gt) + "</b></td></tr>\n";

  retval+="</table>\n";
  return create_panel("Order Manifest", "darkgreen", retval, id);

}


void dodelete(string orderid, object id){

  array tables=({"orders", "orderdata", "lineitems", 
    "customer_info", "payment_info"});

  foreach(tables, string t)
   DB->query("DELETE FROM " + t + " WHERE orderid='"
	+ orderid +"'");

  return;

}

void send_notification(object id, string orderid, string type){

if(!type) return;

string note;
note=Stdio.read_file(id->misc->ivend->config->general->root+"/notes/" +
type +".txt");
if(note) {

  string subject,sender, recipient;
  sscanf(note, "%s\n%s\n%s\n%s", sender, recipient, subject, note);
  array r=DB->query("SELECT " + recipient + " FROM " 
	" customer_info WHERE orderid='"+orderid+"' AND "
                   "type=0");
  recipient=r[0][recipient];
  note=replace(note,"#orderid#",(string)orderid);

  object message=MIME.Message(note, (["MIME-Version":"1.0",
                                     "To":recipient,
				     "X-Sender":"iVend 1.0",
                                     "Subject":subject
                                     ]));


  if(!Commerce.Sendmail.sendmail(sender, recipient, (string)message))
   perror("Error sending " + type  + " note for " +
        id->misc->ivend->st + "!\n");

}      

T_O->report_status("Sent Notification message: " + type,
                id->variables->orderid || "NA", "handleorders", id);
  return;
}

string|int delete_order(string orderid, object id){
perror("doing delete_order\n");
array orders_to_archive;
orders_to_archive=DB->query("SELECT * FROM orders WHERE id='" + orderid +
"'");
foreach(orders_to_archive, mapping or){
 array tables=({"orderdata", "shipments", "customer_info",
	"payment_info", "comments", "lineitems", "activity_log"});
 foreach(tables, string t){

  catch(    DB->query("DELETE FROM " + t + " WHERE orderid='" + or->id +
	"'"));
}
catch(    DB->query("DELETE FROM orders WHERE id='" + or->id + "'"));
perror("archived order " + or->id + "\n");
}
return 1;
}

string|int archive_order(string orderid, object id){
string retval="";
array orders_to_archive;
orders_to_archive=DB->query("SELECT * FROM orders WHERE id='" + orderid +
  "'");
string t;
  foreach(orders_to_archive, mapping or){
retval+="<order id=\"" + or->id + "\">\n"
	"<created>" + or->created + "</created>\n"
	"<updated>" + or->updated + "</updated>\n"
	"<status>" + or->status + "</status>\n"
	"<notes>" + (or->notes||"") + "</notes>\n";
    array tables=({"orderdata", "shipments", "customer_info",
	"payment_info", "lineitems", "activity_log", "comments"});
    foreach(tables, t){
      array fields=DB->list_fields(t);
      array r=DB->query("SELECT * FROM " + t + " WHERE orderid='" +
	or->id + "'");
      foreach(r, mapping row){	
	retval+="<record>\n";
	retval+="<table>" + t + "</table>\n";
        foreach(fields, mapping f){
	  retval+="<data field=\"" + f->name + "\" type=\"" + f->type +
	    "\">" + row[f->name] + "</data>\n";
  	}
    retval+="</record>\n";
          }
      
        }
    retval+="</order>\n";

perror("export/archived order " + or->id + "\n");
     } 

return retval;

}

string|mapping archive_orders(string mode, object id){
 string retval="";
 mapping v=id->variables;

 if(!v->archive){
 // return the usage screen.
 retval+="<form action=\"./\">\n"
	"<input type=hidden name=archive value=1>\n"
	"Please select the orders you would like to archive.<p>";

 retval+="<input type=radio name=archiveby value=days checked> "
	"Archive all closed/cancelled orders more than "
	"<input type=text size=3 name=days value=30> days old.<br>"; 
 retval+="<input type=radio name=archiveby value=orderid> "
	"Archive order #"
	"<input type=text size=5 name=orderid>.<p>";
 retval+="<input type=checkbox name=delete value=yes checked> Delete Orders After Archiving?<p>\n";
 retval+="<input type=submit value=\"Archive\"></form>\n";
 }

 else {

  if(v->doit){
  array orders_to_archive;
  if(v->archiveby=="orderid")
   orders_to_archive=DB->query("SELECT * FROM orders,status WHERE "
	"(status.name='Shipped' or status.name='Cancelled') AND "
	"id='" + v->orderid + "' AND orders.status=status.status");
  else if(v->archiveby=="days")
   orders_to_archive=DB->query("SELECT * FROM orders,status WHERE "
	"TO_DAYS(NOW()) - TO_DAYS(updated) > " + v->days 
	+ " AND (status.name='Shipped' or status.name='Cancelled') "
	" AND orders.status=status.status" );

  foreach(orders_to_archive, mapping or){
	retval+=archive_order(or->id, id);
     } 
#if constant(Protocols.SMTP.client)
if(v->method=="Mail Archive" && v->email!=""){
 object dns=Protocols.DNS.client();
string server=dns->get_primary_mx(gethostname());
if(!server) server="localhost";
 if(catch(
  Protocols.SMTP.client(server)->simple_mail(v->email, 
	"Archive Orders " + (orders_to_archive*", "), "ivend@" +
	gethostname(), retval)
 ))
	return "An error occurred while mailing your archive request.<p>"
	 "Your archive request was cancelled. Please try again later.";
  if(id->variables->delete=="yes")
  foreach(orders_to_archive, mapping or){
	delete_order(or->id, id);
     } 

  return "Your orders have been mailed to " + v->email + ".<p>\n"
	"<a href=./>Click here to continue.</a>\n";
}
else {
#endif
      T_O->add_header(id, "Content-Disposition", 
	"inline; filename=" + "order" +(sizeof(orders_to_archive)==1?("_"+
orders_to_archive[0]->id):"") + ".xml");
  if(id->variables->delete=="yes")
  foreach(orders_to_archive, mapping or){
	delete_order(or->id, id);
     } 
    return http_rxml_answer(retval, id, 0, "text/archive");
#if constant(Protocols.SMTP.client)
    }
#endif
   }
  else {

  array orders_to_archive;
  if(v->archiveby=="orderid")
   orders_to_archive=DB->query("SELECT * FROM orders,status WHERE "
	"(status.name='Shipped' or status.name='Cancelled') AND "
	"id='" + v->orderid + "' AND orders.status=status.status");
  else if(v->archiveby=="days")
   orders_to_archive=DB->query("SELECT * FROM orders,status WHERE "
	"TO_DAYS(NOW()) - TO_DAYS(updated) > " + v->days 
	+ " AND (status.name='Shipped' or status.name='Cancelled') "
	" AND orders.status=status.status" );

  retval+="Found " + sizeof(orders_to_archive) + " orders"
	" to archive.";
  if(sizeof(orders_to_archive)>0)
	retval+=
	" Click the button below to generate the "
	" archive file.<P>"
	"<form action=\"./\">\n"
	"<input type=hidden name=delete value=\"" + id->variables->delete
	 + "\">\n"
	"<input type=hidden name=archive value=1>\n"
	"<input type=hidden name=days value=" + v->days + ">\n"
	"<input type=hidden name=orderid value=" + v->orderid + ">\n"
	"<input type=hidden name=archiveby value=" + v->archiveby +">\n"
	"<input type=hidden name=doit value=1>\n"
#if constant(Protocols.SMTP.client)
	"<input type=text size=40 name=email> Email Address<br>\n"
	"<input type=submit name=method value=\"Mail Archive\">\n"
#endif
	"<input type=submit name=method value=\"Download Archive\">\n"
	"</form>";
  else retval+="<p><a href=\"./\">Click here to start over.</a>";

  }
 }
 return retval;
}

string view_activity_log(string mode, object id){
  string retval="";

if(id->variables->orderid){
  array r;
  if(id->variables->orderlog=="")
    r=DB->query("SELECT * FROM activity_log ORDER BY time_stamp");
  else
    r=DB->query("SELECT * FROM activity_log WHERE orderid='" + 
	id->variables->orderid + "' ORDER BY time_stamp");
  if(sizeof(r)<1) retval+="Unable to find your order.";
  else {

  retval+="<table><tr><td></td><th>Date/Time</th><th>Subsystem</th><th>Message</th></tr>\n";


  foreach(r, mapping m){

  retval+="<tr><td><img src=\"" + T_O->query("mountpoint") +
	"ivend-image/severity" 
	+ m->severity + ".gif\" height=14 width=14></td><td>" 
	+ m->time_stamp + "</td><td>" + m->subsystem +
	"</td><td><autoformat>" + m->message +
	"</autoformat></td></tr>\n";

  }

  retval+="</table>\n";

  }
}

else {

  retval+="<form action=\"./\" method=post>"
	"Enter Order ID: <input name=orderid size=5 type=text> "
	"<input type=submit value=\"View Log\"></form>"; 

}
  retval+="<center>"
	"<form action=''><input type=reset value='Close' "
	"onClick='javascript:window.close()'></form>"
	"</center>";

  return retval;
}

string show_orders(string mode, object id){
string retval="";
string status="";
if(id->variables->orderid) status=DB->query(
      "SELECT status FROM status WHERE name='Shipped' AND tablename='orders'"
      )[0]->status;

 if(id->variables->valpay && id->variables->orderid){
// perror("validating Payment\n");
if(CONFIG_ROOT[module_name]->deletecard=="Yes"){
  string cn;
string key="";
object privs=Privs("Reading Key File");
if(id->misc->ivend->config->general->privatekey)
  key=Stdio.read_file(id->misc->ivend->config->general->privatekey);
privs=0;
array r=DB->query("SELECT payment_info.*, status.name as status from "
	 "payment_info,status WHERE orderid=" + id->variables->orderid +
	 " AND status.status=payment_info.status");
if(r[0]->Card_Number[0..3]=="iVEn"){
 cn=Commerce.Security.decrypt(r[0]->Card_Number,key);
} else cn=r[0]->Card_Number;
if(cn && stringp(cn)) {
  array cn2=cn/"";
  int j=sizeof(cn2);
  for(int l=0; l<(j-4); l++)
   cn2[l]="X";
  cn=cn2*"";
  }
   array r=DB->query(
       "SELECT status FROM status WHERE name='Validated'");
   DB->query("UPDATE payment_info SET status=" + 
       r[0]->status + ", card_number='" + cn + "'"
	" WHERE orderid='" + id->variables->orderid+"'");
   if(id->variables->authorization_id!="")
	DB->query("UPDATE payment_info SET authorization='" + 
		id->variables->authorization_id + "' WHERE orderid='"
		+ id->variables->orderid + "'");
}
else {
   array r=DB->query(
       "SELECT status FROM status WHERE name='Validated'");
   DB->query("UPDATE payment_info SET status=" + 
       r[0]->status +
	" WHERE orderid='" + id->variables->orderid+"'");
   if(id->variables->authorization_id!="")
	DB->query("UPDATE payment_info SET authorization='" + 
		id->variables->authorization_id + "' WHERE orderid='"
		+ id->variables->orderid + "'");
}
   array r=DB->query(
       "SELECT status.name, orders.status from status, orders "
	"WHERE status.status=orders.status and orders.id= '" +
	id->variables->orderid + "'");  
   if(r[0]->name=="Error"){
       array r1=DB->query( 
	"SELECT status FROM status WHERE name='In Progress' "
	"AND tablename='orders'");
	T_O->report_status("Changed order status to 'In Progress.'", 
		id->variables->orderid || "NA", "handleorders", id);
       DB->query("UPDATE orders SET status=" + 
	 r1[0]->status + ",updated=NOW() WHERE id='" +
	id->variables->orderid + "'"); 
	}
	T_O->report_status("Validated Payment with authorization "
		+ (string)(id->variables->authorization_id) + ".", 
		id->variables->orderid || "NA", "handleorders", id);

 } 

 if(id->variables->rejpay && id->variables->orderid){

   array r=DB->query(
       "SELECT status FROM status WHERE name='Rejected'");
   DB->query("UPDATE payment_info SET status=" + 
       r[0]->status + " WHERE orderid='" + id->variables->orderid+"'");

   array r=DB->query(
       "SELECT status FROM status WHERE name='Error'");
        T_O->report_status("Changed order status to 'Error.'",
                id->variables->orderid || "NA", "handleorders", id); 
   DB->query("UPDATE orders SET status=" + 
       r[0]->status + " WHERE id='" + id->variables->orderid+"'");

	id->misc->ivend->this_object->trigger_event("rejectpayment",id,
		(["orderid": id->variables->orderid]));
   send_notification(id, id->variables->orderid, "rejpay");

 } 

 if(id->variables->docancel && id->variables->orderid){
   if(id->variables->reallydocancel){
   array r=DB->query(
       "SELECT status FROM status WHERE name='Cancelled'");
   DB->query("UPDATE payment_info SET status=" + 
       r[0]->status + " WHERE orderid='" + id->variables->orderid+"'");
   array r=DB->query(
       "SELECT status FROM status WHERE name='Cancelled'");
        T_O->report_status("Changed order status to 'Cancelled.'",
                id->variables->orderid || "NA", "handleorders", id); 
   DB->query("UPDATE orders SET status=" + 
       r[0]->status + " WHERE id='" + id->variables->orderid+"'");

	id->misc->ivend->this_object->trigger_event("cancelorder",id,
		(["orderid": id->variables->orderid]));
  }
  else return "<b>Do you really want to cancel this order?</b>"
	"<table><tr><td>"
	"<form action=\"./\" method=post>"
	"<input type=hidden name=reallydocancel value=1>\n"
	"<input type=hidden name=docancel value=1>\n"
	"<input type=hidden name=orderid value=\"" +
		id->variables->orderid + "\">\n"
	"<input type=submit value=\"Yes\">"
	"</form>\n"
	"</td><td>\n"
	"<form action=\"./\" method=post>"
	"<input type=hidden name=orderid value=\"" +
		id->variables->orderid + "\">\n"
	"<input type=submit value=\"No\">"
	"</form></td></tr></table>\n";
 }

 if(id->variables->doship && id->variables->orderid){

   array r=DB->query(
      "SELECT status.name,payment_info.orderid from status,payment_info "
      "WHERE payment_info.orderid='" + id->variables->orderid + "' AND "
      "status.status=payment_info.status");

   if(r && (sizeof(r)>0) && r[0]->name !="Validated") 
     return "Payment information has not been validated.\n" 
       "Cannot Ship order without validation.<p>";


  int already_shipped_some, shipped_any, shipped_some, shipped_all=0;
  array r=({});
  r=DB->query("SELECT * FROM shipments WHERE orderid='" +
   id->variables->orderid + "'");
  if(sizeof(r)>0)
    already_shipped_some=1;
       array n= DB->query(
	"SELECT id FROM orderdata WHERE orderid='" +
	id->variables->orderid + "' AND status !=" +status);
  if(sizeof(n)>0) {
   switch(id->variables->doship){
   perror("sizeof n: " + sizeof(n) + "\n");
    case "Ship Selected":
       foreach(indices(id->variables), string v)
	 if(Regexp(".\..")->match(v) && id->variables[v]=="ship") {
       array t=v/".";
       DB->query("UPDATE orderdata SET status=" + status
         + " WHERE orderid='" + id->variables->orderid + "' AND id='"
	 + t[0] + "' AND series="+ t[1] );
       array o=DB->query(
         "SELECT * FROM orderdata WHERE orderid='" + 
	 id->variables->orderid + "' AND id='" + t[0] + "' AND series=" +t[1]);
       foreach(o, mapping l){
         shipped_some=1;
         shipped_any=1;
        T_O->report_status("Shipped Item: "+ l->id + " Instance: " +
		l->series + " Qty: " +
		l->quantity,
                id->variables->orderid || "NA", "handleorders", id); 
	 string query="INSERT INTO shipments VALUES('" + id->variables->orderid
	 +"','" + l->id + "'," + l->series + "," + l->quantity + ",'" +
	 id->variables->tracking_id + "',NOW(),1)";
	 DB->query(query);
	id->misc->ivend->this_object->trigger_event("ship",id,
		(["orderid": id->variables->orderid, "product_id" :
		l->id, "series": l->series, "quantity": l->quantity]));
       }
     }
    break;
    case "Ship All":
    array r=DB->query("SELECT orderdata.*, status.name as status FROM "
	   "products,orderdata,status WHERE orderdata.orderid=" + 
	   id->variables->orderid + " AND status.status=orderdata.status " 
	   " AND products." + id->misc->ivend->keys->products +
	"=orderdata.id and status.name!='Shipped'");

     DB->query("UPDATE orderdata SET status=" + status
       + " WHERE orderid='" + id->variables->orderid + "'");

       foreach(r, mapping row){
         if(row->status=="Shipped") continue;
        T_O->report_status("Shipped Item: "+ row->id + " Instance: " +
		row->series + " Qty: " +
		row->quantity,
                id->variables->orderid || "NA", "handleorders", id); 

	 string query="INSERT INTO shipments VALUES('" + id->variables->orderid
	 +"','" + row->id + "'," + row->series + "," + row->quantity + ",'" +
	 id->variables->tracking_id + "',NOW(),1)";
	 DB->query(query);
	 shipped_any=1;
         shipped_all=1;
       }

    break;
  }       

       array n= DB->query(
	"SELECT id FROM orderdata WHERE orderid='" +
	id->variables->orderid + "' AND status !=" +status);
       if(sizeof(n)==0) shipped_all=1;

       if(shipped_all) {
/*
	 DB->query(
             "UPDATE payment_info SET Card_Number='',Expiration_Date='' WHERE orderid='" +
	     id->variables->orderid +"'");
*/
	 DB->query("UPDATE orders SET status=" + status
	   + ", updated=NOW() WHERE id='" + id->variables->orderid + "'");    
       array r=DB->query( 
	"SELECT status FROM status WHERE name='Shipped' "
	"AND tablename='orders'");
	T_O->report_status("Order has been completely shipped. Order CLOSED.", 
		id->variables->orderid || "NA", "handleorders", id);
       DB->query("UPDATE orders SET status=" + 
	 status + ",updated=NOW() WHERE id='" +
	id->variables->orderid + "'"); 
		id->misc->ivend->this_object->trigger_event("shipall",id,
		(["orderid": id->variables->orderid]));
       }

     else if(shipped_some){
       array r=DB->query( 
	"SELECT status FROM status WHERE name='Partially Shipped' "
	"AND tablename='orders'");
       DB->query("UPDATE orders SET status=" + 
	 r[0]->status + ",updated=NOW() WHERE id='" +
	id->variables->orderid + "'"); 
	id->misc->ivend->this_object->trigger_event("pship",id,
		(["orderid": id->variables->orderid]));
     }

  }
 }

if(id->variables->dodelete && id->variables->orderid){
  dodelete(id->variables->orderid, id);
  m_delete(id->variables, "orderid");

  }

if(id->variables->notes){
  DB->query("UPDATE orders SET notes=" + id->variables->notes + ","
	"updated=NOW() WHERE "
	"id=" + id->variables->orderid);
  }


if(id->variables->delete){
  DB->query("DELETE FROM display_orders WHERE id=" 
+id->variables->orderid);
  retval+="Order Deleted Successfully.\n";

}

else if(id->variables->orderid) {

if(id->variables->print) {
  ADMIN_FLAGS=NO_BORDER;
  retval+="<BODY onLoad=\"this.print()\">\n";
}
if(id->variables->export) {
  ADMIN_FLAGS=NO_BORDER;
  T_O->add_header(id, "Content-Disposition",
    "inline; filename=" + "order" + id->variables->orderid + ".xml");
  T_O->add_header(id, "Content-Type", "application/x-ivend");
    return archive_order(id->variables->orderid, id);
 }

if(!id->variables->print)
  retval+="<form action=\"./orders\" method=post>\n"
    "<input type=hidden name=orderid value=\"" + 
    id->variables->orderid + "\">\n";

  retval+=show_orderdetails(id->variables->orderid, DB, id);
if(!id->variables->print) {
  retval+="<obox title=\"<font face=helvetica,arial>Order Actions</font>\">";
   array r=DB->query(
      "SELECT status.name,payment_info.orderid from status,payment_info "
      "WHERE payment_info.orderid='" + id->variables->orderid + "' AND "
      "status.status=payment_info.status");
if(r && sizeof(r)>0 && r[0]->name!="Validated" && !id->variables->print)
   retval+="<input type=submit name=valpay value=\"Validate Payment\"> &nbsp; \n"
    "<input type=submit name=rejpay value=\"Reject Payment\"><br>\n"
    "<input type=submit name=docancel value=\"Cancel Order\"> &nbsp; "
    "Authorization ID: <input type=text size=20 name=\"authorization_id\"> &nbsp; ";
else if(sizeof(DB->query(
	"SELECT id FROM orderdata WHERE orderid='" +    
	id->variables->orderid + "' AND status !=" +status))>0)
retval+="<input type=submit name=doship value=\"Ship All\"> &nbsp; "
    "<input type=submit name=doship value=\"Ship Selected\"> &nbsp; "
    "<input type=submit name=docancel value=\"Cancel Order\"> &nbsp; "
    "Tracking ID: <input type=text size=20 name=\"tracking_id\"> &nbsp; ";
retval+= "<input type=submit name=export value=\"Export Order\"><br>"
	"<input type=submit name=print value=\"Format for Printing\"><br>"
    "</form>";
if(!id->variables->print) {
retval+=T_O->open_popup( "View Activity Log",
                                 id->not_query, "View_Activity_Log" ,
                                (["orderid" : id->variables->orderid,
				"height": 500, "width":550]) ,id);

retval+="</obox>";
  }
  }
    }

else {
  retval+="<br>Click on an order id to display an order.\n\n<br>";

  array s=DB->query("SELECT status, name from status where tablename='orders'");

//  foreach(s, mapping row) {
int numlines=(int)CONFIG_ROOT[module_name]->showlines ||10;
  int i=(int)(DB->query("SELECT count(*) as c from orders"))[0]->c;
// " where status=" + row->status)[0]->c);
  array r=DB->query("SELECT id, "
//	"DATE_FORMAT(updated, 'm/d/y h:m') as 
	"updated, notes, status.name as status "
	"FROM orders,status "
//	"WHERE status=" + row->status + 
        " WHERE status.status=orders.status ORDER BY updated DESC LIMIT "
	+(id->variables->page?
		((((int)id->variables->page)*numlines
-numlines) +
","):"") + numlines);

int numpages=0;
numpages=((int)i)/numlines;
if((int)i%numlines) numpages ++;


  if(sizeof(r)>0) {
  retval+="<table valign=top cellspacing=0 cellpadding=0>\n<tr>"
	"<td colspan=4 align=center>";
//  retval+="<font size=+1>" + row->name + "</font><br>";

  retval+="<i><font size=2>" +
(((int)id->variables->page||1 )>1?("<a href=\"./?page="+
(((int)id->variables->page) -1) +"\">"):"")+

"&lt;&lt;" +
((((int)id->variables->page||1 )>1)?"</a>":"") 
 +" &nbsp; Showing page " +
(((int)id->variables->page)||1 )+ " of " + 
numpages + " &nbsp; " +
(((int)id->variables->page||1 )<numpages?("<a href=\"./?page="+
(((int)id->variables->page||1) +1) +"\">"):"")+
  "&gt;&gt;" + 
((((int)id->variables->page ||1 )<numpages)?"</a>":"") 

+ "<br></font></i>";

  retval+="</td></tr>\n";
  retval+="<tr><td></td>\n"
	"<td bgcolor=navy><font color=white "
    " face=helvetica> <b>Order ID</b> </font></td>\n"
	"<td bgcolor=navy><font color=white face=helvetica><b>"
	"Status</b></td>\n"
    "<td bgcolor=navy><font color=white face=helvetica><b>Record "
    "Updated</font></td>\n"
    "<td bgcolor=navy><font color=white "
    "face=helvetica><b>Notes</b></font></td>\n</tr>";

  foreach(r, mapping row){
    retval+="<tr>\n";
    retval+="<td> <img src=\"" + 
	id->misc->ivend->this_object->query("mountpoint")+
	  "ivend-image/rbutton.gif\"> "
	"</td><td bgcolor=gray align=center> <a href=\"./?orderid="
	+row->id+"\">"+
	row->id+"</a> </td>";
    retval+="<td>"+ row->status+" </td>\n";
    retval+="<td> "+(row->updated)+" </td><td> " + (row->notes||"") +
 " </td>\n"
	"</tr>\n";

    }

    retval+="</table>\n";
  }
// }
}

if(id->variables->print) {
  retval+="</BODY>\n";
}

return retval;

}




string|int show_orderdetails(string orderid, object s, object id){

string retval="";

  array r=DB->query("SELECT id, status.name as status, status.status as status_code, "
//	"DATE_FORMAT(updated, 'm/d/y h:m') as "
	"updated, "
//	"DATE_FORMAT(created, 'm/d/y h:m') as "
	"created, "
	"notes "
	"FROM orders,status WHERE id=" 
	+id->variables->orderid +" AND orders.status=status.status");
  if(sizeof(r)!=1) retval="Error finding the requested record.\n";

  else {
  if(r[0]->status_code=="0") {
       array r1=DB->query( 
	"SELECT status FROM status WHERE name='In Progress' "
	"AND tablename='orders'");
	T_O->report_status("Changed order status to 'In Progress.'", 
		id->variables->orderid || "NA", "handleorders", id);
       DB->query("UPDATE orders SET status=" + 
	 r1[0]->status + ",updated=NOW() WHERE id='" +
	id->variables->orderid + "'"); 
	}

	retval+=create_panel("Order Details","hunter","<table valign=top width=100%>"
	"<tr><td><font face=helvetica>"
	"Order ID</td><td>"+r[0]->id+"</td></tr>\n"
	"<tr><td width=30%><font face=helvetica>Status</td><td>"+r[0]->status+"</td></tr>\n"
	"<tr><td width=30%><font face=helvetica>Last Action</td><td>"+r[0]->updated+"</td></tr>\n"
	"<tr><td width=30%><font face=helvetica>Creation</td><td>"+r[0]->created+"</td></tr>\n"
	"<tr><td width=30%><font face=helvetica>Notes</td><td><pre>"+
	(r[0]->notes||"")+"</pre></td></tr>\n"
	"</table>"
	"\n\n", id);

//do we need to update customer info?

if(id->variables->orderid) id->misc->ivend->orderid=id->variables->orderid;

if(id->variables["commitci.x"]){ // commit the lineitem change

  DB->query("UPDATE customer_info SET value=" +
id->variables[id->variables->commit] + " WHERE orderid='" +
id->variables->orderid + "' AND lineitem='" + id->variables->commit +
"'");
T_O->report_status("Changed Lineitem " + id->variables->commit + ": " +
id->variables[id->variables->commit],
                id->variables->orderid || "NA", "handleorders", id);

 }


	 // get address information...

retval+=gentable(id, s, "customer_info", "N/A", 1);
	
retval+="<p>\n" + genpayment(id, s);

retval+="<p>\n" + listorder(id, s);

retval+="<p>\n" + ordercomments(id, s);
}
return retval;

}

mixed register_admin(){

return ({

	([ "mode": "menu.main.Orders.View_Activity_Log",
		"handler": view_activity_log,
		"security_level": 1 ]),
	([ "mode": "menu.main.Orders.View_Orders",
		"handler": show_orders,
		"security_level": 1 ]),
	([ "mode": "menu.main.Orders.Archive_Orders",
		"handler": archive_orders,
		"security_level": 1 ])
	
	});

}

array query_preferences(void|object id) {

  if(!catch(DB) && sizeof(fields)<=0) {

     array f2=DB->list_fields("products");
     foreach(f2, mapping m)
	fields +=({m->name});
    }

  if(!catch(DB) && sizeof(cc_fields)<=0) {

     array f2=DB->list_fields("payment_info");
     foreach(f2, mapping m)
	cc_fields +=({m->name});
    }
   
  return ({ 
	({"manifestfields", "Manifest Fields", 
	"Fields to be included in the order manifest listing.",
	VARIABLE_MULTIPLE,
	"name",
	fields
	}) ,

	({"card_number_field", "CC Number location", 
	"Field that contains Credit Card Number.",
	VARIABLE_SELECT,
	"Card_Number",
	cc_fields
	}) ,

	({"showlines", "Number of orders to show", 
	"Number of orders to show per page.",
	VARIABLE_INTEGER,
	12,
	0
	}) ,

	({"deletecard", "Delete Card Number?",
		"Should Credit Card Number be deleted following verification?", 
	VARIABLE_SELECT,
	"Yes",
	({"Yes", "No"})
	})


	});

}
