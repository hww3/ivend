/*
 * default.pike: checkout module for iVend.
 *
 * Bill Welliver <hww3@riverweb.com>
 *
 */

inherit "roxenlib";

constant module_name="Default Checkout Module";
constant module_type="checkout";


mapping query_tag_callers2();
mapping query_container_callers2();

/*

  currency_convert

  v is price

*/

mixed currency_convert(mixed v, object id){
  float exchange=3.0;
  float customs=2.0;
  float our_fee=3.0;

  // calculate the exchange rate...
  v=( exchange * (float)v);
  v+=( (customs*(float)v) + (our_fee*(float)v) );
  return v;
}

/*

  calculate tax

*/

string tag_salestax(string tag_name, mapping args,
		     object id, mapping defines) {

array r;		// result from query
string query;		// the query
float totaltax;		// totaltax
string locality;	// fieldname of locality

locality=(args->locality||"state");

  object s=Sql.sql(
    id->misc->ivend->config->dbhost,
    id->misc->ivend->config->db,
    id->misc->ivend->config->dblogin,
    id->misc->ivend->config->dbpassword
    );

query=
"select " + locality + " from customer_info where orderid='"+
	id->misc->ivend->SESSIONID +"'";
r=s->query(query);

if(!r) perror("iVend: ERROR locating customerinfo!\n");

else { 

  query=
  "select sessions.sessionid, SUM(products.price*sessions.quantity) "
  "as grandtotaltaxable, taxrates.taxrate as taxrate, "
  "SUM(products.price*sessions.quantity)*taxrates.taxrate as "
  "salestax from sessions, products, taxrates where "
  "(sessions.id=products.id and taxrates.locality='"+ r[0][locality]
  +"' and SESSIONID='"+ id->misc->ivend->SESSIONID +"')";
perror(query+"\n");
  r=s->query(query);
  if(sizeof(r)==1 && r[0]->salestax) {
 if(!id->misc->ivend->lineitems) 
   id->misc->ivend+= (["lineitems":([])]);


    id->misc->ivend->lineitems+=(["salestax":(float)r[0]->salestax]);
    if(args->convert && functionp(currency_convert))
      return sprintf("%.2f",currency_convert((float)r[0]->salestax,id));
    else
      return sprintf("%.2f",(float)r[0]->salestax);

  }
  else {
 if(!id->misc->ivend->lineitems) id->misc->ivend+=(["lineitems":([])]);
    id->misc->ivend->lineitems+=(["salestax":0.00]);
    return ("0.00");
  }
}
 if(!id->misc->ivend->lineitems) id->misc->ivend+=(["lineitems":([])]);
id->misc->ivend->lineitems+=(["salestax":0.00]);
return ("0.00");

}

string tag_generateform(string tag_name, mapping args,
		     object id, mapping defines) {
 object s=iVend.db(
    id->misc->ivend->config->dbhost,
    id->misc->ivend->config->db,
    id->misc->ivend->config->dblogin,
    id->misc->ivend->config->dbpassword
    );

string retval="";
if(!args->table) return "";

 retval+=s->generate_form_from_db(args->table,
    ((
 
      (( (args->exclude||" ")-" ")/",")
       ||({}))
        + 
     ( (
      ((args->hide||" ")-" ") /",")
      ||({})) 
     ),id)+
        "<input type=hidden name=table value=\""+args->table+"\">";
retval+="<input type=hidden name=aeexclude value=\""+((args->exclude||" ")-" ")
  + "\">\n";
return retval;
}

string tag_addentry(string tag_name, mapping args,
		     object id, mapping defines) {

if(id->misc->ivend->error) return "";
if((int)id->variables->shipsame==1) return "";

 object s=iVend.db(
    id->misc->ivend->config->dbhost,
    id->misc->ivend->config->db,
    id->misc->ivend->config->dblogin,
    id->misc->ivend->config->dbpassword
    );

mixed j;

 if(id->variables->aeexclude){
   array aeexclude=id->variables->aeexclude /",";
   string exclude;
   foreach(aeexclude, exclude) {
     id->variables[exclude]="N/A";
     perror(exclude + ": N/A\n");
   }
   m_delete(id->variables, "aeexclude");
 }

 if(args->encrypt){
object encryptedid = id;

  perror("reading "+id->misc->ivend->config->keybase+".pub");
  string key=Stdio.read_file(id->misc->ivend->config->keybase+".pub");

array e=(args->encrypt-" ")/",";
 for(int i=0; i<sizeof(e); i++){


  encryptedid->variables[e[i]]=
    Commerce.Security.encrypt(id->variables[e[i]],key);
 }

 j=s->addentry(encryptedid);

 }

else
  j=s->addentry(id);
    
if(j!=1) id->misc->ivend->error+= "<font size=+2>Error!</font>\n"
	   "<br><b>Please correct the following before continuing:<p></b><ul>"
	+j+"</ul>";

return "";


}

