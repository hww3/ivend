#!NOMODULE
/*
cc_verfiy
Author - Allen Bolderoff 
(with copious amounts of code stolen shamelessly from 
Henrik Grubbström <grubba@infovav.se>) 

and based entirely on the algorithm supplied 
with CREDIT_CARD_VALIDATION_LIB.PL v1.0 
by Doug Miles dmiles@primenet.com

LICENSE - GPL-2.0 and or later
WARRANTY - NONE WHAT SO EVER - implied or otherwise.

*/


/*
This is some constants for number of digits per card
*/
constant hash_function = ({ 0, 2, 4, 6, 8, 1, 3, 5, 7, 9 });
constant card_digits =([ "VISA":16, "AMEX":15, "MasterCard":16,
 "Discover": 16]);


// subroutine creditcheck() starts here
int cc_verify(string ccn, string card_type)
{
// perror(card_type + "\n\n" + ccn + "\n");
// clear spaces & non numeric characters here
string number = replace(ccn, ({ " ", "-" }), ({ "", "" }));

// Check if any non numeric characters exist, and exit with  1 if no good
string validnumbers = replace(number,
                ({ "0","1","2","3","4","5","6","7","8","9" }),
                ({ "","","","","","","","","","" }));

if (validnumbers != "") {
  werror("we have extraneous digits\n");
   return(1);
}

//verify card number length and exit with 1 if bad
// perror("size of number: " + sizeof(number) + "\n");
// perror("size to match: " + card_digits[card_type] + "\n");
if (sizeof(number)!= card_digits[card_type]) {
 werror("wrong number of digits in card number\n");
 return(1);
}

// reverse digits here
array digits = Array.map(reverse(number/""), lambda(string n) { return
(int)n; });

/* 
double every second digit of the reversed number.

ceck whether it is more than 9 when doubled.
if it is more than 9, the we minus 9 from the doubled figure, or if it
is below 9, then we just double it. 

*/ 
int sum=0;
for(int i=1; i<sizeof(digits); i+=2) {
  if((digits[i]*2) > 9) 
    { 
    (digits[i]*=2); 
    (digits[i]-=9); 
    } else { 
    digits[i]*=2; 
    }
}

/*
add all digits (including double values & non doubled figures) together
and put in value of "sum"
*/
for(int i=0; i<sizeof(digits); i+=1) {
  sum += digits[i];
}

/*
is sum divided by 10 equal to 0?
if so, then the card should be good(exit with 0), 
if not, then card is bad (exit with 1)
*/  
sum %= 10;
if (sum != 0) 
{ 
return(1); 
}
return(0); 
}






int expdate_verify(string expdate){

array digits=({});

array temp=expdate/"";

digits=Array.filter((temp),Regexp("[0-9]")->match);
 if ( (sizeof(digits)<5 ) || (sizeof(digits)>6)) { werror("incorrect number of digits in expdate. got " + sizeof(digits) + "\n");
return 0; }
string year;
string month;
expdate=(digits * "");

if (sizeof(expdate)==5){
 
  month=expdate[0..0];
  year=expdate[1..4];
  if(month=="0") {
	werror("only got 5 digit expdate and digit zero is 0.\n");
    return 0;
	
	}
}

else if (sizeof(expdate)==6){

  month=expdate[0..1];
  year=expdate[2..5];

}


else { return 0;
  werror("got less than 5 or greater than 6 digits in expdate.\n");

}
if((int)year<80) year="1"+year;

mapping time=localtime(time());
if((int)year<(time->year+1900)) { werror("got bad year in expdate.\n"); 
	return 0; }
else if((int)year==(1900+time->year)){

  if((int)month<(time->mon+1)) {werror("got good year but bad month in expdate.\n"); 
return 0; }
  else return 1;

}

return 1;
}
