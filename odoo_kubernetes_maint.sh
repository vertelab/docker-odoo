#!/bin/bash
#
# Vertel Kubernetes AF CRM Operation & Deployment script
#

###################
#    FUNCTIONS   #
###################


#---------------------------
# BASIC SETUP
#---------------------------
basic_setup () {
	echo ""
	sudo mkdir -pm777 $GIT_DIR
	clone_docker_odoo_repo
	clone_docker_helm_repo
	echo -e "\e[96mGeneral server info...\e[0m"
	echo "Free / Disk Space: $(df -m $PWD | awk '/[0-9]%/{print $(NF-2)}') MB"
	echo "Free Memory: $(awk '/MemFree/ { printf "%.3f \n", $2/1024/1024 }' /proc/meminfo)GB"
}


#---------------------------
# INSTALL ALL
#---------------------------
install_all () {

	echo ""
	echo -e "\e[96mINSTALLING KUBERNETES...\e[0m"
	sudo snap install microk8s --classic
	sudo usermod -a -G microk8s $USER
	sudo chown -f -R $USER ~/.kube
	#su - $USER
	microk8s kubectl get nodes
	sudo snap alias microk8s.kubectl kubectl
	microk8s.kubectl config view --raw > $HOME/.kube/config
	
	sudo microk8s enable registry
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
	#su - ${USER}
}


