#!NOMODULE

#include <ivend.h>

#define CONFIG id->misc->ivend->config

constant module_name = "Stock Order Handler";
constant module_type = "order";

int saved=1;
array fields=({});


string|int show_orderdetails(string orderid, object s, object id);

string create_panel(string name, string color, string contents){

  string retval="";

   retval+="<table width=80%><tr><td colspan=1 bgcolor=" + color +">\n";
   retval+=" &nbsp; <font face=helvetica color=white><b>"+ name +"</font></b> &nbsp; </td></tr>\n";
   retval+="<tr><td>\n" + contents + "\n</td></tr>\n</table>\n";

  return retval;
}

string|int genpayment(object id, object s){
string retval="";
string key="";
if(id->misc->ivend->config->general->privatekey)
  key=Stdio.read_file(id->misc->ivend->config->general->privatekey);
array r=DB->query("SELECT payment_info.*, status.name as status from "
	 "payment_info,status WHERE orderid=" + id->variables->orderid +
	 " AND status.status=payment_info.status");

array f=DB->list_fields("payment_info");

if(sizeof(r)==0) return create_panel("Payment Information", "maroon", 
	      "Unable to find Payment Info for Order ID " + 
		   id->variables->orderid);

retval="<table width=100%>";
 foreach(f, mapping field){
     if(field->name=="updated" || field->name=="type" || field->name=="orderid") continue;
   retval+="<tr><td width=30%><font face=helvetica>"+ replace(field->name,"_"," ")
     +"</font>\n</td>\n<td>"+
  (r[0][field->name][0..3]=="iVEn"?
    (Commerce.Security.decrypt(r[0][field->name],key)+"*"):r[0][field->name])
  	+"</td></tr>\n";
 
   }


retval+="</table>\n";


return create_panel("Payment Information", "maroon", retval);

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
   string d="<table width=100%>";
   string type=row->type;
   m_delete(row, "type");
   foreach(f, mapping field){
     if(field->name=="updated" || field->name=="type" || field->name=="orderid" || row[field->name]==ignore) continue;
     d+="<tr><td width=30%><font face=helvetica>"+replace(field->name, "_"," ")+"</td><td>\n";
     if(Regexp(".@.*\.*")->match((string)row[field->name]))
       d+="<a href=\"mailto:"+row[field->name]+"\">"+
	 row[field->name]+"</a></td></tr>\n";
     else d+=row[field->name]+"</td></tr>\n";
   }
   d+="</table>";
  retval+=create_panel(type, "navy", d);
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
  string retval="<table width=100%>\n";

  array r=DB->query("SELECT orderdata.*, status.name as status " 
	+ manifestfields +" FROM "
	   "products,orderdata,status WHERE orderdata.orderid=" + 
	   id->variables->orderid + " AND status.status=orderdata.status " 
	   " AND products." + id->misc->ivend->keys->products +
	"=orderdata.id");
  if(sizeof(r)==0)
    return create_panel("Order Manifest", "darkgreen", 
			"Unable to find data for this order.");
  retval+="<tr><td><font face=helvetica size=-1>Select</td>\n<td align=left>"
    "<font face=helvetica size=-1>Qty</font></td>\n"
    "<td align=left><font face=helvetica size=-1>Item</font></td>\n";
foreach(mf,string f)
  retval+="<td align=left><font face=helvetica size=-1>" + 
    replace(f,"_"," ") +"</font></td>\n";
retval+="<td align=right><font face=helvetica size=-1>Unit Price</font></td>\n"
    "<td align=right><font face=helvetica size=-1>Item Total</font></td>\n";

  foreach(r, mapping row) {
    retval+="<tr><td>" + (row->status=="Shipped"?"(S)" : 
	"<input type=checkbox value=ship name=\"" + 
	row[id->misc->ivend->keys->products ]+
      "." + row->series + "\">")+ "</td>"
      "<td>" + row->quantity + "</td><td>" + row->id 
      + "</td>";
     foreach(mf, string f) retval+="<td>" + row[f] + "</td>";
retval+=	"<td align=right>" + row->price +
	"</td><td align=right>"
      + sprintf("%.2f", (float)row->price * (float)row->quantity) 
      + "</td></tr>\n";
  }

retval+="<tr><td colspan=5> &nbsp; </td></tr>\n";

r=DB->query("select * from lineitems where orderid='"+
id->variables->orderid + "'");

   foreach(r, mapping row) {

  retval+="<tr>\n<td></td><td></td>";
  foreach(mf, string f)
    retval+="<td></td>\n";
  retval+="\n<td align=right><font "
	"face=helvetica>" +
 capitalize(row->lineitem) + " "
        + (row->extension||"")
	+"</td>\n<td> &nbsp; </td><td align=right>" 
	+ row->value + "</td></tr>\n";
  
  }

r=DB->query("SELECT SUM(value) as grandtotal FROM lineitems WHERE "
	"orderid='"+ id->variables->orderid + "'");

  retval+="<tr><td></td><td></td>";
foreach(mf, string f)
    retval+="<td></td>\n";   
  retval+="<td align=right>"
	"<font face=helvetica><b>Grand Total</b></td><td></td>"
	"<td align=right><b>" + r[0]->grandtotal + "</b></td></tr>\n";

  retval+="</table>\n";
  return create_panel("Order Manifest", "darkgreen", retval);

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


  return;
}

