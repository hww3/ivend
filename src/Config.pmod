/* Config file reader/writer
   Copyright 1998 by Bill Welliver
   hww3@riverweb.com
   
   This file may be used and distributed under the terms of the 
   GNU Public License version 2 or later.

*/

mapping read(string contents){
  mapping config=([]);
  string section,attribute,value;
  array c;
  if(contents)
   c=contents/"\n";
  else return ([]); 
 foreach(c, string line) {
    if((line-" ")[0..0]=="[") { // We've got a section header
      sscanf(line,"%*s[%s]%*s",section);
      if(!config[section])
        config[section]=([]);
    }
   if(sscanf(line,"%s=%s", attribute, value)==2) // attribute line.
      if(config[section][attribute] && arrayp(config[section][attribute]))
	config[section][attribute]+=({value});
      else if(config[section][attribute])
	config[section][attribute]=({config[section][attribute]}) + ({value});
      else config[section][attribute]=value;
  }
return config;
}

string write(mapping config){
string s="# Configuration file.\n";
array configs=indices(config);

foreach(configs, string c){
  s+="\n[" + c + "]\n";
  foreach(indices(config[c]), string a)
    if(stringp(config[c][a]))
      s = s + a + "=" + (string)config[c][a] + "\n";
    else if(arrayp(config[c][a]))
      foreach(config[c][a], string v)
        s+=a + "=" + v + "\n";

  }
return s;
}