#-------------------------------
# BUILDING, TAGGING and PUSHING
#-------------------------------
build_all () {
	
	echo ""
	echo -e "\e[96mBUILDING IMAGES...\e[0m"
	echo ""
	read -t 5 -p "Building baseimage? N/Y [N - timesout in 5 s]: " buildbaseimage 
	buildbaseimage=${buildbaseimage:-N}
	if [[ "$buildbaseimage" == "Y" ]]; then
		echo -e "\e[95mNow building baseimage...\e[0m\n"
		cd $GIT_DIR/$ODOO_REPO/baseimage
		# ToDo - Only build if it doesn't exist...
		if [ -z "$NOCACHE" ]; then
			sudo docker build . -t "${REGISTRY_URL}/${BASEIMAGE}:latest"
		else
			echo "Building with --no-cache and --pull..."
			sudo docker build . --pull --no-cache -t "${REGISTRY_URL}/${BASEIMAGE}:latest"
		fi
		BASEIMAGE_ID=$(sudo docker images -q "${REGISTRY_URL}/${BASEIMAGE}:latest")
		sudo docker tag $BASEIMAGE_ID "${REGISTRY_URL}/${BASEIMAGE}:latest"
		sudo docker push "${REGISTRY_URL}/${BASEIMAGE}"
		echo -e "\n\e[95mBaseimage ${BASEIMAGE} with image ID $BASEIMAGE_ID pushed to ${REGISTRY_URL}\e[0m"
		cd - > /dev/null
		echo ""
	fi
	echo -e "\e[95mNow building v12.0 image...\e[0m\n"
	sleep 2
	cd $GIT_DIR/$ODOO_REPO/v12.0
	if [ -z "$NOCACHE" ]; then
		sudo docker build . -t "${REGISTRY_URL}/${V12IMAGE}:${VERSION}" --build-arg featurebranch=${BRANCH}
	else
		echo "Building with --no-cache..."
		sudo docker build . --no-cache -t "${REGISTRY_URL}/${V12IMAGE}:${VERSION}" --build-arg featurebranch=${BRANCH}
	fi
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

	cd $GIT_DIR/$ODOO_HELM_REPO/db-deployment
  	kubectl apply -f postgres-config.yaml -n $NAMESPACE
  	kubectl apply -f postgres-service.yaml -n $NAMESPACE
  	kubectl apply -f postgres-deployment.yaml -n $NAMESPACE

	cd - > /dev/null

	cd $GIT_DIR/$ODOO_HELM_REPO/charts
	if [ -z "$DEBUG" ]; then
		helm upgrade --install "v12-${BRANCH}-${USER}" ./odoo-helm --set fullnameOverride="v12-${BRANCH}-${USER}" --set image.repository="${REGISTRY_URL}/${V12IMAGE}" --set image.tag=${VERSION} --namespace ${NAMESPACE} | grep -ve 'NOTES:' -e 'export' -e 'echo' -e 'Get the application URL' | tee -a $TEMP_DEPLOY_LOG_FILE
	else	
		helm upgrade --install "v12-${BRANCH}-${USER}" ./odoo-helm --set fullnameOverride="v12-${BRANCH}-${USER}" --set image.repository="${REGISTRY_URL}/${V12IMAGE}" --set image.tag=${VERSION} --namespace ${NAMESPACE} | tee -a $TEMP_DEPLOY_LOG_FILE
	fi
	cd - > /dev/null
	export NODE_PORT=$(kubectl get --namespace $NAMESPACE -o jsonpath="{.spec.ports[0].nodePort}" services "v12-${BRANCH}-${USER}")
	export NODE_IP=$(kubectl get nodes --namespace $NAMESPACE -o jsonpath="{.items[0].status.addresses[0].address}")
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
# CLONE GITHUB docker-odoo REPO
#-------------------------------
clone_docker_odoo_repo () {

	echo -e "\e[96mCloning GitHub repo $ODOO_REPO...\e[0m"
	cd $GIT_DIR
	if [ ! -d "$ODOO_REPO" ]; then
		git clone --branch main https://github.com/vertelab/docker-odoo.git
	else
		cd $ODOO_REPO
		git pull
		cd - > /dev/null
	fi
	cd ~
	echo ""
}


#-------------------------------
# CLONE GITHUB docker-helm REPO
#-------------------------------
clone_docker_helm_repo () {

	echo -e "\e[96mCloning GitHub repo $ODOO_HELM_REPO...\e[0m"
	cd $GIT_DIR
	if [ ! -d "$ODOO_HELM_REPO" ]; then
		git clone --branch main https://github.com/vertelab/docker-helm.git
	else
		cd $ODOO_HELM_REPO
		git pull
		cd - > /dev/null
	fi
	cd ~
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
	echo -e "\e[96mPODs Status in namespaces...\e[0m"
	if [ -n "$DEBUG" ]; then
		echo -e "\e[96mList PODs in all namespaces when debug is used...\e[0m"
		kubectl get pod --all-namespaces
	else	
		kubectl get pods --show-labels | grep -e '$BRANCH' -e '$NAMESPACE'
	fi
	echo ""
	echo -e "\e[96mList Deployments...\e[0m"
	if [ -z "$NAMESPACE" ]; then echo "(Note! Use -ns <namespace> to limit this output)"; fi
	kubectl get deployments --all-namespaces | grep -e 'NAMESPACE' -e "$NAMESPACE"
	echo ""
	echo -e "\e[96mServices... (External Access)\e[0m"
	kubectl get services | grep -e CLUSTER-IP -e '$BRANCH'
	if [ -n "$DEBUG" ]; then
		echo -e "\e[96mDetailed POD status when debug is used...\e[0m"
		kubectl describe pods --all-namespaces
	fi
	echo ""
	echo -e "\e[96mNamespaces...\e[0m"
	if [ -z "$NAMESPACE" ]; then echo "(Note! Use -ns <namespace> to limit this output)"; fi
	kubectl get namespace | grep -e 'NAME' -e "$NAMESPACE"
	echo ""
	echo -e "\e[96mImages...\e[0m"
	if [ -n "$DEBUG" ]; then
		docker images | grep -e 'REPOSITORY' -e "$BRANCH"
	elif [ -n "$BRANCH" ]; then
		echo "(Remove '--branch <branch>' to print all images for user $USER)"
		docker images | grep -e 'REPOSITORY' -e "$USER" | grep "$BRANCH"
	else
		echo "(Use '--debug' to list all images)"
		echo "(Use '--branch <branch>' to limit output to a Tag from a specific branch)"
		docker images | grep -e 'REPOSITORY' -e "$USER"
		docker images | grep -e 'baseimage'
	fi
	echo ""
	echo -e "\n\e[95mFind your POD_NAME: kubectl get pods --namespace $NAMESPACE\e[0m"  | tee -a $TEMP_DEPLOY_LOG_FILE
	echo -e "\n\e[95mEdit POD_NAME and port-forward: kubectl --namespace $NAMESPACE port-forward POD_NAME :8069\e[0m"  | tee -a $TEMP_DEPLOY_LOG_FILE
	echo -e "\n\e[95mSave the random port after port-forward\e[0m" | tee -a $TEMP_DEPLOY_LOG_FILE
	echo -e "\n\e[95mSetup putty in you local machine\e[0m" | tee -a $TEMP_DEPLOY_LOG_FILE
	echo -e "\n\e[95mURL to the CRM application: http://127.0.0.1:random_port\e[0m" | tee -a $TEMP_DEPLOY_LOG_FILE
	echo ""
}


#---------------------------
# DELETE NAMESPACE
#---------------------------
delete_namespace () {

	echo ""
	echo -e "\e[96mDeleting Namespace...\e[0m"
	for ns_delete in $(echo $NAMESPACE_DELETE | sed "s/,/ /g")
	do
		kubectl get namespace "$ns_delete"
		kubectl delete namespace "$ns_delete"
	done
	echo ""
}


#---------------------------
# DELETE IMAGE
#---------------------------
delete_image () {

	echo ""
	echo -e "\e[96mDeleting Image...\e[0m"
	for im_delete in $(echo $IMAGE_DELETE | sed "s/,/ /g")
	do
		docker rmi "$im_delete"
	done
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
	echo "  --branch <branch name>	Branch name in GitHub. Mandatory for build and deploy."
	echo "  -i all			Installation of Kubernetes, Docker and basic setup."
	echo "  -b all			Building, tagging and pushing images."
	echo "  -d all			Deploy POD."
	echo "  -s				Complete AF CRM Status information for user $USER."
	echo "  -ns <namespace>		Namespace. Only used together with status."
	echo "  -dn <namespaces>		Delete Namespace/s. Comma separated without spaces."
	echo "  -di <images>			Delete image/s. Comma separated without spaces."
	echo "  -nc				Do not use cache in Docker build and pull baseimage."
	echo "  --debug			Debug mode. Additional information for status command."
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
GIT_DIR="git_repos"
#GIT_DIR="../git_common_repos"
ODOO_REPO="docker-odoo"
ODOO_HELM_REPO="docker-helm"
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
			if [ -z "$INSTALL" ]; then echo -e "\e[31mMissing '-i all'!\e[0m"; fi
			shift 1
			;;
		-b | --build) ## Docker Build, tag and push to registry ##
	        BUILD="$2"
		if [ -z "$BUILD" ]; then echo -e "\e[31mMissing '-b all'!\e[0m"; fi
			shift 1
	        ;;
	    -d | --deploy) ## Deploy Odoo and Postgres DB... ##
	        DEPLOY="$2"
		if [ -z "$DEPLOY" ]; then echo -e "\e[31mMissing '-d all'!\e[0m"; fi
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
		-di | --deleteimage) ## DELETE IMAGE ##
	        IMAGE_DELETE="$2"
		shift 1
	        ;;
		-nc | --nocache) ## DO NOT USE CACHE DURING BUILD AND PULL BASEIMAGE ##
	        NOCACHE="true"
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


# --branch is mandatory for build and deploy
if [ -z "$BRANCH" ] && ([ -n "$BUILD" ] || [ -n "$DEPLOY" ]); then
	echo	
	echo -e "\e[31m'--branch <branch>' is missing. It is mandatory for build and deploy!\e[0m"
	sleep 1	
	usage  
fi


if [[ "$INSTALL" == "all" ]]; then
	basic_setup
	install_all
fi

if [[ "$BUILD" == "all" ]]; then
	basic_setup
	build_all
fi

if [[ "$DEPLOY" == "all" ]]; then
	basic_setup
	deploy_all
fi

if [[ "$STATUS" == "TRUE" ]]; then
	basic_setup
	installation_status
	pod_status
fi

if [[ -n "$NAMESPACE_DELETE" ]]; then
	delete_namespace
fi

if [[ -n "$IMAGE_DELETE" ]]; then
	delete_image
fi

#if [[ "$DELETE" == "installation" ]]; then
#	installation_delete
#fi


exit $RETVAl