string tag_cardcheck(string tag_name, mapping args,
		     object id, mapping defines) {

if(Commerce.CreditCard.cc_verify(
    id->variables[args->cardnumber] ||
    id->variables->Card_Number,
    id->variables[args->cartype] ||
    id->variables->Payment_Method)
    || !Commerce.CreditCard.expdate_verify(id->variables[args->expdate]
	      || id->variables->Expiration_Date))

id->misc->ivend->error+=
  "You have supplied improper credit card information!<p>"
  "Please go back and correct this before continuing.";

return "";
}

mixed checkout(object id){

string retval=
  Stdio.read_file(id->misc->ivend->config->root +
    "/checkout/checkout_"+ (id->variables["_page"] || "1") +
    ".html");

if(!retval) return "error loading " + id->misc->ivend->config->root +
  "/checkout/checkout_"+ (id->variables["_page"] || "1") + 
  ".html" ;    

retval=parse_rxml(retval,id);

return retval;

}


string tag_subtotal(string tag_name, mapping args,
		     object id, mapping defines) {

   if(args->convert && functionp(currency_convert) ) {
     perror("converting currency...\n");
  return(sprintf("%.2f",
    (float)currency_convert(id->misc->ivend->lineitems->subtotal,id))) ;
   }
else return sprintf("%.2f",
    (float)id->misc->ivend->lineitems->subtotal);



}

string tag_grandtotal(string tag_name, mapping args,
		     object id, mapping defines) {

float grandtotal=0.00;
string item;
 foreach(indices(id->misc->ivend->lineitems), item)
   grandtotal+=id->misc->ivend->lineitems[item];


   if(args->convert && functionp(currency_convert) ) {
     perror("converting currency...\n");
  return(sprintf("%.2f",(float)currency_convert(grandtotal,id))) ;
   }
else return sprintf("%.2f",(float)grandtotal);

}

string tag_showorder(string tag_name, mapping args,
		     object id, mapping defines) {
float subtotal=0.00;
string retval="";

 object s=Sql.sql(
    id->misc->ivend->config->dbhost,
    id->misc->ivend->config->db,
    id->misc->ivend->config->dblogin,
    id->misc->ivend->config->dbpassword
    );

string query="SELECT sessions.quantity, "
  "products.name, products.price, "
  "sessions.quantity*products.price AS linetotal FROM "
  "sessions,products WHERE products.id=sessions.id AND "
  "sessions.sessionid='" + id->misc->ivend->SESSIONID + "'";

perror("QUERY:\n\n"+query+"\n\n");

array r=s->query(query);
perror("sizeof result: "+sizeof(r)+"\n");
 for(int i=0; i < sizeof(r); i++) {
   retval+="<tr><td align=right>" + r[i]->quantity + "</td>\n"
     "<td>"+ r[i]->name + "</td>\n"
     "<td align=right>";

   if(args->convert && functionp(currency_convert) ) {
     perror("converting currency...\n");
  retval+=sprintf("%.2f",(float)currency_convert(r[i]->price,id)) ;
   }
else retval+=r[i]->price;
   retval+= "</td>\n"
     "<td align=right>";
   if(args->convert && functionp(currency_convert) ) {
     perror("converting currency...\n");
  retval+=sprintf("%.2f",(float)currency_convert(r[i]->linetotal,id)) ;
   }
else retval+=r[i]->linetotal;
subtotal+=(float)r[i]->linetotal;
retval+= "</td></tr>\n"; 
 }


 if(!id->misc->ivend->lineitems) id->misc->ivend+=(["lineitems":([])]);
id->misc->ivend->lineitems+=(["subtotal":(float)subtotal]);


return retval;

}


string|void container_checkout(string name, mapping args,
                      string contents, object id)
{

if(functionp(query_tag_callers2))
 mapping tags=query_tag_callers2();
if(functionp(query_container_callers2))
  mapping containers=query_container_callers2();
string h;

if(id->variables["_page"])
    id->misc->ivend->next_page= (int)id->variables["_page"]+1;

contents="<form action=\"" + id->not_query + "\">\n<input type=hidden name=_page "
  "value=" + (id->misc->ivend->next_page || "2") + ">\n"
  +contents+ "</form>\n";

contents=parse_html(contents,
		  tags,
		  containers,
		  id);

 if(id->misc->ivend->error) return  (id->misc->ivend->error[1..]);
else return contents;
}




mapping query_tag_callers2() {

return (["showorder" : tag_showorder,
	"grandtotal" : tag_grandtotal,
  	  "subtotal" : tag_subtotal,
	  "salestax" : tag_salestax, 
	 "cardcheck" : tag_cardcheck,
	  "addentry" : tag_addentry,
	"generateform": tag_generateform
	]);

}

mapping query_container_callers2(){

  return ([]);

}

mapping query_tag_callers(){

  return ([]);

}

mapping query_container_callers() {

return ([ "checkout" : container_checkout]);

}















