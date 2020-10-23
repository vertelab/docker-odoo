#!/bin/bash
#
# Vertel Kubernetes Odoo Operation & Deployment script
#

###################
#    FUNCTIONS   #
###################


#---------------------------
# BASIC SETUP
#---------------------------
basic_setup () {
	echo -> /dev/null
}


#---------------------------
# INSTALL ALL
#---------------------------
install_all () {

	echo ""
	echo -e "\e[96mINSTALLING KUBERNETES...\e[0m"
	sudo snap install microk8s --classic
	sudo usermod -a -G microk8s $USER
	#sudo chown -f -R $USER ~/.kube
	sudo chown -R $USER $HOME/.kube
	sudo snap alias microk8s.kubectl kubectl
	microk8s.kubectl config view --raw > $HOME/.kube/config
	sudo microk8s enable registry
	sudo microk8s enable registry:size=40Gi
	echo "Checking Kubernetes status, waiting until up and running"
	microk8s.status --wait-ready

	microk8s enable helm	
	
	echo ""
	echo -e "\e[96mINSTALLING DOCKER - FIRST PREREQUISITES...\e[0m"
	sudo apt update
	sudo apt install apt-transport-https ca-certificates curl software-properties-common
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
	sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable"
	sudo apt update
	apt-cache policy docker-ce
	echo -e "\e[96mINSTALLING DOCKER...\e[0m"
	sudo apt install docker-ce
	echo -e "\e[96mDOCKER Daemon status...\e[0m"
	sudo systemctl status docker

	echo -e "\e[96mAdding user ${USER} to Docker group...\e[0m"
	sudo usermod -aG docker ${USER}
	su - ${USER}
}


#-------------------------------
# BUILDING, TAGGING and PUSHING
#-------------------------------
build_all () {
	
	echo ""
	echo -e "\e[96mBUILDING IMAGES...\e[0m"
	
	# CLONE repo - We need to clone the repos that exist in BitBucket today
	# But here we will clone them for a new repo/s in GitHub Vertel (copied from AF Bitbucket)
	# Call separate function here to perform the clone from GitHub...
	#clone_github_pod_repo

	echo ""
	echo -e "\e[95mNow building baseimage...\e[0m\n"
	cd git_repos/baseimage
	# ToDo - Only build if it doesn't exist...
	sudo docker build . -t "${REGISTRY_URL}/${BASEIMAGE}:latest"
	BASEIMAGE_ID=$(sudo docker images -q "${REGISTRY_URL}/${BASEIMAGE}:latest")
	sudo docker tag $BASEIMAGE_ID "${REGISTRY_URL}/${BASEIMAGE}:latest"
	sudo docker push "${REGISTRY_URL}/${BASEIMAGE}"
	echo -e "\n\e[95mBaseimage ${BASEIMAGE} with image ID $BASEIMAGE_ID pushed to ${REGISTRY_URL}\e[0m"
	cd - > /dev/null

	echo ""
	echo -e "\e[95mNow building v12.0 image...\e[0m\n"
	sleep 2
	cd git_repos/v12.0
	sudo docker build . -t "${REGISTRY_URL}/${V12IMAGE}:${VERSION}"
	V12IMAGE_ID=$(sudo docker images -q "${REGISTRY_URL}/${V12IMAGE}:${VERSION}")
	sudo docker tag $V12IMAGE_ID "${REGISTRY_URL}/${V12IMAGE}:${VERSION}"
	sudo docker push "${REGISTRY_URL}/${V12IMAGE}"
	echo -e "\n\e[95mv12.0 image ${V12IMAGE} with image ID $V12IMAGE_ID pushed to ${REGISTRY_URL}\e[0m\n"
	echo $DELIMITER
	cd - > /dev/null
}


