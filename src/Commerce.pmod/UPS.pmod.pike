class zone{

private mapping(string:mixed) zonedata=([]);
private mapping(string:mixed) ratedata=([]);

int load_zonefile(string zonefile){
perror("Commerce.UPS.zone->load_zonefile()\n");
if (zonefile=="") return 0;
int loc=search(zonefile,"Dest. ZIP,");
string zn=zonefile[loc..];
// perror("zonefile: "  + zn + "\n");
array z=((replace(zn,({"\r\n"}),({"\n"})))/"\n");
// perror(sizeof(z) + "\n");
//  werror(z[0]+"\n");
array t=z[0]/","; // shipping types
 perror(sizeof(t) + "\n");
for(int i=2; i<sizeof(z);i++){
  array a=z[i]/",";
  mapping line=([]);
// perror(sizeof(a)+"\n");
  if(sizeof(a)!=sizeof(t)) {
    werror("mismatched line!\n");
    continue;
    }
  if(a[0]=="")
    continue;
  for(int j=1;j<sizeof(a);j++){
    line[
	t[j]]=
	a[j];  
    }
  zonedata[a[0]]=([]);
  zonedata[a[0]]=line;
}
t=t-({"Dest. ZIP"});
return 1;
}

int load_ratefile(string ratefile){
perror("Commerce.UPS.zone->load_ratefile()\n");
ratefile=replace(ratefile, "\r", "\n");
if (ratefile=="") return 0;
string type=ratefile[4..(search(ratefile,",")-1)];
int loc=search(ratefile,"Weight");
ratefile=ratefile[(loc+1)..];
array z=((replace(ratefile,({"\r\n"}),({"\n"})))/"\n");
// werror(sizeof(z)+"\n");
array t=z[0]/",";
// werror(z[0]);
ratedata[type]=([]);
for(int i=1; i<sizeof(t); i++){
  t[i]=t[i]-" ";
  ratedata[type][t[i]-"Zone"]=([]);
}

for(int i=1; i<sizeof(z); i++){

  array a=z[i]/",";

  for(int j=1;j<sizeof(a);j++){
    a[j]=a[j]-"$";
    ratedata[type][t[j]-"Zone"][a[0]-" "]=(a[j]-" ");
    }

}
//  write(sprintf("%O",ratedata));

return 1;

}

int load_all_zones(string dir){
if( dir=="") return 0;
else {
  array d=get_dir(dir);
  d=d-({"CVS",".",".."});
  for(int i=0; i<sizeof(d); i++){
    if(d[i]=="zones.csv") {
      string data=Stdio.read_file(dir+"/"+d[i]);
      if(!load_zonefile(data)) return 0;
      }
    else {
      string data=Stdio.read_file(dir+"/"+d[i]);
      if(!load_ratefile(data)) return 0;
      }
    }
  }
return 1;
}

string findzip(string zipcode){
// perror(sprintf("%O", zonedata) +"\n");
zipcode=zipcode[0..2];
array z=indices(zonedata);
z=sort(z);
for(int i=0; i<sizeof(z); i++){

  if((int)zipcode<(int)z[i][0..2]){
    return z[i-1];
    }
  }
}

int|array showtypes(){

return indices(ratedata) || 0;

}

float|mapping(string:float) findrate(string zipcode, 
    string weight, string|void type){ 
string zone="";
if (zipcode=="") return -1.00;
else if (weight=="letter") weight="Letter";
string zip=findzip(zipcode);
perror("ZIP: " + zipcode + " " + zip + "\n");
if(type){
  zone=zonedata[zip][type];
  werror(zone+"\n");
  }
else if(sizeof(indices(ratedata))==1){
perror("Only one ratetype loaded...\n");
type=indices(ratedata)[0];
zone=zonedata[zip][type];
}
else {
   mapping(string:float) retval=([]);
   array t=indices(ratedata);
   foreach(t, string typename){
      zone=zonedata[zip][typename];
      werror(zone+"\n");
      retval+=([typename:(float)(ratedata[typename][zone][weight])]);
      }
   perror(sprintf("%O", retval));
   return retval;
   }
string cost;
weight=sprintf("%d", (int)weight);
perror("type: " + type + " zone: " + zone + " weight: " + weight + "\n");
cost=ratedata[type][zone][weight];
perror(cost+"\n");
return ((float)(cost));

}

void create(string|void zonefile){

perror("Commerce.UPS.zone()\n");

if(zonefile) load_zonefile(zonefile);
else return;

}


}
