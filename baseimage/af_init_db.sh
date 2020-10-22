#--------------------------------
#!/bin/bash
# Peter Hammarstronm 2020-01-30
#
#--------------------------------
# Variables
# set the postgres database host, port, user and password according to the environment
# 
: ${HOST:=${DB_ENV_POSTGRES_HOST:=${DB_PORT_5432_TCP_ADDR:='db'}}}
: ${PORT:=${DB_ENV_POSTGRES_PORT:=${DB_PORT_5432_TCP_PORT:=5432}}}
: ${USER:=${DB_ENV_POSTGRES_USER:=${POSTGRES_USER:='odoo'}}}
: ${PASSWORD:=${DB_ENV_POSTGRES_PASSWORD:=${POSTGRES_PASSWORD:='odoo'}}}
: ${DBNAME:=${DB_ENV_POSTGRES_DBNAME:='testdb'}}

PGPASSWORD=$PASSWORD
export PGPASSWORD
#echo "$DB_ENV_POSTGRESS_PASSWORD, $DB_ENV_POSTGRESS_HOST, $DB_ENV_POSTGRESS_PORT, $PGPASSWORD"
#------------------------------------------------------
# GET Modules Change newline to , remove last character
ODOO_MODULES="$(tr '\n' ',' < /installed_modules.conf | sed '$ s/.$//')"
if [ -n $EXTRA_MODULES ]; then  # Not null
  ODOO_MODULES="$ODOO_MODULES,$EXTRA_MODULES"
fi

#----------------------------------------
# Init DB
psql --host $HOST --port $PORT  --username $USER -l | grep -w $DBNAME > /dev/null

if [ $? != 0  ]; then
  echo "Database Does not exist Create DB"
  createdb --host $HOST --port $PORT --username $USER $DBNAME

  if [ -n $ODOO_MODULES ]; then  
    echo "Install Base Modules: $ODOO_MODULES"
    echo ""
    odoo -d $DBNAME --init=$ODOO_MODULES \
      --db_host $HOST \
      --db_port $PORT \
      --db_user $USER \
      --db_password $PASSWORD \
      --load-language sv_SE \
      --stop-after-init
  
    if [ $? = 0  ]; then 
      echo "Modules installed OK"
    else
      echo "Modules install failed error: $?"
    fi
  else
    echo "No Modules installed"
  fi
elif [ -n $EXTRA_MODULES ]; then
  echo "Install Extra Modules: '$EXTRA_MODULES'"
  echo ""
  odoo -d $DBNAME --init=$EXTRA_MODULES \
    --db_host $HOST \
    --db_port $PORT \
    --db_user $USER \
    --db_password $PASSWORD \
    --stop-after-init

  if [ $? = 0  ]; then
    echo "Extra Modules installed OK"
  else
    echo "Extra Modules install failed error: $?"
  fi
else
  echo "Database Already Exist iand no extra modules skipping Databse init"
fi