string archive_orders(string mode, object id){
 string retval="";
 mapping v=id->variables;

 if(!v->archive){
 // return the usage screen.
 retval+="<form action=\"./\">\n"
	"<input type=hidden name=archive value=1>\n";

 retval+="Archive all orders more than "
	"<input type=text size=3 name=days value=30> days old. "; 

 retval+="<input type=submit value=\"Archive\"></form>\n";
 }

 else {

  array orders_to_archive=DB->query("SELECT * FROM orders WHERE "
	"TO_DAYS(NOW()) - TO_DAYS(updated) > " + v->days );
  retval+="Archiving " + sizeof(orders_to_archive) + " orders.<p>";
  foreach(orders_to_archive, mapping o){
perror(sprintf("%O", o));
retval+="Records for " + o->id+ "<br>";
    array tables=({"orderdata", "shipments", "customer_info",
	"payment_info"});
    foreach(tables, string t){
      array fields=DB->list_fields(t);
      array r=DB->query("SELECT * FROM " + t + " WHERE orderid='" +
	o->id + "'");
      array fl,dl=({});
      foreach(r, mapping row){	
        foreach(fields, mapping f){
	  fl+=({f->name});
	  dl+=({DB->quote(row[f->name])});
	}
        retval+="INSERT INTO " + t + " (" + (fl*",") + ") VALUES("
	+ (dl*",")  +")\n";
        }
      
      }
    }

 }

 return retval;
}