#-------------------------------
# DEPLOY ALL PODs
#-------------------------------
deploy_all () {
	
	echo ""
	echo -e "\e[96mStarting Deploying...\e[0m"
	
	NAMESPACE="${BRANCH}-${USER}"
	echo -e "\e[95m\nNamespace $NAMESPACE will be used for the deployment. (Format: <BRANCH>-<USER>)\e[0m\n"
	NAMESPACE_EXIST=$(kubectl get namespace --all-namespaces | grep -e $NAMESPACE)

	if [ -z "$NAMESPACE_EXIST" ]; then
		kubectl create namespace $NAMESPACE
		kubectl get namespace $NAMESPACE
	else	
		echo -e "\e[95mNamespace ${NAMESPACE} already exist. POD will be upgraded and revision stepped.\e[0m"
		kubectl get namespace $NAMESPACE
		sleep 3
	fi

	echo -e "\e[95m\nPlease - Delete namespace with '-dn $NAMESPACE' when not used anymore - test finished successfully and branch merged!\e[0m"
	sleep 4
	
	TEMP_DEPLOY_LOG_FILE=$(date "+%F-%T")
	TEMP_DEPLOY_LOG_FILE="${PWD}/_deploy_history_${TEMP_DEPLOY_LOG_FILE}.log"
	echo "" | tee -a $TEMP_DEPLOY_LOG_FILE
	cd git_repos
	if [ -z "$DEBUG" ]; then
		helm upgrade --install "v12-${BRANCH}-${USER}" ./odoo-helm --set fullnameOverride="v12-${BRANCH}-${USER}" --set image.repository="${REGISTRY_URL}/${V12IMAGE}" --set image.tag=${VERSION} --namespace ${NAMESPACE} | grep -ve 'NOTES:' -e 'export' -e 'echo' -e 'Get the application URL' | tee -a $TEMP_DEPLOY_LOG_FILE
	else	
		helm upgrade --install "v12-${BRANCH}-${USER}" ./odoo-helm --set fullnameOverride="v12-${BRANCH}-${USER}" --set image.repository="${REGISTRY_URL}/${V12IMAGE}" --set image.tag=${VERSION} --namespace ${NAMESPACE} | tee -a $TEMP_DEPLOY_LOG_FILE
	fi
	cd - > /dev/null
	export NODE_PORT=$(kubectl get --namespace kalle8-olsric -o jsonpath="{.spec.ports[0].nodePort}" services v12-kalle8-olsric)
	export NODE_IP=$(kubectl get nodes --namespace kalle8-olsric -o jsonpath="{.items[0].status.addresses[0].address}")
	#echo "URL to the CRM appölication: http://$NODE_IP:$NODE_PORT" | tee -a $TEMP_DEPLOY_LOG_FILE
	echo -e "\n\e[95mURL to the CRM application: http://$NODE_IP:$NODE_PORT\e[0m" | tee -a $TEMP_DEPLOY_LOG_FILE
	echo "" | tee -a $TEMP_DEPLOY_LOG_FILE
	echo $DELIMITER >> $TEMP_DEPLOY_LOG_FILE
	cat $TEMP_DEPLOY_LOG_FILE $DEPLOY_LOG_FILE > "${DEPLOY_LOG_FILE}_NEW_TEMP"
	rm -rf $TEMP_DEPLOY_LOG_FILE
	mv -f "${DEPLOY_LOG_FILE}_NEW_TEMP" $DEPLOY_LOG_FILE
	echo -e "\e[95mHistory with all ${USER} deployments are saved in file: ${PWD}/${DEPLOY_LOG_FILE}\e[0m\n"
	echo $DELIMITER
}


#-------------------------------
# CLONE GITHUB POD REPOS
#-------------------------------
clone_github_pod_repo () {

	echo ""
	echo -e "\e[96mCloning GitHub POD repos..\e[0m"
	echo "ToDo"
	echo ""

}


#-------------------------------
# CLONE GITHUB HELM REPO
#-------------------------------
clone_helm_repo () {

	echo ""
	echo -e "\e[96mCloning GitHub Helm repo..\e[0m"
	echo "ToDo"
	echo ""

}


#---------------------------
# INSTALLATION STATUS
#---------------------------
installation_status () {
	
	echo ""
	echo -e "\e[96mOS Version...\e[0m"	
	lsb_release -sd

	echo ""
	echo -e "\e[96mKubernetes Status...\e[0m"	
	microk8s.status | grep microk8s	
	
	echo ""
	echo -e "\e[96mDocker Status...\e[0m"
	systemctl status docker | grep Active
}


#---------------------------
# POD / DEPLOYMENT STATUS
#---------------------------
## !! Have to grep to minimize output depending on feature branch / names !! ##
pod_status () {

	#if [ -z '$BRANCH' ]; then
	#	BRANCH = ""
	#fi

	echo ""
	echo -e "\e[96mPODs Status and other...\e[0m"
	if [ -n "$DEBUG" ]; then
		echo -e "\e[96mList PODs in all namespaces when debug is used...\e[0m"
		kubectl get pod --all-namespaces
	else	
		kubectl get pods --show-labels | grep -e '$BRANCH' -e '$NAMESPACE'
	fi
	echo ""
	kubectl get deployments | grep -e '$BRANCH' -e '$NAMESPACE'
	echo ""
	kubectl get services | grep -e CLUSTER-IP -e '$BRANCH'
	if [ -n "$DEBUG" ]; then
		echo -e "\e[96mDetailed POD status when debug is used...\e[0m"
		kubectl describe pods --all-namespaces
	fi
	echo ""
	kubectl get namespace
	echo ""
	docker images	
	echo -e "\e[96mUrl to access the AF CRM service:\e[0m"
	echo "ToDo - web CRM url..."
	echo ""
}


#---------------------------
# DELETE NAMESPACE
#---------------------------
delete_namespace () {

	echo ""
	echo -e "\e[96mDeleting Namespace...\e[0m"
	kubectl get namespace $NAMESPACE_DELETE
	kubectl delete namespace $NAMESPACE_DELETE
	echo ""
}

