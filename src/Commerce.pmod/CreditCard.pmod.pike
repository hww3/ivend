
int cc_verify(string card_number){

string *digits=({});
string *digits2=({});
array(string) temp = (card_number/"");

digits=Array.filter((temp),Regexp("[0-9]")->match);
if(sizeof(digits)<10 && sizeof(digits)>16)
  return 0;

for(int i=0; i<sizeof(digits);i++){

  if (((i+1)%2)==0)
    string j=(string)((int)digits[i]*2);
  else continue;
  digits2=(j/"");
  if(sizeof(digits2)>1)
  digits[i]=(string)((int)digits2[0]+((int)digits2[1]));
  else digits[i]=digits2[0];
  }
write(sprintf("%O",digits));
int check=0;
for(int i=0; i<sizeof(digits);i++)
  check+=(int)digits[i];

if ((check%10)==0)
  return 1;
else
  return 0;

}

int expdate_verify(string expdate){

string *digits=({});

string *temp=expdate/"";

digits=Array.filter((temp),Regexp("[0-9]")->match);

string year;
string month;
expdate=(digits * "");

if (sizeof(expdate)==4){
 
  month=expdate[0..1];
  year=expdate[2..3];

}

else if (sizeof(expdate)==3){

  month=expdate[0..0];
  year=expdate[1..2];

}


else return 0;

if((int)year<80) year="1"+year;

mapping time=localtime(time());
if((int)year<time->year) return 0;
else if((int)year==time->year){

  if((int)month<(time->mon+1)) return 0;
  else return 1;

}

return 1;
}
