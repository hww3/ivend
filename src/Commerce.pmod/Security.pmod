string|int encrypt(string s, string key){


 if (!key) {
    werror("Could not read public key.\n");
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

  s=MIME.encode_base64(s);     
  return "iVEn" + s;



}      

string|int decrypt(string s, string key){

if(s[0..3]!="iVEn")
  return(0);
else s=s[4..];
  s=MIME.decode_base64(s);


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

// perror("decrypting...\n");
//  perror(s);
  s=rsa->decrypt(s);  

  return s;
}






