#!/bin/sh

if [ -x "/usr/ucb/echo" ]
then
  PATH=/usr/ucb:$PATH
fi

echo 
echo iVend 1.0 Store Creation Script
echo

if [ ! -d "../configurations" ]
then
  default=$PWD
  echo -n Location of iVend configuration files [$default]: 
  read configdir
  if [ -z "$configdir" ] 
  then
    configdir=$default
  fi
else
  configdir="../configurations"
fi

default=$PWD
echo -n Directory of New Store [$default]: 
read storedir
if [ -z "$storedir" ] 
then
  storedir=$default
fi

default="test"
echo -n Store ID [$default]:
read storename
if [ -z "$storename" ]
then
  storename=$default
fi

default="iVend Test Store"
echo -n Store Description [$default]:
read storedescription
if [ -z "$storedescription" ]
then 
  storedescription=$default
fi

default="localhost"
echo -n Database Host [$default]:
read dbhost
if [ -z "$dbhost" ]
then 
  dbhost=$default
fi

default=$storename
echo -n Database Name [$default]:
read db
if [ -z "$db" ]
then 
  db=$default
fi

default=$storename
echo -n Database User [$default]:
read dbuser
if [ -z "$dbuser" ]
then 
  dbuser=$default
fi

default=""
echo -n Database User \($dbuser\) Password [$default]:
read dbpassword
if [ -z "$dbpassword" ]
then 
  dbpassword=$default
fi

if [ ! -d $storedir ] 
then 
  echo Creating Directory $storedir.
  mkdir $storedir
fi

if [ ! -d $storedir/private ]
then
  mkdir $storedir/private
fi

echo Populating Store Directory.
cp -r ../examples/standard/* $storedir

echo Creating RSA Keypair.
pike -M ../src ./make_key.pike 1024 $storedir/private/key

if [ -f $configdir/global ]
then
  echo Writing Global Configuration File.
  cat << EOF > $configdir/global
\$create_index=No
\$move_onestore=No
EOF
fi
echo Writing Configuration File.
cat << EOF > $configdir/$storename

\$config=$storename
\$name=$storedescription
\$root=$storedir
\$publickey=$storedir/private/key.pub
\$privatekey=$storedir/private/key.priv
\$config_user=$adminuser
\$db=$db
\$dbhost=$dbhost
\$dblogin=$dbuser
\$dbpassword=$dbpassword
EOF

cp ../data/schema.mysql /tmp/$$schema
vi /tmp/$$schema
echo Populating Database.
mysql -h $dbhost -u $dbuser --password=$dbpassword $db < /tmp/$$schema
rm /tmp/$$schema

echo Your store has been set up successfully.
echo 
echo You must now reload the iVend module using the Roxen Config Interface.
echo Use the iVend configuration interface to complete any remaining 
echo setup options.
echo
