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
	 "payment_info,status WHERE orderid=" + id->variables->orderid);

array f=s->list_fields("payment_info");

if(sizeof(r)==0) return create_panel("Payment Information", "maroon", 
	      "Unable to find Payment Info for Order ID " + 
		   id->variables->orderid);

string key=Stdio.read_file(id->misc->ivend->config->keybase+".priv");

retval="<table width=100%>";
 foreach(f, mapping field){
     if(field->name=="updated" || field->name=="type" || field->name=="orderid") continue;
   retval+="<tr><td width=30%><font face=helvetica>"+ replace(field->name,"_"," ")
     +"</font>\n</td>\n<td>";

   if(field->name=="Card_Number") retval+=Commerce.Security.decrypt(r[0][field->name], key)+"\n</td></tr>\n";
     else retval+=r[0][field->name]+"\n</td></tr>\n";
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

  array r=s->query("SELECT orderdata.*, products.name FROM "
	   "products,orderdata WHERE orderdata.orderid=" + 
	   id->variables->orderid + " AND products.id=orderdata.id");
  if(sizeof(r)==0)
    return create_panel("Order Manifest", "darkgreen", 
			"Unable to find data for this order.");
  retval+="<tr><td align=left><font face=helvetica size=-1>Qty</font></td>\n"
    "<td align=left><font face=helvetica size=-1>Item</font></td>\n"
    "<td align=left><font face=helvetica size=-1>Description</font></td>\n"
    "<td align=right><font face=helvetica size=-1>Unit Price</font></td>\n"
    "<td align=right><font face=helvetica size=-1>Item Total</font></td>\n";

  foreach(r, mapping row) {
    retval+="<tr><td>" + row->quantity + "</td><td>" + row->id 
      + "</td><td>" + row->name + "</td><td align=right>" + row->price +
	"</td><td align=right>"
      + sprintf("%.2f", (float)row->price * (float)row->quantity) 
      + "</td></tr>\n";
  }

retval+="<tr><td colspan=5> &nbsp; </td></tr>\n";

r=s->query("select * from lineitems where orderid='"+
id->variables->orderid + "'");

   foreach(r, mapping row) {

  retval+="<tr>\n<td></td><td></td>\n<td align=right><font "
	"face=helvetica>" +
	capitalize(row->lineitem)
	+"</td>\n<td> &nbsp; </td><td align=right>" 
	+ row->value + "</td></tr>\n";
  
  }

r=s->query("SELECT SUM(value) as grandtotal FROM lineitems WHERE "
	"orderid='"+ id->variables->orderid + "'");

  retval+="<tr><td></td><td></td><td align=right>"
	"<font face=helvetica><b>Grand Total</b></td><td></td>"
	"<td align=right><b>" + r[0]->grandtotal + "</b></td></tr>\n";

  retval+="</table>\n";
  return create_panel("Order Manifest", "darkgreen", retval);

}


string show_orders(object id, object s){
string retval="";

if(id->variables->status){
  s->query("UPDATE orders SET status=" + id->variables->status + ","
	"updated=NULL WHERE "
	"id=" + id->variables->orderid);
  }

if(id->variables->notes){
  s->query("UPDATE orders SET notes=" + id->variables->notes + ","
	"updated=NULL WHERE "
	"id=" + id->variables->orderid);
  }


if(id->variables->delete){
  s->query("DELETE FROM display_orders WHERE id="+id->variables->orderid);
  retval+="Order Deleted Successfully.\n";

}

else if(id->variables->orderid) {
retval+="<a href=./orders?fprint=1&orderid="+ id->variables->orderid+">"
	"Display for Printing</a><p>";
retval+=show_orderdetails(id->variables->orderid, s, id);

retval+="<form action=./orders>\n"
	"Change this order's status to: "
	"<input type=hidden name=orderid value="+
	id->variables->orderid+">\n"
	"<select name=status>";

array status=s->query("SELECT status, name from status where tablename='orders'");
foreach(status, mapping v)
  retval+="<option value="+ v->status + ">"+v->name+"\n";

retval+="</select><input type=submit value=Change></form>\n";


  }

else {
  array r=s->query("SELECT id, status.name as status,"
	"DATE_FORMAT(updated, 'm/d/y h:m') as updated "
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
	"DATE_FORMAT(updated, 'm/d/y h:m') as updated, "
	"DATE_FORMAT(created, 'm/d/y h:m') as created, "
	"notes "
	"FROM orders,status WHERE id=" 
	+id->variables->orderid +" AND orders.status=status.status");
  if(sizeof(r)!=1) retval="Error finding the requested record.\n";

  else {

	string key=Stdio.read_file(id->misc->ivend->config->root+"/"+
	  id->misc->ivend->config->keybase+".priv");	
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









