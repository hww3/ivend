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

array get_section_names(contents){
array sections=({});
return sections;

}

int write_section(string file, string section, mapping attributes){

  if(!(file || !section || !attributes))
    return -1;	// no information was provided.
  object fd=Stdio.File(file, "rw");
  string contents=fd->read();
  if(!contents) {
    werror("Couldn't read contents of " + file + ".\n");
    return -1;
    }

  array sections=get_section_names(contents);

  string before,during,after;
  if(search(contents, "[" + section + "]\n") !=-1){ //create new section
  sscanf(contents, "%s[" + section + "]\n%s\n[%s", before, during, after);

  during="";
  }
  else {
    during="";
    before=contents;
    after="";
  }
foreach(indices(attributes), string a)
        if(stringp(attributes[a]))
            during = during + a + "=" + (string)attributes[a] + "\n";
        else if(arrayp(attributes[a]))
            foreach(attributes[a], string v)
            during+=a + "=" + v + "\n";     
  fd->seek(0);
  if(after) after="\n[" + after;
  else after="";
  fd->write(before + "[" + section + "]\n" + during + after);
  return 1;
}
