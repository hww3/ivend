#!/usr/local/bin/pike -M../src

int main(int argc, string * argv){

  if(argc < 3) {
    werror("Usage: " + argv[0] + " privatekeyfile publickeyfile\n");
    return 0;
  }
  string priv = Stdio.read_file(argv[1]);
  string pub = Stdio.read_file(argv[2]);

  string s1="This is a test...";

  werror("s1: \n\n" + s1 + "\n\n");

  string s2=Commerce.Security.encrypt(s1,pub);

  werror("s2: \n\n" + s2 + "\n\n");

  s2=Commerce.Security.decrypt(s2,priv);

  werror("s2: \n\n" + s2 + "\n\n");
  if(s1==s2) {
  werror("Encrypt/Decrypt successful. Keypair is good.\n");
  return 0;
  }
  else { werror("Encrypt/Decrypt unsuccessful. Keypair is bad.\n");
   return 1;
  }
}
