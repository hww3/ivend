#!/bin/sh

usage="usage: clean_db.sh <dbhost> <db> <user> <password>"

if [ $# -ne 4 ] ; then
    echo $usage 1>&2
    exit 1
fi

mysql -h $1 -u $3 -p$4 $2 << EOF

DELETE FROM sessions;
DELETE FROM orders;
DELETE FROM orderdata;
DELETE FROM lineitems;
DELETE FROM customer_info;
DELETE FROM payment_info;
DELETE FROM shipments;

EOF

echo All Sessions and Orders Deleted Successfully.
