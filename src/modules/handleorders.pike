constant module_name = "Stock Order Handler";
constant module_type = "order";

mixed show_orders(object id){

// string username=id->auth[1];



string retval="<font size=+1>\nSHOPPER DISPLAY AD ORDERS</font></b>\n\n";
object s=Sql.sql(0,"shopper","shopper","orioles");
if(id->variables->delete){
  s->query("DELETE FROM display_orders WHERE id="+id->variables->id);
  retval+="Order Deleted Successfully.\n"
	"<a href=checkads.pike>Click here to return.</a>";
}

else if(id->variables->id) {
  array r=s->query("SELECT * FROM display_orders WHERE id="+id->variables->id);
  if(sizeof(r)!=1) retval="Error finding the requested record.\n"
	"<a href=checkads.pike>Click here to return.</a>";	
  else {

	string key=Stdio.read_file(id->misc->ivend->config->root+"/"+
	  id->misc->ivend->config->keybase+".priv");	
	 retval="ORDER DETAILS:\n\n"
	"Date: "+r[0]->added+"\n"
	"From:\n\n"
	"      "+r[0]->name+"\n"
	"      "+r[0]->address+"\n"
	"      "+r[0]->address2+"\n\n"
	"      "+r[0]->phone+"\n"
	"      <a href=mailto:"+r[0]->email+">"+r[0]->email+"</a>\n"+  
	"\n\n"
	"Payment:\n\n"
	"      "+r[0]->method+"\n"
	"      "+Commerce.Security.decrypt(r[0]->account, key)+"\n"
	"      "+(r[0]->expiration ||"")+"\n\n"
	"Display Ad Text:\n\n"
	+r[0]->display_text+
	"\n\n\n"
	"<a href=checkads.pike>Click here to return.</a>";	
    s->query("UPDATE display_orders SET status=1 WHERE id="+
	id->variables->id);
    }
  }

else {
  array r=s->query("SELECT * FROM display_orders ORDER BY added");

  retval+="Click on a name to display an order.\n\n";
  retval+="     <b>Name\t\tOrder Placed\n</b>";

  if(sizeof(r) <1) retval+="No orders.\n";

  for(int i=(sizeof(r)-1); i>=0; i--){

    if(r[i]->status=="0") retval+="<font color=red> NEW  </font>";

    else retval+="      ";
    retval+="<a href=\"checkads.pike?id="
	+r[i]->id+"\">"+r[i]->name+"</a>\t"+(r[i]->added)+"\t"
	"<a href=\"checkads.pike?id="+r[i]->id+"&delete=1\">Delete</a>\n";

  }

}

return "<font face=courier><pre>"+retval+"</pre>";

}
