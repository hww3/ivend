#!NOMODULE

#include <ivend.h>

inherit "roxenlib";

constant module_name = "Currency Conversion";
constant module_type = "addin";    

void initialize_db(object db) {

  perror("initializing currency conversion module!\n");
catch(db->query("drop table currencies"));
db->query(
"CREATE TABLE currencies ("
"  currency char(16) DEFAULT '' NOT NULL PRIMARY KEY,"
"  symbol char(16) DEFAULT '' NOT NULL,"
"  description char(64) DEFAULT '',"
"  from_currency char(16) DEFAULT '' NOT NULL,"
"  rate decimal(10,2) not null"
") ");

return;

}   

/*
void event_admindelete(string event, object id, mapping args){

  if(args->type=="product")
	DB->query("DELETE FROM upsell WHERE id='" + args->id + "'");
  return;
}
*/

mixed currency_handler(string mode, object id){

ADMIN_FLAGS=NO_BORDER;

// return sprintf("<pre>%O</pre>",
// mkmapping(indices(id->misc->ivend),
// values(id->misc->ivend))); 

if(id->variables->initialize) {
	initialize_db(DB);
   return "Currency module initialized. To use this feature, please "
    " close this window and start again.";
  }
if(sizeof(DB->list_tables"currencies"))!=1)
  return "You have not configured the currencies handler."
	"<p><a href=./?initialize=1>Click here</a>"
	" to do this now.";

if(id->variables->action=="AddCurrency")
  DB->query("INSERT INTO currencies VALUES('" + id->variables->currency +
"','" + DB->quote(id->variables->symbol) + "','" +
DB->quote(id->variables->description) + "','"
+ id->variables->from_currency + "'," + id->variables->rate + ")");
else if(id->variables->action=="DeleteCurrency") {

      DB->query("DELETE FROM currencies WHERE currency='" +
	id->variables->currency + "'"); 

}

string retval="<title>Currencies</title>\n"
	"<body bgcolor=white text=navy>"
	"<font face=helvetica, arial>";
  retval+="<table>\n"

"<tr><th>Currency</th><th>Symbol</th><th>Description</th><th>Exchange "
"Rate</th><th></th></tr>\n";
  retval+="<tr><td>\n";
  retval+="<form action=./>\n"
	"<input size=3 name=currency>";	
  retval+="<td><input size=5 name=symbol>\n"
	"</td><td><input size=32 name=description>\n</td><td>"
	"1 unit equals <input name=rate size=10> <input name=from_currency "
	"size=3>.</td>";
  retval+="<td><input type=submit value=AddCurrency name=action></form></td></tr>\n";
  
  array a=DB->query("SELECT * FROM currencies ORDER BY currency");
  if(sizeof(a)==0) retval+="<tr><td colspan=5>No Currencies "
	" Defined.</td></tr>";
  else foreach(a, mapping row) retval+="<tr><td>" + row->currency +
	"</td><td>" + row->symbol + "</td><td>" + row->description + 
	"</td><td> 1 " +
	row->from_currency + " equals " + row->rate + " " +
	row->currency + ".</td><td>"
	"<form action="."><input type=hidden name=currency value=\"" +
	row->currency + "\"><input "
	"type=submit name=action value=DeleteCurrency></form></td></tr>";
  retval+="</form>\n";
  retval+="<p>"
	"<b>Currency</b> is a 3 character code designating the currency."
	"<i>examples: AUD, GBP</i><br>"
	"<b>Symbol</b> is the symbol used to signify this currency."
	"<i>examples: AU$, &#163;</i><br>"
	"<b>Description</b> is a short description for the currency."
	"<i>example: Australian Dollar, British Pound</i><br>"
	"<b>Exchange Rate</b> is a numerical exchange rate and a 3 "
	"character currency code that is being exchanged from."
	"<i>example: 1 USD is equal to 0.70 GBP";
return retval;

}


mixed container_currency(string name, mapping args,
                      string contents, object id)
{
  string retval="";
  if(contents=="") return "No input, currency conversion unavailable.";
  if(id->misc->ivend->currency) args->to=id->misc->ivend->currency;
  if(!args->to || args->to=="") return "No destination currency available.";
  string from=config[module_name]["default_currency"];
  if(from=="") return "No originating currency available.";
  float exchange_rate=0.00;
  retval+="<!-- converting " + args + " " + from + " to " + args->to + ". -->";
  if(exchange_rate==0.0) return "No exchange information available for " +
    args->to + ".";
  float from_amt, to_amt;
  
  int matches=sscanf(contents, "%f", from_amt);
  if(matches!=1) return "Unable to get original amount to convert.";

  array a=DB->query("SELECT * FROM currencies WHERE from_currency='" +
	from + "' AND currency='" + args->to + "'");
  if(sizeof(a)!=1) return "Unable to find a conversion for this currency.";
  to_amt=((from_amt*(float)(a[0]->rate_));
  retval+=sprintf("%s %.2f", to_symbol, to_amt);
  return retval;

}

mixed query_container_callers(){

  return ([ "currency": container_currency ]);

}

mixed query_event_callers(){

  return ([ "admindelete": event_admindelete ]);

}

mixed register_admin(){

  return ({
	([ "mode": "menu.main.Store_Administration.Currencies",
		"handler": currency_handler,
		"security_level": 0 ])
	});
}


mixed query_preferences(object id){

array fields;
  if(!catch(DB) && sizeof(fields)<=0) {

     array f2=DB->query("select from_currency from currencies order by currency");
     foreach(f2, mapping m)
        fields +=({m->currency});
    } 
return ({

        ({"default_currency", "Default Currency",
        "The currency unit all prices are expressed in by default.",
        VARIABLE_MULTIPLE,
        "USD",
        fields
        })  

)};

}

