constant module_name = "Stock Order Handler";
constant module_type = "order";

string|int genpayment(object id, object s){
string retval="";

array r=s->query("SELECT payment_info.*, status.name as status from "
	 "payment_info,status WHERE orderid=" + id->variables->orderid);

array f=s->list_fields("payment_info");

if(sizeof(r)==0) return "Unable to find Payment Info for Order ID " + 
		   id->variables->orderid;

retval+="<table width=80%><tr><td colspan=2 bgcolor=maroon>\n"
  " &nbsp; <font color=white face=helvetica>Payment Information</font></td></tr>\n";

string key=Stdio.read_file(id->misc->ivend->config->keybase+".priv");

 foreach(f, mapping field){
     if(field->name=="updated" || field->name=="type" || field->name=="orderid") continue;
   retval+="<tr><td width=30%><font face=helvetica>"+ replace(field->name,"_"," ")
     +"</font>\n</td>\n<td>";

   if(field->name=="Card_Number") retval+=Commerce.Security.decrypt(r[0][field->name], key)+"\n</td></tr>\n";
     else retval+=r[0][field->name]+"\n</td></tr>\n";
   }


retval+="</table>\n";


return retval;

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

   retval+="<table width=80%><tr><td colspan=2 bgcolor=navy>\n";
   retval+=" &nbsp; <font face=helvetica color=white><b>"+ row->type+"</font></b> &nbsp; </td></tr>\n";
   m_delete(row, "type");
   foreach(f, mapping field){
     if(field->name=="updated" || field->name=="type" || field->name=="orderid" || row[field->name]==ignore) continue;
     retval+="<tr><td width=30%><font face=helvetica>"+replace(field->name, "_"," ")+"</td><td>\n";
 
     retval+=row[field->name]+"</td></tr>\n";
   }
   retval+="</table></td>\n";
 }


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
  retval+="Order Deleted Successfully.\n";

}

else if(id->variables->orderid) {

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
	 retval="<table width=80%><tr><td colspan=2 bgcolor=hunter>\n"
	   "<font face=helvetica color=white> &nbsp; Order Details"
	"</td></tr>\n<tr><td><font face=helvetica>"
	"Order ID</td><td>"+r[0]->id+"</td></tr>\n"
	"<tr><td width=30%><font face=helvetica>Status</td><td>"+r[0]->status+"</td></tr>\n"
	"<tr><td width=30%><font face=helvetica>Last Action</td><td>"+r[0]->updated+"</td></tr>\n"
	"<tr><td width=30%><font face=helvetica>Creation</td><td>"+r[0]->created+"</td></tr>\n"
	"<tr><td width=30%><font face=helvetica>Notes:</td><td><pre>"+
	(r[0]->notes||"")+"</pre></td></tr>\n"
	"</table>"
	"\n\n";

	 // get address information...

retval+=gentable(id, s, "customer_info", "N/A", 1);
	
retval+="<p>\n" + genpayment(id,s);
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

array status=s->query("SELECT status, name from status where tablename='orders'");
foreach(status, mapping v)
  retval+="<option value="+ v->status + ">"+v->name+"\n";

retval+="</select><input type=submit value=Change></form>\n";


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














