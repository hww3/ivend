constant module_name = "Stock Order Handler";
constant module_type = "order";

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

array r=s->query("SELECT payment_info.*, status.name as status from "
	 "payment_info,status WHERE orderid=" + id->variables->orderid +
	 " AND status.status=payment_info.status");

array f=s->list_fields("payment_info");

if(sizeof(r)==0) return create_panel("Payment Information", "maroon", 
	      "Unable to find Payment Info for Order ID " + 
		   id->variables->orderid);

retval="<table width=100%>";
 foreach(f, mapping field){
     if(field->name=="updated" || field->name=="type" || field->name=="orderid") continue;
   retval+="<tr><td width=30%><font face=helvetica>"+ replace(field->name,"_"," ")
     +"</font>\n</td>\n<td>";
   }


retval+="</table>\n";


return create_panel("Payment Information", "maroon", retval);

}

string|int gentable(object id, object s, string table, string ignore, void|int worrytype){
string retval="";
array r=s->query("SELECT "+table+".*, type.name as type FROM "+table+",type "
		 "WHERE orderid="+ id->variables->orderid +
		 " AND type.type=" + table + ".type");

array f=s->list_fields(table);

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

  string retval="<table width=100%>\n";

  array r=s->query("SELECT orderdata.*, products.name,status.name as status FROM "
	   "products,orderdata,status WHERE orderdata.orderid=" + 
	   id->variables->orderid + " AND status.status=orderdata.status " 
	   " AND products.id=orderdata.id");
  if(sizeof(r)==0)
    return create_panel("Order Manifest", "darkgreen", 
			"Unable to find data for this order.");
  retval+="<tr><td><font face=helvetica size=-1>Select</td>\n<td align=left>"
    "<font face=helvetica size=-1>Qty</font></td>\n"
    "<td align=left><font face=helvetica size=-1>Item</font></td>\n"
    "<td align=left><font face=helvetica size=-1>Description</font></td>\n"
    "<td align=right><font face=helvetica size=-1>Unit Price</font></td>\n"
    "<td align=right><font face=helvetica size=-1>Item Total</font></td>\n";

  foreach(r, mapping row) {
    retval+="<tr><td><input type=checkbox value=ship name=\"" + row->id +
      "." + row->series + "\"></td>"
      "<td>" + row->quantity + (row->status=="Shipped" ?" (S)":"")+"</td><td>" + row->id 
      + "</td><td>" + row->name + "</td><td align=right>" + row->price +
	"</td><td align=right>"
      + sprintf("%.2f", (float)row->price * (float)row->quantity) 
      + "</td></tr>\n";
  }

retval+="<tr><td colspan=5> &nbsp; </td></tr>\n";

r=s->query("select * from lineitems where orderid='"+
id->variables->orderid + "'");

   foreach(r, mapping row) {

  retval+="<tr>\n<td></td><td></td><td></td>\n<td align=right><font "
	"face=helvetica>" +
	capitalize(row->lineitem)
	+"</td>\n<td> &nbsp; </td><td align=right>" 
	+ row->value + "</td></tr>\n";
  
  }

r=s->query("SELECT SUM(value) as grandtotal FROM lineitems WHERE "
	"orderid='"+ id->variables->orderid + "'");

  retval+="<tr><td></td><td></td><td></td><td align=right>"
	"<font face=helvetica><b>Grand Total</b></td><td></td>"
	"<td align=right><b>" + r[0]->grandtotal + "</b></td></tr>\n";

  retval+="</table>\n";
  return create_panel("Order Manifest", "darkgreen", retval);

}


void dodelete(string orderid, object id){

  array tables=({"orders", "orderdata", "lineitems", 
    "customer_info", "payment_info"});

  foreach(tables, string t)
   id->misc->ivend->db->query("DELETE FROM " + t + " WHERE orderid='"
	+ orderid +"'");

  return;

}

