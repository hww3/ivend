/* keys.pmod
 *
 * written by someone at idonex (please let me know who!)
 */

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
