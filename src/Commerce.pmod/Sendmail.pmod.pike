int readcode(object f){

perror("readcode() \n");

int code;
int space;
string r;

do {
werror("Loop...\n");
space=' ';
werror("getting line...\n");
r=f->gets();
werror("got line...\n");
if(!r) return 0;
sscanf(r, "%d%c%*s", code, space);
perror("space: " + (string)space + "\n");
}
while (space=='-');
perror("returning code " + code + "\n");
return code;
}



int check_address(string address){
string mailhost;
array a=address/"@";
if(sizeof(a)!=2) return 0;

object d=Protocols.DNS.client();

mixed mxhost=d->get_primary_mx(a[1]);
// werror(mxhost + "\n");
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

 werror("Contacted " + mxhost + "\n");

int r;
if(r=readcode(f)/100 !=2) {
    f->close();
    werror("BAD WELCOME MESSAGE: " + r + "\n");
    return 0;
    }

 werror("Got welcome message from " + mxhost + "\n");

f->write("HELO " + gethostname() + "\r\n");
werror("wrote HELO " + gethostname() + "\n");
if(r=readcode(f)/100 !=2){
  f->close();
  werror("NO GREETING FROM MAIL SERVER: " + r + "!\n");
  return 0;
  }

 werror("Sent HELO to " + mxhost + "\n");

f->write("MAIL FROM: <" + address + ">\r\n");
if(r=readcode(f)/100 !=2) {
  return 0; // bad address!
  }
f->write("RCPT TO: <" + address + ">\r\n");
if(r=readcode(f)/100 !=2) {
  return 0; // bad address!
} else {
  perror("The VRFY TEST has passed\n");
  f->write("QUIT\n");
  f->close();

  return 1;       // good address!
}
}
int sendmail(string sender, string|array recipient, string message){
int code;
array recip=({});
object f=Stdio.FILE();
if(!f->connect("localhost", 25)) {
  werror("ERROR ESTABLISHING SMTP CONNECTION!\n");
  return 0;
  }
if(readcode(f)/100 !=2) {
    f->close();
    return 0;
    }

f->write("HELO " + gethostname() + "\r\n");
if(readcode(f)/100 !=2){
  f->close();
  werror("NO GREETING FROM MAIL SERVER!\n");
  return 0;
  }
f->write("MAIL FROM: " + sender + "\r\n");
readcode(f);
if(!arrayp(recipient)) recip=({recipient});
else recip=recipient;
foreach(recip, string rc){
  f->write("RCPT TO: " + rc + "\r\n");
  if(readcode(f)!=250) werror("SEND FAILED FOR " + rc + "\n");

  }
f->write("DATA\r\n");
if(readcode(f)!=354){
    f->close();
    return 0;
    }
f->write(message);
if(message[(sizeof(message)-1)..]=="\n")
  f->write(".\r\n");
else f->write("\r\n.\r\n");
readcode(f);
f->write("QUIT\r\n");
readcode(f);

f->close();

return 1;
}

