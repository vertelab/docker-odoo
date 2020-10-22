#--------------------------------
#!/bin/bash
# Mikael Holm 2020-05-12
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

echo "Install: '$INSTALL_MODULES'"
if [[ -n $INSTALL_MODULES ]]; then  
  echo "Installing modules: $INSTALL_MODULES"
  echo ""
  odoo -d $DBNAME --init=$INSTALL_MODULES \
    --db_host $HOST \
    --db_port $PORT \
    --db_user $USER \
    --db_password $PASSWORD \
    --stop-after-init
  
  if [ $? = 0  ]; then 
    echo "Modules installed OK"
  else
    echo "Modules install failed error: $?"
  fi
else
  echo "No modules to install"
fi

echo "Update: '$UPDATE_MODULES'"
if [[ -n $UPDATE_MODULES ]]; then  
  echo "Updating modules: $UPDATE_MODULES"
  echo ""
  odoo -d $DBNAME --update=$UPDATE_MODULES \
    --db_host $HOST \
    --db_port $PORT \
    --db_user $USER \
    --db_password $PASSWORD \
    --stop-after-init
  
  if [ $? = 0  ]; then 
    echo "Modules updated OK"
  else
    echo "Modules update failed error: $?"
  fi
else
  echo "No modules to update"
fi

echo "Remove: '$REMOVE_MODULES'"
echo "Not supported by Odoo cmdline"
