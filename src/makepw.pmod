string make_password(string wordfile, int len) {

string password="";
array words=Stdio.read_file(wordfile||"")/"\n";
if(sizeof(words)<2)

  password=(string)hash((string)(time()))[0..7];
else {
int good=0;
while(good==0){
int w1=random(sizeof(words));
int w2=random(sizeof(words));

if((sizeof(words[w1]) + sizeof(words[w2])) <= len) {
  password=words[w1] + words[w2];
  good=1;
  }
}
}


return password;

}
