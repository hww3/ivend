#!/usr/bin/pike

// load tab delimited datafile into sql statements
// version 1.0 of august 24 1998
// hww3@riverweb.com

int main(int argc, string * argv){

if(argc!=3) {

  werror("usage: " + argv[0] + " products|groups filename.txt\n");
  exit (1);
  }

if((argv[1]-" ")!="products" && (argv[1]-" ")!="groups") {

  werror("invalid table name " + argv[1] + "\n");
  exit (1);
  }
  
array file=Stdio.read_file(argv[2])/"\n";
file=file-({""});
if(!file) {
  werror("unable to load data from " + argv[2] + "\n");  
  exit (1);
}


array fields=file[0]/"\t";

file=file[1..];

foreach(file, string line){
  string query="INSERT INTO " + argv[1] +" (";
  string query2=" VALUES(";
  array record=line/"\t";
  for(int i=0; i<sizeof(fields); i++)
     if(!catch(record[i]) && fields[i] !="shipping" && sizeof(record[i])>1)
       {
//	 write(fields[i] + ": " + record[i] + "\n");
         query +=(fields[i]||"NULL") + ",";        
         if(fields[i]=="mfgr") record[i]=record[i]-" ";
         query2 +="'" + replace(record[i],"\"\"","&quote;") + "',";    

        }
  query=query[0..sizeof(query)-2] + ") " + query2[0..sizeof(query2)-2] +")";
  query=replace(query,({"\"","&quote;"}),({"","\""}));

  write(query +";\n");
  }

return 0;

}
