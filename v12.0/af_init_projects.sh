#!/bin/bash
#--------------------------------
# Mikael Holm 2020-05
# Arbetsförmedlingen AF CRM
# Vertel AB
# www.vertel.se
#--------------------------------
# 2020-10-21 13:58

destination="/usr/share"
odoomodules="/usr/share/core-odoo/addons"
clonelog="/etc/odoo/clonedrepos.log"
allmodules="/etc/odoo/allmodules.lst"
defaultbranch="Dev-12.0"
#defaultbranch="12.0"

odooprojects=( 
    # Vertel
    "odoo-af||https://github.com/vertelab/odoo-af.git" 
    "odoo-base||https://github.com/vertelab/odoo-base.git" 
    "odoo-edi||https://github.com/vertelab/odoo-edi.git"
    "odoo-l10n_se||https://github.com/vertelab/odoo-l10n_se.git" 
    "odoo-account||https://github.com/vertelab/odoo-account.git" 
    "odoo-user-mail||https://github.com/vertelab/odoo-user-mail.git" 
    "odoo-imagemagick||https://github.com/vertelab/odoo-imagemagick.git" 
    "odoo-server-tools||https://github.com/vertelab/odoo-server-tools.git" 
    "odoo-hr||https://github.com/vertelab/odoo-hr.git"
    # Use Vertel versions of OCA modules
    "odooext-oca-web||https://github.com/vertelab/web.git"
    "odooext-oca-server-auth||https://github.com/vertelab/server-auth.git" 

    # OCA 
    "odooext-oca-partner-contact||https://github.com/OCA/partner-contact.git" 
    "odooext-oca-hr||https://github.com/OCA/hr.git" 
    "odooext-oca-social||https://github.com/OCA/social.git" 
)

tt0=`date +%s`
for row in "${odooprojects[@]}" 
do
    t0=`date +%s`
    dir=`echo $row|cut -d"|" -f 1`
    branch=`echo $row|cut -d"|" -f 2`
    repo=`echo $row|cut -d"|" -f 3`
    validPath="$destination/$dir"
    odoomodules="$odoomodules,$validPath"
    echo "using repo: $repo  branch: $branch  dir: $dir  validpath: $validPath"

    # remove path, if any
    if [ -d "$validPath" ]
        then
        echo "remove valid path: $validPath"
        rm -Rf $validPath
    fi

    if [ -z "$branch" ]
        then
        branch=$defaultbranch
    fi

    echo "git clone -b $branch $repo $validPath"
    actualbranch=$branch
    # If named branch "Dev-12.0" or other doesn't exist clone branch 12.0
    if ! git clone -b $branch --depth 1 $repo $validPath 2> /dev/null
    then
        actualbranch="12.0"
        echo "git clone -b $actualbranch $repo $validPath"
        git clone -b $actualbranch --depth 1 $repo $validPath
    fi
    
    # Save log of latest commit for project repo 
    gitOutput=`git -C $validPath log --pretty=format:'%H - (%cD) %s <%an>' -1` 
    echo "$validPath ($actualbranch): $gitOutput" | tee -a $clonelog

    # Save list of all modules in project
    # Should this be in utv-docker?
    find $validPath -name __mani* | cut -d"/" -f 5 >> $allmodules
    t1=`date +%s`
    echo Time spent cloning: $[$t1-$t0] seconds
    echo ""
done
tt1=`date +%s`

echo ""
echo Total time spent cloning: $[$tt1-$tt0] seconds
echo ""

# Update addons_path 
echo "Updating addons_path: $odoomodules"
perl -i -pe "s%addons_path.*$%addons_path = $odoomodules%g" /etc/odoo/odoo.conf
perl -i -pe "s%admin_passwd.*$%admin_passwd = $ODOO_ADMIN_PWD%g" /etc/odoo/odoo.conf
