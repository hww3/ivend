
string encrypt(string s, string key){

  object rsa = keys.pub_to_rsa(key);
function r = Crypto.randomness.reasonably_random()->read;

s=rsa->encrypt(s, r);
s=MIME.encode_base64(s);
return s;

}      

string decrypt(string s, string key){
  object rsa =
  keys.priv_to_rsa(key);
  s=MIME.decode_base64(s);
  s=rsa->decrypt(s);
  return s;

}
