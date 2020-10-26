#!/bin/bash
#--------------------------------
# Mikael Holm 2020-05
# Arbetsförmedlingen AF CRM
# Vertel AB
# www.vertel.se
#--------------------------------
# 2020-10-21 13:58

scriptname=$(basename -- "$0")
destination="/usr/share"
odoomodules="/usr/share/core-odoo/addons"
clonelog="/etc/odoo/clonedrepos.log"
allmodules="/etc/odoo/allmodules.lst"
masterbranch="12.0"
defaultbranch="Dev-12.0"
actualbranch=""

# If script called with branch argument, save in featurebranch
if [ -n "$1" ]; then
        featurebranch="$1"
fi
# Valid branches to try cloning from are stored in array in relevant order
# Different repos in array depending on if branch name was used as argument or not,
# and what the branch name is when used
if [ -z "$featurebranch" ] || [ "$featurebranch" == "$defaultbranch" ]; then
        validbranches=( $defaultbranch $masterbranch )
elif [ "$featurebranch" != "$masterbranch" ]; then
        validbranches=( $featurebranch $defaultbranch $masterbranch )
else
        validbranches=( $masterbranch )
fi

echo "This branch order is used when cloning the GitHub repos: "${validbranches[@]}""

# Any branch specified below will get highest priority when cloning the repo
# Even higher priority than the branch argument for this script
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
    scriptbranch=`echo $row|cut -d"|" -f 2`
    repo=`echo $row|cut -d"|" -f 3`
    validPath="$destination/$dir"
    odoomodules="$odoomodules,$validPath"
    echo "using repo: $repo  branch: $scriptbranch  dir: $dir  validpath: $validPath"

    # remove path, if any
    if [ -d "$validPath" ]
        then
        echo "remove valid path: $validPath"
        rm -Rf $validPath
    fi

    if [ -n "$scriptbranch" ]; then
	validbranches=("${scriptbranch[@]}" "${validbranches[@]}")
	echo "Specific branch specified in script $scriptname for repo $repo."
	echo "Now added at the first position of branches to clone: "${validbranches[@]}""
    fi

    for branch in "${validbranches[@]}"
    do
        echo "git clone -b $branch $repo $validPath"
        if ! git clone -b $branch --depth 1 $repo $validPath 2> /dev/null
        then
                echo "Branch $branch is not valid, trying next..."
                continue
        else
		actualbranch=$branch
		if [ -n "$scriptbranch" ]; then scriptbranch=""; unset validbranches[0];fi
		break
        fi
    done

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