#---------------------------
# INSTALLATION DELETE
#---------------------------
installation_delete () {
	
	echo ""
	echo -e "\e[31mDelete Docker installation...\e[0m"	
	sudo apt-get remove docker-ce

	echo ""
	echo -e "\e[31mDelete Kubernetes installation...\e[0m"	
	microk8s.status | grep microk8s	
	snap list |grep microk8s
	microk8s.reset
	snap remove microk8s
	#microk8s.status | grep microk8s	
	#snap list |grep microk8s
}


#---------------------------
# Usage 
#---------------------------
usage () {
	echo ""	
	echo "NAME" 
	echo "  `basename $0` [OPTIONS]"
	echo
	echo "OPTIONS"
	echo "  --branch <branch name>	Branch name in GitHub. Mandatory."
	echo "  -i all			Installation of Kubernetes and Docker."
	echo "  -b all			Building, tagging and pushing images."
	echo "  -d all			Deploying PODs."

	echo "  -s				Status information, both for installations and PODs."
	echo "  -ns <namespace>		Namespace. Only used together with status."
	echo "  -dn <namespace>		Delete specified Namespace."
	echo "  --debug			Debug enabled. Some additional output information from status command."
	#echo "  --delete			DO NOT USE! Removing Docker and Kubernetes installation!s DO NOT USE!"
	echo "  -h				This help menu." 
	echo ""	
	echo "EXAMPLES"
	echo "  # `basename $0` -s"
	echo "  # `basename $0` --branch my_feature_branch -b all"
	echo "  # `basename $0` --branch my_feature_branch2 -b all -d all"
	echo "  # `basename $0` --branch my_feature_branch3 -s --debug"
	echo "  "
exit
}


###########################
#    MAIN SCRIPT START    #
###########################

# Dir where script is located.
#cd `dirname $0`/

cd ~
REGISTRY_URL="localhost:32000"
BASEIMAGE="af-crm-baseimage"
V12IMAGE="af-crm-v12.0"
DEPLOY_LOG_FILE="_deploy_history.log"
DELIMITER="===================================================="

#---------------------------------------------
# Looping through flags - used input arguments
#---------------------------------------------

if [ $# -eq 0 ]; then
	echo ""
	echo -e "\e[96mMissing argument!\nAt least one argument is required.\e[0m"
	sleep 3
	usage
    	exit
fi

while [ "$1" ]
do
	case $1 in
		--branch) ## Mandatory! Branch name, such as the feature branch name ##
			BRANCH="$2"
			VERSION="${BRANCH}-${USER}"
			shift 1
			;;
		-i | --install) ## Install Kubernetes and Docker... ##
			INSTALL="$2"
			shift 1
			;;
		-b | --build) ## Docker Build, tag and push to registry ##
	        BUILD="$2"
			shift 1
	        ;;
	    -d | --deploy) ## Deploy Odoo and Postgres DB... ##
	        DEPLOY="$2"
			shift 1
	        ;;
	    -s | --status) ## Status ##
	        STATUS="TRUE"   
	        ;;
		 -ns | --namespace) ## NAMESPACE MAINLY FOR STATUS, SINCE DEPLOY IS SET AUTOMATICALLY##
	        NAMESPACE="$2"
		shift 1
	        ;;
		-dn | --deletenamespace) ## DELETE NAMESPACE ##
	        NAMESPACE_DELETE="$2"
		shift 1
	        ;;
		--debug) ## Debug ##
	        DEBUG="TRUE"   
	        ;;
		#--delete) ## Delete (installation or pod (=POD/deployments and images)) ##
	        #DELETE="$2" 
			#shift 1
	        #;;
	    -h | --help) ## Help ##
		usage
	        exit           
	        ;;
	    *) ## Help ##
			echo -e '\E[96m\nThe specified argument is invalid:\n'$1'\E[00;00m        '	
			echo	
			sleep 2	
	        usage  
	        exit           
	        ;;
	esac
	shift 1
done


#-------------------
# Actions to take - functions to call related to used flags
#-------------------

basic_setup

# --branch is mandatory for build and deploy
if [ -z "$BRANCH" ] && ([ -n "$BUILD" ] || [ -n "$DEPLOY" ]); then
	echo	
	echo -e "\e[31m'--branch <branch>' is missing. It is mandatory for build and deploy!\e[0m"
	sleep 1	
	usage  
fi


if [[ "$INSTALL" == "all" ]]; then
	install_all
fi

if [[ "$BUILD" == "all" ]]; then
	build_all
fi

if [[ "$DEPLOY" == "all" ]]; then
	deploy_all
fi

if [[ "$STATUS" == "TRUE" ]]; then
	installation_status
	pod_status
fi

if [[ -n "$NAMESPACE_DELETE" ]]; then
	delete_namespace
fi

#if [[ "$DELETE" == "installation" ]]; then
#	installation_delete
#fi


exit $RETVAl