string show_orders(string mode, object id){
string retval="";
string status="";
if(id->variables->orderid) status=DB->query(
      "SELECT status FROM status WHERE name='Shipped' AND tablename='orders'"
      )[0]->status;

 if(id->variables->valpay && id->variables->orderid){

   array r=DB->query(
       "SELECT status FROM status WHERE name='Validated'");
   DB->query("UPDATE payment_info SET status=" + 
       r[0]->status + " WHERE orderid='" + id->variables->orderid+"'");

   array r=DB->query(
       "SELECT status.name, orders.status from status, orders "
	"WHERE status.status=orders.status and orders.id= '" +
	id->variables->orderid + "'");  
   if(r[0]->name=="Error"){
       array r1=DB->query( 
	"SELECT status FROM status WHERE name='In Progress' "
	"AND tablename='orders'");
       DB->query("UPDATE orders SET status=" + 
	 r1[0]->status + ",updated=NOW() WHERE id='" +
	id->variables->orderid + "'"); 
	}

 } 

 if(id->variables->rejpay && id->variables->orderid){

   array r=DB->query(
       "SELECT status FROM status WHERE name='Rejected'");
   DB->query("UPDATE payment_info SET status=" + 
       r[0]->status + " WHERE orderid='" + id->variables->orderid+"'");

   array r=DB->query(
       "SELECT status FROM status WHERE name='Error'");
   DB->query("UPDATE orders SET status=" + 
       r[0]->status + " WHERE id='" + id->variables->orderid+"'");

   send_notification(id, id->variables->orderid, "rejpay");

 } 

 if(id->variables->docancel && id->variables->orderid){
   DB->query(
     "UPDATE payment_info SET Card_Number='',Expiration_Date='' WHERE orderid='" +
     id->variables->orderid +"'");

   array r=DB->query(
       "SELECT status FROM status WHERE name='Cancelled'");
   DB->query("UPDATE payment_info SET status=" + 
       r[0]->status + " WHERE orderid='" + id->variables->orderid+"'");
   array r=DB->query(
       "SELECT status FROM status WHERE name='Cancelled'");
   DB->query("UPDATE orders SET status=" + 
       r[0]->status + " WHERE id='" + id->variables->orderid+"'");

	id->misc->ivend->this_object->trigger_event("cancelorder",id,
		(["orderid": id->variables->orderid]));

 }

 if(id->variables->doship && id->variables->orderid){

   array r=DB->query(
      "SELECT status.name,payment_info.orderid from status,payment_info "
      "WHERE payment_info.orderid='" + id->variables->orderid + "' AND "
      "status.status=payment_info.status");

   if(r[0]->name !="Validated") 
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
	 DB->query(
             "UPDATE payment_info SET Card_Number='',Expiration_Date='' WHERE orderid='" +
	     id->variables->orderid +"'");
	 DB->query("UPDATE orders SET status=" + status
	   + ", updated=NOW() WHERE id='" + id->variables->orderid + "'");    
       array r=DB->query( 
	"SELECT status FROM status WHERE name='Shipped' "
	"AND tablename='orders'");
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

if(id->variables->print)
  ADMIN_FLAGS=NO_BORDER;

if(!id->variables->print)
  retval+="<form action=\"./orders\" method=post>\n"
    "<input type=hidden name=orderid value=\"" + 
    id->variables->orderid + "\">\n";

  retval+=show_orderdetails(id->variables->orderid, DB, id);
if(!id->variables->print)
  retval+="<obox title=\"<font face=helvetica,arial>Order Actions</font>\">";
   array r=DB->query(
      "SELECT status.name,payment_info.orderid from status,payment_info "
      "WHERE payment_info.orderid='" + id->variables->orderid + "' AND "
      "status.status=payment_info.status");
if(r[0]->name!="Validated")
   retval+="<input type=submit name=valpay value=\"Validate Payment\"> &nbsp; \n"
    "<input type=submit name=rejpay value=\"Reject Payment\"><br>\n"
    "<input type=submit name=docancel value=\"Cancel Order\"> &nbsp; ";
else if(sizeof(DB->query(
	"SELECT id FROM orderdata WHERE orderid='" +    
	id->variables->orderid + "' AND status !=" +status))>0)
retval+="<input type=submit name=doship value=\"Ship All\"> &nbsp; "
    "<input type=submit name=doship value=\"Ship Selected\"> &nbsp; "
    "<input type=submit name=docancel value=\"Cancel Order\"> &nbsp; "
    "Tracking ID: <input type=text size=20 name=\"tracking_id\"> &nbsp; ";
retval+="<input type=submit name=print value=\"Format for Printing\"><br>"
    "</obox></form>";
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
  retval+="<table cellspacing=0 cellpadding=0>\n<tr>"
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
       DB->query("UPDATE orders SET status=" + 
	 r1[0]->status + ",updated=NOW() WHERE id='" +
	id->variables->orderid + "'"); 
	}

	retval+=create_panel("Order Details","hunter","<table width=100%>"
	"<tr><td><font face=helvetica>"
	"Order ID</td><td>"+r[0]->id+"</td></tr>\n"
	"<tr><td width=30%><font face=helvetica>Status</td><td>"+r[0]->status+"</td></tr>\n"
	"<tr><td width=30%><font face=helvetica>Last Action</td><td>"+r[0]->updated+"</td></tr>\n"
	"<tr><td width=30%><font face=helvetica>Creation</td><td>"+r[0]->created+"</td></tr>\n"
	"<tr><td width=30%><font face=helvetica>Notes</td><td><pre>"+
	(r[0]->notes||"")+"</pre></td></tr>\n"
	"</table>"
	"\n\n");

	 // get address information...

retval+=gentable(id, s, "customer_info", "N/A", 1);
	
retval+="<p>\n" + genpayment(id, s);

retval+="<p>\n" + listorder(id, s);
}
return retval;

}

mapping register_admin(){

return ([

	"menu.main.Orders.View_Orders" : show_orders,
	"menu.main.Orders.Archive_Orders" : archive_orders

	]);

}

array query_preferences(void|object id) {

  if(!catch(DB) && sizeof(fields)<=0) {

     array f2=DB->list_fields("products");
     foreach(f2, mapping m)
	fields +=({m->name});
    }
   
  return ({ 
	({"manifestfields", "Manifest Fields", 
	"Fields to be included in the order manifest listing.",
	VARIABLE_MULTIPLE,
	"name",
	fields
	}) ,

	({"showlines", "Number of orders to show", 
	"Number of orders to show per page.",
	VARIABLE_INTEGER,
	12,
	0
	})


	});

}