void send_notification(object id, string orderid, string type){

if(!type) return;

string note;
note=Stdio.read_file(id->misc->ivend->config->root+"/notes/" + type +".txt");
if(note) {

  string subject,sender, recipient;
  sscanf(note, "%s\n%s\n%s\n%s", sender, recipient, subject, note);
  array r=id->misc->ivend->db->query("SELECT " + recipient + " FROM " 
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

string show_orders(object id, object s){
string retval="";

 if(id->variables->valpay && id->variables->orderid){

   array r=id->misc->ivend->db->query(
       "SELECT status FROM status WHERE name='Validated'");
   id->misc->ivend->db->query("UPDATE payment_info SET status=" + 
       r[0]->status + " WHERE orderid='" + id->variables->orderid+"'");
			    

 } 

 if(id->variables->rejpay && id->variables->orderid){

   array r=id->misc->ivend->db->query(
       "SELECT status FROM status WHERE name='Rejected'");
   id->misc->ivend->db->query("UPDATE payment_info SET status=" + 
       r[0]->status + " WHERE orderid='" + id->variables->orderid+"'");

   send_notification(id, id->variables->orderid, "rejpay");

 } 

 if(id->variables->doship && id->variables->orderid){

   array r=id->misc->ivend->db->query(
      "SELECT status.name,payment_info.orderid from status,payment_info "
      "WHERE payment_info.orderid='" + id->variables->orderid + "' AND "
      "status.status=payment_info.status");

   if(r[0]->name !="Validated") 
     return "Payment information has not been validated.\n" 
       "Cannot Ship order without validation.<p>";

     array r=id->misc->ivend->db->query(
      "SELECT status FROM status WHERE name='Shipped' AND tablename='orders'"
      );


     if(id->variables->doship=="Ship Selected") {

       foreach(indices(id->variables), string v)
	 if(Regexp(".\..")->match(v) && id->variables[v]=="ship") {
       array t=v/".";
       id->misc->ivend->db->query("UPDATE orderdata SET status=" + r[0]->status
         + " WHERE orderid='" + id->variables->orderid + "' AND id='"
	 + t[0] + "' AND series="+ t[1] );
       array o=id->misc->ivend->db->query(
         "SELECT * FROM orderdata WHERE orderid='" + 
	 id->variables->orderid + "' AND id='" + t[0] + "' AND series=" +t[1]);
       foreach(o, mapping l){
	 string query="INSERT INTO shipments VALUES('" + id->variables->orderid
	 +"','" + l->id + "'," + l->series + "," + l->quantity + ",'" +
	 id->variables->tracking_id + "',NOW(),1)";
	 id->misc->ivend->db->query(query);
       }
       
	 }
     }

     else if(id->variables->doship=="Ship All") {

       id->misc->ivend->db->query("UPDATE orderdata SET status=" + r[0]->status
       + " WHERE orderid='" + id->variables->orderid + "'");
       array o=id->misc->ivend->db->query("SELECT * FROM orderdata WHERE orderid='" + 
				id->variables->orderid + "'");
       foreach(o, mapping l){
	 string query="INSERT INTO shipments VALUES('" + id->variables->orderid
	 +"','" + l->id + "'," + l->series + "," + l->quantity + ",'" +
	 id->variables->tracking_id + "',NOW(),1)";
	 id->misc->ivend->db->query(query);
       }
     
       send_notification(id, id->variables->orderid, "ship");

     }
     
       array n= id->misc->ivend->db->query(
	"SELECT id FROM orderdata WHERE orderid='" +
	id->variables->orderid + "' AND status !=" + r[0]->status);
       if(sizeof(n)==0) {
	 id->misc->ivend->db->query(
             "UPDATE payment_info SET Card_Number='',Expiration_Date='' WHERE orderid='" +
	     id->variables->orderid +"'");
	 id->misc->ivend->db->query("UPDATE orders SET status=" + r[0]->status
	   + ", updated=NOW() WHERE id='" + id->variables->orderid + "'");    

       }

     else {
       array r=id->misc->ivend->db->query( 
	"SELECT status FROM status WHERE name='PShipped' "
	"AND tablename='orders'");
       id->misc->ivend->db->query("UPDATE orders SET status=" + 
	 r[0]->status + ",updated=NOW() WHERE id='" +
	id->variables->orderid + "'"); 
     }




 }

if(id->variables->dodelete && id->variables->orderid){
  dodelete(id->variables->orderid, id);
  m_delete(id->variables, "orderid");

  }

if(id->variables->notes){
  s->query("UPDATE orders SET notes=" + id->variables->notes + ","
	"updated=NOW() WHERE "
	"id=" + id->variables->orderid);
  }


if(id->variables->delete){
  s->query("DELETE FROM display_orders WHERE id="+id->variables->orderid);
  retval+="Order Deleted Successfully.\n";

}

else if(id->variables->orderid) {
  /*
    retval+="<a href=./orders?fprint=1&orderid="+ id->variables->orderid+">"
    "Display for Printing</a><p>";

  */

  retval+="<form action=\"./orders\" method=post>\n"
    "<input type=hidden name=orderid value=\"" + 
    id->variables->orderid + "\">\n";

  retval+=show_orderdetails(id->variables->orderid, s, id);

  retval+="<input type=submit name=valpay value=\"Validate Payment\"> &nbsp; \n"
    "<input type=submit name=rejpay value=\"Reject Payment\"><br>\n"
    "Tracking ID: <input type=text size=20 name=\"tracking_id\"> &nbsp; "
    "<input type=submit name=doship value=\"Ship All\"> &nbsp; "
    "<input type=submit name=doship value=\"Ship Selected\">"
    "</form>";
    }

else {
  array r=s->query("SELECT id, status.name as status,"
//	"DATE_FORMAT(updated, 'm/d/y h:m') as 
	"updated "
	"FROM orders,status "
	"WHERE status.status=orders.status ORDER BY status, updated");

  retval+="Click on a name to display an order.\n\n";
  retval+="<table>\n<tr><td><font face=helvetica><b>Order ID</font></td>\n"
    "<td><font face=helvetica><b>Status</font></td>\n"
    "<td><font face=helvetica><b>Record Updated</font></td>\n"
    "<td><font face=helvetica><b>Notes</b></font></td>\n</tr>";

  if(sizeof(r) <1) retval+="No orders.\n";

  for(int i=(sizeof(r)-1); i>=0; i--){
    retval+="<tr>\n";
    retval+="<td><a href=\"./orders?orderid="
	+r[i]->id+"\">"+
	r[i]->id+"</a></td>";
    retval+="<td>"+ r[i]->status+"</td>\n";
    retval+="<td>"+(r[i]->updated)+"</td><td>"
	"</tr>\n";

  }

  retval+="</table>\n";

}

return retval;

}




string|int show_orderdetails(string orderid, object s, object id){

string retval="";

  array r=s->query("SELECT id, status.name as status, "
//	"DATE_FORMAT(updated, 'm/d/y h:m') as "
	"updated, "
//	"DATE_FORMAT(created, 'm/d/y h:m') as "
	"created, "
	"notes "
	"FROM orders,status WHERE id=" 
	+id->variables->orderid +" AND orders.status=status.status");
  if(sizeof(r)!=1) retval="Error finding the requested record.\n";

  else {

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

