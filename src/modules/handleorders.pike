constant module_name = "Stock Order Handler";
constant module_type = "order";

string|int gentable(object id, object s, string table, string ignore, void|int worrytype){
string retval="";
array r=s->query("SELECT "+table+".*, type.name as type FROM "+table+",type "
		 "WHERE orderid="+ id->variables->orderid +
		 " AND type.type=" + table + ".type");

array f=s->list_fields(table);

if(sizeof(r)==0) return "Unable to find "+table+" for Order ID " + 
		   id->variables->orderid;

retval+="<table><tr>\n";

 foreach(r, mapping row){

   retval+="<td valign=top><table><tr><td bgcolor=gold>\n";
   retval+=" &nbsp; <font size=+1><b>"+ row->type+"</font></b> &nbsp; </td></tr>\n<tr><td>";
   m_delete(row, "type");
   foreach(f, mapping field){
     if(row[field->name]==ignore) retval+="";
     else if(field->name=="updated" || field->name=="type" || field->name=="orderid") retval+="";
     else retval+=row[field->name]+"<br>\n";
   }
   retval+="</td></tr></table></td>\n";
 }

retval+="</tr></table>\n";

return retval;

}


string show_orders(object id, object s){
string retval="";

if(id->variables->status){
  s->query("UPDATE orders SET status=" + id->variables->status + ","
	"updated=NOW() WHERE "
	"id=" + id->variables->orderid);
  }

if(id->variables->notes){
  s->query("UPDATE orders SET notes=" + id->variables->notes + ","
	"updated=NOW() WHERE "
	"id=" + id->variables->orderid);
  }


if(id->variables->delete){
  s->query("DELETE FROM display_orders WHERE id="+id->variables->orderid);
  retval+="Order Deleted Successfully.\n"
	"<a href=./orders>Click here to return.</a>";
}

else if(id->variables->orderid) {

  array r=s->query("SELECT id, status.name as status, "
	"DATE_FORMAT(updated, 'm/d/y h:m') as updated, "
	"DATE_FORMAT(created, 'm/d/y h:m') as created, "
	"notes "
	"FROM orders,status WHERE id=" 
	+id->variables->orderid +" AND orders.status=status.status");
  if(sizeof(r)!=1) retval="Error finding the requested record.\n"
	"<a href=./orders>Click here to return.</a>";	
  else {

	string key=Stdio.read_file(id->misc->ivend->config->root+"/"+
	  id->misc->ivend->config->keybase+".priv");	
	 retval="<b>ORDER DETAILS:</b><p>\n"
	"<table>\n"
	"<tr><td>"
	"Order ID: &nbsp; </td><td>"+r[0]->id+"</td></tr>\n"
	"<tr><td>Status: &nbsp; </td><td>"+r[0]->status+"</td></tr>\n"
	"<tr><td>Last Action: &nbsp; </td><td>"+r[0]->updated+"</td></tr>\n"
	"<tr><td>Creation: &nbsp; </td><td>"+r[0]->created+"</td></tr>\n"
	"<tr><td>Notes: &nbsp; </td><td><pre>"+
	(r[0]->notes||"")+"</pre></td></tr>\n"
	"</table>"
	"\n\n";

	 // get address information...

retval+=gentable(id, s, "customer_info", "N/A", 1);
	

/*
retval+="Payment:\n\n"
	"      "+r[0]->method+"\n"
	"      "+Commerce.Security.decrypt(r[0]->account, key)+"\n"
	"      "+(r[0]->expiration ||"")+"\n\n";
*/	
retval+="<form action=./orders>\n"
	"Change this order's status to: "
	"<input type=hidden name=orderid value="+
	r[0]->id+">\n"
	"<select name=status>";

array status=s->query("SELECT status, name from status");
foreach(status, mapping v)
  retval+="<option value="+ v->status + ">"+v->name+"\n";

retval+="</select><input type=submit value=Change></form>\n";

retval+="<p><a href=./orders>Click here to return.</a>";	
    }
  }

else {
  array r=s->query("SELECT id, status.name as status,"
	"DATE_FORMAT(updated, 'm/d/y h:m') as updated "
	"FROM orders,status "
	"WHERE status.status=orders.status ORDER BY status, updated");

  retval+="Click on a name to display an order.\n\n";
  retval+="<table>\n<tr><td><b>Order ID</td><td><b>Status</td>"
	"\n<td><b>Record Updated</td></tr>";

  if(sizeof(r) <1) retval+="No orders.\n";

  for(int i=(sizeof(r)-1); i>=0; i--){
    retval+="<tr>\n";
    retval+="<td><a href=\"./orders?orderid="
	+r[i]->id+"\">"+
	r[i]->id+"</a></td>";
    retval+="<td>"+ r[i]->status+"</td>\n";
    retval+="<td>"+(r[i]->updated)+"</td><td>"
	"<a href=\"./orders?orderid="+r[i]->id+"&delete=1\">Delete</a>"
	"</td></tr>\n";

  }

  retval+="</table>\n";

}

return retval;

}














