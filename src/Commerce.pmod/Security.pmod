object pub_to_rsa(string s)
{
  array a = Array.map(s/"\n" - ({ "" }), Gmp.mpz, 16);
  return Crypto.rsa()->set_public_key(a[0], a[1]);
}

object priv_to_rsa(string s)
{
  array a = Array.map(s/"\n" - ({ "" }), Gmp.mpz, 16);
  return Crypto.rsa()->set_public_key(a[0], a[1])
    ->set_private_key(a[2]);
}

string rsa_to_pub(object rsa)
{
  return sprintf("%s\n%s\n",
		 rsa->n->digits(16),
		 rsa->e->digits(16));
}

string rsa_to_priv(object rsa)
{
  return sprintf("%s\n%s\n%s\n",
		 rsa->n->digits(16),
		 rsa->e->digits(16),
		 rsa->d->digits(16));
}

string encrypt(string s, string key){

  object rsa = pub_to_rsa(key);
function r = Crypto.randomness.reasonably_random()->read;

s=rsa->encrypt(s, r);
s=MIME.encode_base64(s);
return s;

}      

string decrypt(string s, string key){
  object rsa =
  priv_to_rsa(key);
  s=MIME.decode_base64(s);
  s=rsa->decrypt(s);
  return s;

}


