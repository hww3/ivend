int check_address(string address){
string mailhost;
array a=address/"@";
if(sizeof(a)!=2) return 0;

object d=Protocols.DNS.client();

mixed mxhost=d->get_primary_mx(a[1]);
if(mxhost!=0) mailhost=mxhost;
else if((mxhost=d->gethostbyname(a[1])) && mxhost[0]!=0)
	mailhost=mxhost[0];
else return 0;
	// ok we've weeded out bad domains and hosts... now let's connect

object f=Stdio.FILE();
if(!f->connect(mailhost, 25)) {
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

f->write("MAIL FROM: <mailcheckr@" + gethostname() + ">\n");
if(readcode(f)/100 !=2) return 0;	// can't talk to this host.

f->write("RCPT TO: <" + address + ">\n");
if(readcode(f)/100 !=2) return 0;	// bad address!

f->write("QUIT\n");
f->close();

return 1;	// good address!

}

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

