#!/bin/bash
#--------------------------------
# Jakob Krabbe 2020-04
# Arbetsförmedlingen AF CRM
# Vertel AB
# www.vertel.se
#--------------------------------

export ODOO_SERVER_CONF=/etc/odoo/odoo.conf
export ODOOADDONS=`ls -d /usr/share/odoo-* /usr/share/odooext-* | grep -v odoo-addons | tr "\n" ","`

# IF AND VALID POSSIBLE, INCLUDE BRANCH
# bash af_init_odooprojects.sh 12.0-AFC-155

branch=$1
origin="/home/$USER"
destination="/usr/share"

odooprojects=( 
    # Vertel
    "odoo-account|https://github.com/vertelab/odoo-account.git" 
    "odoo-l10n_se|https://github.com/vertelab/odoo-l10n_se.git" 
    "odoo-af|https://github.com/vertelab/odoo-af.git" 
    "odoo-base|https://github.com/vertelab/odoo-base.git" 
    "odoo-user-mail|https://github.com/vertelab/odoo-user-mail.git" 
    "odoo-imagemagick|https://github.com/vertelab/odoo-imagemagick.git" 
    "odoo-server-tools|https://github.com/vertelab/odoo-server-tools.git" 
    # OCA 
    "odooext-oca-partner-contact|https://github.com/OCA/partner-contact.git" 
    "odooext-oca-web|https://github.com/OCA/web.git" 
    "odooext-oca-hr|https://github.com/OCA/hr.git" 
    "odooext-oca-social|https://github.com/OCA/social.git" 
    "odooext-oca-server-auth|https://github.com/OCA/server-auth.git" 
)

for row in "${odooprojects[@]}" 
do
	cd ~
	dir=`echo $row|cut -d"|" -f 1`
	repo=`echo $row|cut -d"|" -f 2`
	validPath="$origin/$dir"
	# remove path, if any
	echo "checking repo: $repo"
	echo "checking branch: $branch"
	echo "$origin"
	echo "checking dir: $dir"
	echo "checking valid path: $validPath"
	if [ -d "$validPath" ]
        then
		echo "remove valid path: $validPath"
		rm -Rf $validPath
	fi
	echo "git clone -b 12.0 $repo $validPath"
	mkdir -p $validPath
	sudo chown odoo:odoo -R $validPath
	sudo chmod g+w -R $validPath
	if [ -z "$branch" ]
        then
		git clone -b 12.0 --depth 1 $repo $validPath
	else
		git clone -b $branch --depth 1 $repo $validPath  2> /dev/null || git clone -b 12.0 --depth 1 $repo $validPath
	fi
	mv $validPath $destination
	echo "Ending loop: $validPath"
done

# update addons_path 
CMD="s/^addons_path.*=.*/addons_path=${ODOOADDONS//"/"/"\/"}/g"
sudo perl -i -pe $CMD $ODOO_SERVER_CONF
