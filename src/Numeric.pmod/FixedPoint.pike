//! a class for working with fixed point numbers.

int n;
int d;

// create a new fixed point number, number with digits digits in the 
// decimal point.
 void create(float|int|void number, int(1..)|void digits)
{
  d=digits||2;
  if(number)
    n=(int)(number*pow(10,d));
  else n=0;
}

static mixed `+(mixed ... args)
{
   foreach(args, mixed a)
    add(a);

  return this;
}

static mixed `-(mixed ... args)
{
   foreach(args, mixed a)
    sub(a);

  return this;
}

static mixed `*(mixed ... args)
{
   foreach(args, mixed a)
    mul(a);

  return this;
}

static mixed `/(mixed ... args)
{
   foreach(args, mixed a)
    div(a);

  return this;
}

static int `==(mixed args)
{
  if(objectp(args))
  {
    if(!args->_getcomp)
      return 0;
    int n1,d1;
    [n1,d1] = args->_getcomp();
    if((n1==n) && (d1==d))
      return 1;
    werror("components not equal.\n");
    return 0;
  }
  else
  {
    werror("not an object.\n");
    return 0;
  }
}

static string _sprintf(mixed ... args)
{
  return
    "FixedPoint(" + (string)(n/pow(10,d)) + "." + 
      sprintf("%0" + d + "d", (n%pow(10,d))) + ")";
}

static mixed cast(string args)
{
  if(args=="string")
    return (string)(n/pow(10,d)) + "." + 
      sprintf("%0" + d + "d", (n%pow(10,d)));
  else if(args=="float")
    return (float)(n/pow(10,d)) + 
      ((float)(n%pow(10,d)/(float)((pow(10,d)))));
  else if(args=="int")
    return (int)(n/pow(10,d));
  else error("Cannot cast Numeric.FixedPoint to " + args + ".\n");
}

static void add(mixed arg)
{
  if(intp(arg))
    n+=(int)(arg*pow(10,d));
  else
    n+=(int)((float)arg*pow(10,d));
}

static void sub(mixed arg)
{
  if(intp(arg))
    n-=(int)(arg*pow(10,d));
  else
    n-=(int)((float)arg*pow(10,d));
}

static void mul(mixed arg)
{
  if(intp(arg))
    n=(int)(n*arg);
  else
    n=(int)((float)(arg)*n);
}

static void div(mixed arg)
{
    n=(int)(n/(float)(arg));
  
}

static mixed `->(mixed args)
{
  if(args=="_getcomp")
    return getcomp;
}

array getcomp()
{
  return ({n, d});
}
