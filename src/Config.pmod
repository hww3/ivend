/* Config file reader/writer
   Copyright 1998 by Bill Welliver
   hww3@riverweb.com
   
   This file may be used and distributed under the terms of the 
   GNU Public License version 2 or later.

*/

string format_section(string section, mapping attributes){

  string s="";
  
  s+="\n[" + section + "]\n";
  foreach(indices(attributes), string a)
        if(stringp(attributes[a]))
            s = s + a + "=" + (string)attributes[a] + "\n";
        else if(arrayp(attributes[a]))
            foreach(attributes[a], string v)
            s+=a + "=" + v + "\n";

  return s;

}

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

string write(mapping config, array|void order){
    string s="# Configuration file.\n";
    array configs;

    if(order) configs=order;
    else configs=indices(config);
    foreach(configs, string c){
      s+= format_section(c, config[c]) +"\n";
    }

    return s;
}

array get_section_names(string contents){
array sections=({});

array c=contents/"\n";
string section="";

foreach(c, string line) {
  if(sscanf(line, "[%s]", section)==1)
    sections +=({section});
  }
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

  if(search(sections, section)==-1) // we need to create a new section.
    {
    fd->write(format_section(section, attributes));
    return 1;
    }

  else {  // we need to overwrite the existing section.
    mapping m=read(contents);
    m[section]=attributes;
    array order=get_section_names(contents);
    contents=write(m, order);
    fd->seek(0);
    fd->write(contents);
    fd->close();
  }

  return 1;
}
