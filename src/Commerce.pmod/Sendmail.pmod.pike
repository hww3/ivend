int readcode(object f){

int code;
int space;
string r;

do {
space=' ';
r=f->gets();
if(!r) return 0;
sscanf(r, "%d%c%*s", code, space);
}
while (space=='-');
return code;
}

int sendmail(string sender, string recipient, string message){
int code;
object f=Stdio.FILE();
if(!f->connect("localhost", 25)) {
  werror("ERROR ESTABLISHING SMTP CONNECTION!\n");
  return 0;
  }
if(readcode(f)/100 !=2) {
    f->close();
    return 0;
    }

f->write("HELO " + gethostname() + "\n");
if(readcode(f)/100 !=2){
  f->close();
  werror("NO GREETING FROM MAIL SERVER!\n");
  return 0;
  }
f->write("MAIL FROM: " + sender + "\n");
readcode(f);
f->write("RCPT TO: " + recipient + "\n");
readcode(f);
f->write("DATA\n");
if(readcode(f)!=354){
    f->close();
    return 0;
    }
f->write(message);
f->write(".\n");
readcode(f);
f->write("QUIT\n");
readcode(f);

f->close();

return 1;
}

