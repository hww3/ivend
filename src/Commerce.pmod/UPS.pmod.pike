class zone{

private mapping(string:mixed) zonedata=([]);
private mapping(string:mixed) ratedata=([]);

int load_zonefile(string zonefile){

if (zonefile=="") return 0;
int loc=search(zonefile,"\"ZONES\"\n");
zonefile=zonefile[(loc+8)..];
array z=zonefile/"\n";
array t=z[0]/",";
for(int i=2; i<sizeof(z);i++){

  array a=z[i]/",";
  mapping line=([]);
  for(int j=1;j<sizeof(a);j++){
    line[t[j]]=a[j];  
    }
  zonedata[a[0]]=([]);
  zonedata[a[0]]=line;
}
// write(sprintf("%O",zonedata));
t=t-({"Dest. ZIP"});
return 1;
}

int load_ratefile(string ratefile){
if (ratefile=="") return 0;
string type=ratefile[4..(search(ratefile,",")-1)];
int loc=search(ratefile,"\nWeight");
ratefile=ratefile[(loc+1)..];
array z=ratefile/"\n";
array t=z[0]/",";
ratedata[type]=([]);
for(int i=1; i<sizeof(t); i++){
  ratedata[type][t[i]-"Zone "]=([]);
}

for(int i=1; i<sizeof(z); i++){

  array a=z[i]/",";

  for(int j=1;j<sizeof(a);j++){
    ratedata[type][t[j]-"Zone "][a[0]-" "]=a[j];
    }

}

return 1;

}

int load_all_zones(string dir){
if( dir=="") return 0;
else array d=get_dir(dir);
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
return 1;
}

string findzip(string zipcode){
zipcode=zipcode[0..2];
array z=indices(zonedata);
z=sort(z);
for(int i=0; i<sizeof(z); i++){

  if((int)zipcode<(int)z[i][0..2])
  return z[i-1];
  }
}

float|mapping(string:float) findrate(string zipcode, 
    string weight, string|void type){ 

if (zipcode=="") return 0.00;
else if (weight=="letter") weight="Letter";
string zip=findzip(zipcode);
string zone=zonedata[zip][type];
if(!type){
   mapping(string:float) retval=([]);
   array t=indices(ratedata);
   for(int i=0; i<sizeof(t); i++){
      string zone=zonedata[zip][t[i]];
      retval+=([t[i]:(float)(ratedata[t[i]][zone][weight][1..])]);
      }
   return retval;
   }
if(catch(string cost=ratedata[type][zone][weight])) return 0.00;
return ((float)(cost[1..]));

}

void create(string|void zonefile){

if(zonefile) load_zonefile(zonefile);
else return;

}


}
