/* Decode a coded RSAPublicKey structure */
object parse_public_key(string key)
{
//  WERROR(sprintf("rsa->parse_public_key: '%s'\n", key));
  array a = Standards.ASN1.decode(key)->get_asn1();

//  WERROR(sprintf("rsa->parse_public_key: asn1 = %O\n", a));
  if (!a
      || (a[0] != "SEQUENCE")
      || (sizeof(a[1]) != 3)
      || (sizeof(column(a[1], 0) - ({ "INTEGER" })))
      || a[1][0][1])
    return 0;

  object rsa = Crypto.rsa();
  rsa->set_public_key(a[1][1][1], a[1][2][1]);
//  rsa->set_private_key(a[1][3][1], column(a[1][4..], 1));
  return rsa;
}


string|int encrypt(string s, string key){

#if !constant(_Crypto) || !constant(Crypto.rsa)

werror("Crypto not present! Doing dummy encrypt!\n");

#else /* constant(_Crypto) && constant(Crypto.rsa) */

 if (!key) {
    werror("Could not read public key.");
    return 0;
    }

  object msg = Tools.PEM.pem_msg()->init(key);
  object part = msg->parts["RSA PUBLIC KEY"];

  if (!part) {
    werror("Key file not formatted properly.\n");
    return 0;
    }

  object rsa  = parse_public_key(part->decoded_body());

  function r = Crypto.randomness.reasonably_random()->read;

  s=rsa->encrypt(
s, 
r);


#endif /* constant(_Crypto) && constant(Crypto.rsa) */

  s=MIME.encode_base64(s);     
  return s;



}      

string|int decrypt(string s, string key){

  s=MIME.decode_base64(s);

#if !constant(_Crypto) || !constant(Crypto.rsa)

werror("Crypto not present! Doing dummy decrypt!\n");

#else /* constant(_Crypto) && constant(Crypto.rsa) */

 if (!key) {
    werror("Could not read private key.");
    return 0;
    }

  object msg = Tools.PEM.pem_msg()->init(key);
  object part = msg->parts["RSA PRIVATE KEY"];

  if (!part) {
    werror("Key file not formatted properly.\n");
    return 0;
    }

  object rsa = Standards.PKCS.RSA.parse_private_key(part->decoded_body());


  s=rsa->decrypt(s);  
#endif /* constant(_Crypto) && constant(Crypto.rsa) */

  return s;
}






