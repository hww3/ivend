/* make_key.pike
 *
 * written by someone at idonex (please let me know who!)
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

int main(int argc, array(string) argv)
{
  string name;
  int keysize;
  string response;
  response=readline("Number of bits: ");
  if((int)response<100) keysize=512;
  keysize=(int)response;
  response=readline("Base filename: ");
  if(response=="") name="rsakey";
  else name=response;
  write("Generating "+keysize+" bit RSA keypair...\n");

  function r = Crypto.randomness.reasonably_random()->read;

  object rsa = Crypto.rsa();
  rsa->generate_key(keysize, r);

  write_file(name + ".pub", keys.rsa_to_pub(rsa));
  write_file(name + ".priv", keys.rsa_to_priv(rsa));

}

