#!/usr/bin/pike -M../src

int main(int argc, string * argv){

  if(argc < 3) {
    werror("Usage: " + argv[0] + " privatekeyfile publickeyfile\n");
    return 0;
  }
  string priv = Stdio.read_file(argv[1]);
  string pub = Stdio.read_file(argv[2]);

  string s2="This is a test...";

  werror("s2: \n\n" + s2 + "\n\n");

  s2=Commerce.Security.encrypt(s2,pub);

  werror("s2: \n\n" + s2 + "\n\n");

  s2=Commerce.Security.decrypt(s2,priv);

  werror("s2: \n\n" + s2 + "\n\n");

  return 0;
}
