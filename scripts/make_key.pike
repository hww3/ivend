#!/usr/bin/pike -M../src

/* make_key.pike
 *
 */

int write_file(string filename,string what)
{
  int ret;
  object f = Stdio.File();

  if(!f->open(filename,"twc"))
    throw( ({ "Couldn't open file "+filename+".\n", backtrace() }) );
  
  ret=f->write(what);
  f->close();
  return ret;
}


string * generate_keys(int key_size){

 object rsa = Crypto.rsa();
  rsa->generate_key(key_size,
Crypto.randomness.reasonably_random()->read);

  string privkey = Tools.PEM.simple_build_pem
    ("RSA PRIVATE KEY",
     Standards.PKCS.RSA.rsa_private_key(rsa));

  werror(privkey);

return ({privkey});

}



int main(int argc, array(string) argv)
{
  string name;
  int keysize;
  string response;

  write("Getting Ready to Create a new RSA Keypair...\n\n");

  response=readline("Number of bits: ");
  if((int)response<300) { 
    werror(response + " is too small. Using 512...\n");
    keysize=512;
    }
  if((int)response>3000) { 
    werror(response + " is too large. Using 2048...\n");
    keysize=2048;
    }
  keysize=(int)response;
  response=readline("File in which to place the Key: ");
  if(response=="") name="rsakey";
  else name=response;

  string * key = generate_keys(keysize);

//  write_file(name + ".pub", Commerce.Security.rsa_to_pub(rsa));
  write_file(name + ".priv", key[0]);
//  write_file(name + ".pub", key[1]);

  return 0;
}

