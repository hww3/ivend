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

  object rsa  = Standards.PKCS.RSA.parse_public_key(part->decoded_body());
  if(rsa==0) werror("Public Key not Parsed properly.\n");
  function r = Crypto.randomness.reasonably_random()->read;

  s=rsa->encrypt(s, r);


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






