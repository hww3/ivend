#!/usr/bin/pike

// dumptable - dump db table to tab delimited text.
// version 1.0 of september 8 1998
// hww3@riverweb.com

int main(int argc, string * argv){

if(argc!=6) {

  werror("usage: " + argv[0] + " products|groups dbhost dbname dbuser dbpasswd\n");
  exit (1);
  }

if((argv[1]-" ")!="products" && (argv[1]-" ")!="groups") {

  werror("invalid table name " + argv[1] + "\n");
  exit (1);
  }
  

object s=Sql.sql(argv[2], argv[3], argv[4], argv[5]);

array fields=s->list_fields(argv[1]);

array records=s->query("SELECT * FROM " + argv[1]);
array fl=({});
foreach(fields, mapping f){
  fl+=({f->name});
}

write((fl*"\t")+"\n");

foreach(records, mapping r){
  array rw=({});
  foreach(fields, mapping f){

rw+=({replace(r[f->name]||"NULL",({"\r","\t","\n"}),({"","\\t","\\n"}))});    
    }
  write((rw*"\t")+ "\n");
  }

return 0;

}
