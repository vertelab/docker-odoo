#--------------------------------
#!/bin/bash
# Peter Hammarstronm 2020-01-30
#
#--------------------------------
# Variables
# set the postgres database host, port, user and password according to the environment
# and pass them as arguments to the odoo process if not present in the config file
: ${HOST:=${DB_PORT_5432_TCP_ADDR:='db'}}
: ${PORT:=${DB_PORT_5432_TCP_PORT:=5432}}
: ${USER:=${DB_ENV_POSTGRES_USER:=${POSTGRES_USER:='odoo'}}}
: ${PASSWORD:=${DB_ENV_POSTGRES_PASSWORD:=${POSTGRES_PASSWORD:='odoo'}}}


ODOO_ADDONS='/mnt/extra-addons'
ODOO_DBNAME='testdb'
#EXTRA_NODULES=""

PGPASSWORD=$PASSWORD
export PGPASSWORD
#echo "$DB_ENV_POSTGRESS_PASSWORD, $DB_ENV_POSTGRESS_HOST, $DB_ENV_POSTGRESS_PORT, $PGPASSWORD"

#------------------------------------------------------
# GET Modules Change newline to , remove last character

#ODOO_MODULES="$(tr '\n' ',' < /installed_modules.conf | sed '$ s/.$//')"
echo "Modules to be install:" 
#echo "$ODOO_MODULES"
echo "$EXTRA_MODULES"
echo ""

#----------------------------------------
# Init DB
  echo "Install Base Modules:"
  echo ""
  odoo -d $ODOO_DBNAME -i $EXTRA_MODULES \
    --db_host $HOST \
    --db_port $PORT \
    --db_user $USER \
    --db_password $PASSWORD \
    --stop-after-init

if [ $? = 0  ]; then 
  echo "Modules installed OK"
else
  echo "Modules install failed eroor: $?"
fi


