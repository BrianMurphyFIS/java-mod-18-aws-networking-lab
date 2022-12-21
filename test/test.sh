#!/bin/bash


#########
# Setup #
#########

cd /test

# Patch the Inspec Azure Profile to work around some unimplemented features
sed -i 's/unless @resource_long_desc.is_a?(Hash) \&\& @resource_long_desc.key?(:id)/unless @resource_long_desc.is_a?(Hash) \&\& ( @resource_long_desc.key?(:id) || @opts[:ignore_error]  )/' /deps/inspec-azure/libraries/azure_generic_resource.rb
sed -i 's/validate_parameters(required: %i(resource_id), allow: %i(transform_keys))/validate_parameters(required: %i(resource_id), allow: %i(transform_keys ignore_error))/' /deps/inspec-azure/libraries/azure_generic_resource.rb

# Load all ssh keys
eval "$(ssh-agent -s)"
for i in $(find ./secrets -maxdepth 1 -name '*.pem')
do
	ssh-add $i
done

# Setting up local ssh proxy, as Ruby Docker-API client doesn't natively support Docker SSH protocol yet
echo "ControlMaster auto" >> /etc/ssh/ssh_config
echo "ControlPath /var/run/ssh_socket" >> /etc/ssh/ssh_config
echo "StreamLocalBindUnlink yes" >> /etc/ssh/ssh_config

# Load any self-signed certificates
for i in $(find ./secrets -maxdepth 1 -name '*.crt')
do
	cat $i >> /etc/ssl/certs/ca-certificates.crt
done


######################
# Test AWS resources #
######################

# Run each AWS Inspec profile
for i in $(find ./profiles -maxdepth 1 -name 'aws-*' -type d | grep -v aws-vm-inventory | cut -d'/' -f3-)
do
	inspec exec /test/profiles/$i -t aws:// --filter-empty-profiles --reporter json:/$i-json cli:/$i-cli progress-bar # 2>/dev/null
	sync
	cat /$i-json >> /out-json
done

# Run AWS VM Inventory profile to retrieve VM IP addresses
if [ -d ./profiles/aws-vm-inventory ]
then
	inspec exec /test/profiles/aws-vm-inventory -t aws:// --filter-empty-profiles --reporter json:/aws-vm-inventory-json cli:/aws-vm-inventory-cli progress-bar 2>/dev/null
	sync
	cat /aws-vm-inventory-json | jq '.profiles[] | select(.name=="aws-vm-inventory") | .controls[] | select(.id=="AWS VM Inventory") | .results[] | select(.status=="failed") | .message' | tr '"' ' ' | awk '{print $7}' | tr -d '\\' | awk '{print $1}' | paste -d ' ' - - - >> /aws-vm-ips
fi

# Run Inspec tests for AWS VMs
for i in $(find ./profiles -maxdepth 1 -name 'vm-*' -type d | cut -d'/' -f3- | cut -d'-' -f2-)
do
	VM_NAME=$i
	VM_IP=$(grep "^$VM_NAME " /aws-vm-ips 2> /dev/null | awk '{print $2}')
	if [ "x$VM_IP" != "x" ]
	then
		inspec exec /test/profiles/vm-$VM_NAME -t ssh://ubuntu@$VM_IP --filter-empty-profiles --reporter json:/$VM_NAME-json cli:/$VM_NAME-cli progress-bar # 2>/dev/null
		sync
		cat /$VM_NAME-json >> /out-json
	fi
done
# AWS Private VMs via jump host
for i in $(find ./profiles -maxdepth 1 -name 'jump-vm-*' -type d | cut -d'/' -f3- | cut -d'-' -f3-)
do
	VM_NAME=$i
	VM_IP=$(grep "^$VM_NAME " /aws-vm-ips 2> /dev/null | awk '{print $3}')
	if [ "x$VM_IP" != "x" ]
	then
		JUMP_HOST=$(cat /aws-vm-ips | grep -v " using " | head -n1 | awk '{print $2}')
		inspec exec /test/profiles/jump-vm-$VM_NAME -t ssh://ubuntu@$VM_IP --bastion-host=$JUMP_HOST --bastion-port=22 --bastion-user=ubuntu --filter-empty-profiles --reporter json:/$VM_NAME-json cli:/$VM_NAME-cli progress-bar # 2>/dev/null
		sync
		cat /$VM_NAME-json >> /out-json
	fi
done

# Run Inspec tests for Remote Docker Containers
for i in $(find ./profiles -maxdepth 1 -name 'remote-docker-*' -type d | cut -d'/' -f3-)
do
	VM_NAME="echo $i | cut -d'_' -f1"
	VM_IP=$(grep "^$VM_NAME " /aws-vm-ips 2> /dev/null | awk '{print $2}')
	CONTAINER_NAME="echo $i | cut -d'_' -f2"
	if [ "x$VM_IP" != "x" ]
	then
		# ssh proxy setup
		ssh -o "StrictHostKeyChecking=no" -fNTM -L/var/run/docker-$VM_NAME.sock:/var/run/docker.sock ssh://ubuntu@$VM_IP	

		DOCKER_HOST=unix:/var/run/docker-$VM_NAME.sock inspec exec /test/profiles/$i -t docker://$CONTAINER_NAME --filter-empty-profiles --reporter json:/$i-json cli:/$i-cli progress-bar # 2>/dev/null
		sync
		cat /$i-json >> /out-json

		# ssh proxy cleanup
		ssh -O "exit" $VM_IP

	fi
done


######################
# Test GCP resources #
######################

# Set correct credential path from file name input
GOOGLE_APPLICATION_CREDENTIALS="/test/secrets/$GOOGLE_APPLICATION_CREDENTIALS"

# Run each GCP Inspec profile
for i in $(find ./profiles -maxdepth 1 -name 'gcp-*' -type d | grep -v gcp-vm-inventory | cut -d'/' -f3-)
do
	inspec exec /test/profiles/$i -t gcp:// --filter-empty-profiles --reporter json:/$i-json cli:/$i-cli progress-bar # 2>/dev/null
	sync
	cat /$i-json >> /out-json
done

# Run GCP VM Inventory profile to retrieve VM IP addresses
if [ -d ./profiles/gcp-vm-inventory ]
then
	inspec exec /test/profiles/gcp-vm-inventory -t gcp:// --filter-empty-profiles --reporter json:/gcp-vm-inventory-json cli:/gcp-vm-inventory-cli progress-bar 2>/dev/null
	sync
	cat /gcp-vm-inventory-json | jq '.profiles[] | select(.name=="gcp-vm-inventory") | .controls[] | select(.id=="GCP VM Inventory") | .results[] | select(.status=="failed") | .message' | tr '"' ' ' | awk '{print $7}' | tr -d '\\' | awk '{print $1}' | paste -d ' ' - - >> /gcp-vm-ips
fi

# Run Inspec tests for GCP VMs
for i in $(find ./profiles -maxdepth 1 -name 'vm-*' -type d | cut -d'/' -f3- | cut -d'-' -f2-)
do
	VM_NAME=$i
	VM_IP=$(grep "^$VM_NAME " /gcp-vm-ips 2> /dev/null | awk '{print $2}')
	if [ "x$VM_IP" != "x" ]
	then
		inspec exec /test/profiles/vm-$VM_NAME -t ssh://ubuntu@$VM_IP --filter-empty-profiles --reporter json:/$VM_NAME-json cli:/$VM_NAME-cli progress-bar # 2>/dev/null
		sync
		cat /$VM_NAME-json >> /out-json
	fi
done

# Run Inspec tests for Remote Docker Containers
for i in $(find ./profiles -maxdepth 1 -name 'remote-docker-*' -type d | cut -d'/' -f3-)
do
	VM_NAME="echo $i | cut -d'_' -f1"
	VM_IP=$(grep "^$VM_NAME " /gcp-vm-ips 2> /dev/null | awk '{print $2}')
	CONTAINER_NAME="echo $i | cut -d'_' -f2"
	if [ "x$VM_IP" != "x" ]
	then
		# ssh proxy setup
		ssh -o "StrictHostKeyChecking=no" -fNTM -L/var/run/docker-$VM_NAME.sock:/var/run/docker.sock ssh://ubuntu@$VM_IP	

		DOCKER_HOST=unix:/var/run/docker-$VM_NAME.sock inspec exec /test/profiles/$i -t docker://$CONTAINER_NAME --filter-empty-profiles --reporter json:/$i-json cli:/$i-cli progress-bar # 2>/dev/null
		sync
		cat /$i-json >> /out-json

		# ssh proxy cleanup
		ssh -O "exit" $VM_IP

	fi
done


########################
# Test Azure resources #
########################

# Run each Azure Inspec profile
for i in $(find ./profiles -maxdepth 1 -name 'azure-*' -type d | grep -v azure-vm-inventory | cut -d'/' -f3-)
do
	inspec exec /test/profiles/$i -t azure:// --filter-empty-profiles --reporter json:/$i-json cli:/$i-cli progress-bar # 2>/dev/null
	sync
	cat /$i-json >> /out-json
done

# Run Azure VM Inventory profile to retrieve VM IP addresses
if [ -d ./profiles/azure-vm-inventory ]
then
	inspec exec /test/profiles/azure-vm-inventory -t azure:// --filter-empty-profiles --reporter json:/azure-vm-inventory-json cli:/azure-vm-inventory-cli progress-bar 2>/dev/null
	sync
	cat /azure-vm-inventory-json | jq '.profiles[] | select(.name=="azure-vm-inventory") | .controls[] | select(.id=="Azure VM Inventory") | .results[] | select(.status=="failed") | .message' | tr '"' ' ' | awk '{print $7}' | tr -d '\\' | awk '{print $1}' | paste -d ' ' - - >> /azure-vm-ips
fi

# Run Inspec tests for Azure VMs
for i in $(find ./profiles -maxdepth 1 -name 'vm-*' -type d | cut -d'/' -f3- | cut -d'-' -f2-)
do
	VM_NAME=$i
	VM_IP=$(grep "^$VM_NAME " /azure-vm-ips 2> /dev/null | awk '{print $2}')
	if [ "x$VM_IP" != "x" ]
	then
		inspec exec /test/profiles/vm-$VM_NAME -t ssh://azureuser@$VM_IP --filter-empty-profiles --reporter json:/$VM_NAME-json cli:/$VM_NAME-cli progress-bar # 2>/dev/null
		sync
		cat /$VM_NAME-json >> /out-json
	fi
done

# Run Inspec tests for Remote Docker Containers
for i in $(find ./profiles -maxdepth 1 -name 'remote-docker-*' -type d | cut -d'/' -f3-)
do
	VM_NAME="echo $i | cut -d'_' -f1"
	VM_IP=$(grep "^$VM_NAME " /azure-vm-ips 2> /dev/null | awk '{print $2}')
	CONTAINER_NAME="echo $i | cut -d'_' -f2"
	if [ "x$VM_IP" != "x" ]
	then
		# ssh proxy setup
		ssh -o "StrictHostKeyChecking=no" -fNTM -L/var/run/docker-$VM_NAME.sock:/var/run/docker.sock ssh://azureuser@$VM_IP	

		DOCKER_HOST=unix:/var/run/docker-$VM_NAME.sock inspec exec /test/profiles/$i -t docker://$CONTAINER_NAME --filter-empty-profiles --reporter json:/$i-json cli:/$i-cli progress-bar # 2>/dev/null
		sync
		cat /$i-json >> /out-json

		# ssh proxy cleanup
		ssh -O "exit" $VM_IP

	fi
done


#############################
# Test Kubernetes resources #
#############################

# Set correct credential path from file name input
KUBECONFIG="/test/secrets/$KUBECONFIG"

for i in $(find ./profiles -maxdepth 1 -name 'k8s-*' -type d | cut -d'/' -f3-)
do
        inspec exec /test/profiles/$i -t k8s:// --filter-empty-profiles --reporter json:/$i-json cli:/$i-cli progress-bar # 2>/dev/null
	sync
	cat /$i-json >> /out-json
done


###############################
# Test Local Docker resources #
###############################

# Run tests against local Docker Daemon
if [ -d ./profiles/local-docker-environment ]
then
	inspec exec /test/profiles/local-docker-environment --filter-empty-profiles --reporter json:/local-docker-environment-json cli:/local-docker-environment-cli progress-bar # 2>/dev/null
	sync
	cat /local-docker-environment-json >> /out-json
fi

# Run tests inside local Docker Containers
for i in $(find ./profiles -maxdepth 1 -name 'local-docker-*' -type d | grep -v local-docker-environment | cut -d'/' -f3-)
do
	CONTAINER_NAME="echo $i | cut -d'_' -f2"
	inspec exec /test/profiles/$i -t docker://$CONTAINER_NAME --filter-empty-profiles --reporter json:/$i-json cli:/$i-cli progress-bar # 2>/dev/null
	sync
	cat /$i-json >> /out-json
done







################
# Parse output #
################

green=$(tput setaf 2)
blue=$(tput setaf 4)
red=$(tput setaf 1)
white=$(tput setaf 7)
yellow=$(tput setaf 3)
cyan=$(tput setaf 6)
normal=$(tput sgr0)

COMPLETED_PROFILES=0
FAILED_PROFILES=0
OPTIONAL_PROFILES_REMAINING=0
COMPLETED_GROUPS=0
FAILED_GROUPS=0
OPTIONAL_GROUPS_REMAINING=0
COMPLETED_CONTROLS=0
FAILED_CONTROLS=0
OPTIONAL_CONTROLS_REMAINING=0
COMPLETED_TESTS=0
FAILED_TESTS=0
OPTIONAL_TESTS_REMAINING=0
ANY_OPTIONAL=false

IFS=$'\n'

# loop through each profile
for i in $(cat /out-json | jq -r '.profiles[].name')
do
	# loop through each group
	for j in $(cat /out-json | jq -r ".profiles[] | select(.name==\"$i\") | .groups[].title")
	do
		# loop through each control
		for k in $(cat /out-json | jq -r ".profiles[] | select(.name==\"$i\") | .groups[] | select(.title==\"$j\") | .controls[]")
		do
			STEP=$(cat /out-json | jq -r ".profiles[] | select(.name==\"$i\") | .controls[] | select(.id==\"$k\") | .descriptions[] | select(.label==\"step\") | .data")
			OPTIONAL=$(cat /out-json | jq -r ".profiles[] | select(.name==\"$i\") | .controls[] | select(.id==\"$k\") | .descriptions[] | select(.label==\"optional\") | .data")
			
			# loop through each test
			for l in $(cat /out-json | jq -r ".profiles[] | select(.name==\"$i\") | .controls[] | select(.id==\"$k\") | .results | to_entries[] | .key")
			do
				
				# handle output for each test
				STATUS=$(cat /out-json | jq -r ".profiles[] | select(.name==\"$i\") | .controls[] | select(.id==\"$k\") | .results | to_entries[] | select(.key==$l) | .value.status")
				MESSAGE=$(cat /out-json | jq -r ".profiles[] | select(.name==\"$i\") | .controls[] | select(.id==\"$k\") | .results | to_entries[] | select(.key==$l) | .value.code_desc")
				ALL_TESTS_PASSED="true"
				ALL_OPTIONAL_TESTS_PASSED="true"
				ALL_TESTS_FAILED="true"
				ALL_OPTIONAL_TESTS_FAILED="true"

				if [ "$STATUS" = "passed" ]
				then
					if [ "$OPTIONAL" = "true" ]
					then
						printf "%40s%s\n" "" "${blue} ✔ $MESSAGE (optional)${normal}" >> /out-text
						echo "$STEP $STATUS ${blue} $i / $j /$k / $MESSAGE${normal}" >> /out-text-help
						ALL_OPTIONAL_TESTS_FAILED="false"
						ANY_OPTIONAL=true
					else
						printf "%40s%s\n" "" "${green} ✔ $MESSAGE${normal}" >> /out-text
						echo "$STEP $STATUS ${green} $i / $j / $k / $MESSAGE${normal}" >> /out-text-help
						ALL_TESTS_FAILED="false"
						COMPLETED_TESTS=$(($COMPLETED_TESTS + 1))
					fi
				else
					if [ "$OPTIONAL" = "true" ]
					then
						printf "%40s%s\n" "" "${white} × $MESSAGE (optional)${normal}" >> /out-text
						echo "$STEP passed ${white} $i / $j / $k / $MESSAGE${normal}" >> /out-text-help
						ALL_OPTIONAL_TESTS_PASSED="false"
						OPTIONAL_TESTS_REMAINING=$(($OPTIONAL_TESTS_REMAINING + 1))
						ANY_OPTIONAL=true
					else
						printf "%40s%s\n" "" "${red} × $MESSAGE${normal}" >> /out-text
						echo "$STEP $STATUS ${red} $i / $j / $k / $MESSAGE${normal}" >> /out-text-help
						ALL_TESTS_PASSED="false"
						FAILED_TESTS=$(($FAILED_TESTS + 1))
					fi
				fi
			done

			# handle output for each control. Essentially just a parent containing the specific tests.
			ALL_CONTROLS_PASSED="true"
			ALL_OPTIONAL_CONTROLS_PASSED="true"
			ALL_CONTROLS_FAILED="true"
			ALL_OPTIONAL_CONTROLS_FAILED="true"
			if [ "$OPTIONAL" = "true" ]
			then
				if [ "$ALL_OPTIONAL_TESTS_PASSED" = "true" ]
				then
					printf "%30s%s\n" "" "${blue} ✔ $k (optional)${normal}" >> /out-text
					ALL_OPTIONAL_CONTROLS_FAILED="false"
				elif [ "$ALL_OPTIONAL_TESTS_FAILED" = "true" ]
				then
					printf "%30s%s\n" "" "${white} × $k (optional)${normal}" >> /out-text
					ALL_OPTIONAL_CONTROLS_PASSED="false"
					OPTIONAL_CONTROLS_REMAINING=$(($OPTIONAL_CONTROLS_REMAINING + 1))
				else
					printf "%30s%s\n" "" "${cyan} - $k (optional)${normal}" >> /out-text
					ALL_OPTIONAL_CONTROLS_FAILED="false"
					ALL_OPTIONAL_CONTROLS_PASSED="false"
					OPTIONAL_CONTROLS_REMAINING=$(($OPTIONAL_CONTROLS_REMAINING + 1))
				fi
			else
				if [ "$ALL_TESTS_PASSED" = "true" ]
				then
					printf "%30s%s\n" "" "${green} ✔ $k${normal}" >> /out-text
					ALL_CONTROLS_FAILED="false"
					COMPLETED_CONTROLS=$(($COMPLETED_CONTROLS + 1))
				elif [ "$ALL_TESTS_FAILED" = "true" ]
				then
					printf "%30s%s\n" "" "${red} × $k${normal}" >> /out-text
					ALL_CONTROLS_PASSED="false"
					FAILED_CONTROLS=$(($FAILED_CONTROLS + 1))
				else
					printf "%30s%s\n" "" "${yellow} - $k${normal}" >> /out-text
					ALL_CONTROLS_FAILED="false"
					ALL_CONTROLS_PASSED="false"
					FAILED_CONTROLS=$(($FAILED_CONTROLS + 1))
				fi
			fi
		done

		# handle output for each group. Essentially just a parent containing the specific controls.
		ALL_GROUPS_PASSED="true"
		ALL_OPTIONAL_GROUPS_PASSED="true"
		ALL_GROUPS_FAILED="true"
		ALL_OPTIONAL_GROUPS_FAILED="true"
		if [ "$ALL_CONTROLS_FAILED" = "true" ] && [ "$ALL_CONTROLS_PASSED" = "true" ] # if all children are optional
		then
			if [ "$ALL_OPTIONAL_CONTROLS_PASSED" = "true" ]
			then
				printf "%20s%s\n" "" "${blue} ✔ $j${normal}" >> /out-text
				ALL_OPTIONAL_GROUPS_FAILED="false"
			elif [ "$ALL_OPTIONAL_CONTROLS_FAILED" = "true" ]
			then
				printf "%20s%s\n" "" "${white} × $j${normal}" >> /out-text
				ALL_OPTIONAL_GROUPS_PASSED="false"
				OPTIONAL_GROUPS_REMAINING=$(($OPTIONAL_GROUPS_REMAINING + 1))
			else
				printf "%20s%s\n" "" "${cyan} - $j${normal}" >> /out-text
				ALL_OPTIONAL_GROUPS_FAILED="false"
				ALL_OPTIONAL_GROUPS_PASSED="false"
				OPTIONAL_GROUPS_REMAINING=$(($OPTIONAL_GROUPS_REMAINING + 1))
			fi
		else
			if [ "$ALL_CONTROLS_PASSED" = "true" ]
			then
				printf "%20s%s\n" "" "${green} ✔ $j${normal}" >> /out-text
				ALL_GROUPS_FAILED="false"
				COMPLETED_GROUPS=$(($COMPLETED_GROUPS + 1))
			elif [ "$ALL_CONTROLS_FAILED" = "true" ]
			then
				printf "%20s%s\n" "" "${red} × $j${normal}" >> /out-text
				ALL_GROUPS_PASSED="false"
				FAILED_GROUPS=$(($FAILED_GROUPS + 1))
			else
				printf "%20s%s\n" "" "${yellow} - $j${normal}" >> /out-text
				ALL_GROUPS_FAILED="false"
				ALL_GROUPS_PASSED="false"
				FAILED_GROUPS=$(($FAILED_GROUPS + 1))
			fi
		fi
	done

	# handle output for each profile. Essentially just a parent containing the specific groups.
	ALL_PROFILES_PASSED="true"
	ALL_OPTIONAL_PROFILES_PASSED="true"
	ALL_PROFILES_FAILED="true"
	ALL_OPTIONAL_PROFILES_FAILED="true"
	if [ "$ALL_GROUPS_FAILED" = "true" ] && [ "$ALL_GROUPS_PASSED" = "true" ] # if all children are optional
	then
		if [ "$ALL_OPTIONAL_GROUPS_PASSED" = "true" ]
		then
			printf "%10s%s\n\n" "" "${blue} ✔ $i${normal}" >> /out-text
			ALL_OPTIONAL_PROFILES_FAILED="false"
		elif [ "$ALL_OPTIONAL_GROUPS_FAILED" = "true" ]
		then
			printf "%10s%s\n\n" "" "${white} × $i${normal}" >> /out-text
			ALL_OPTIONAL_PROFILES_PASSED="false"
			OPTIONAL_PROFILES_REMAINING=$(($OPTIONAL_PROFILES_REMAINING + 1))
		else
			printf "%10s%s\n\n" "" "${cyan} - $i${normal}" >> /out-text
			ALL_OPTIONAL_PROFILES_FAILED="false"
			ALL_OPTIONAL_PROFILES_PASSED="false"
			OPTIONAL_PROFILES_REMAINING=$(($OPTIONAL_PROFILES_REMAINING + 1))
		fi
	else
		if [ "$ALL_GROUPS_PASSED" = "true" ]
		then
			printf "%10s%s\n\n" "" "${green} ✔ $i${normal}" >> /out-text
			ALL_PROFILES_FAILED="false"
			COMPLETED_PROFILES=$(($COMPLETED_PROFILES + 1))
		elif [ "$ALL_GROUPS_FAILED" = "true" ]
		then
			printf "%10s%s\n\n" "" "${red} × $i${normal}" >> /out-text
			ALL_PROFILES_PASSED="false"
			FAILED_PROFILES=$(($FAILED_PROFILES + 1))
		else
			printf "%10s%s\n\n" "" "${yellow} - $i${normal}" >> /out-text
			ALL_PROFILES_FAILED="false"
			ALL_PROFILES_PASSED="false"
			FAILED_PROFILES=$(($FAILED_PROFILES + 1))
		fi
	fi
done

sync
tac /out-text

# print summarized testing information
printf "\n%5s%s\n" "" "${green}$COMPLETED_PROFILES successful profiles${normal}, ${red}$FAILED_PROFILES failed profiles${normal}, ${white}$OPTIONAL_PROFILES_REMAINING optional profiles remaining${normal}"
printf "%5s%s\n" "" "${green}$COMPLETED_GROUPS successful groups${normal}, ${red}$FAILED_GROUPS failed groups${normal}, ${white}$OPTIONAL_GROUPS_REMAINING optional groups remaining${normal}"
printf "%5s%s\n" "" "${green}$COMPLETED_CONTROLS successful controls${normal}, ${red}$FAILED_CONTROLS failed controls${normal}, ${white}$OPTIONAL_CONTROLS_REMAINING optional controls remaining${normal}"
printf "%5s%s\n\n" "" "${green}$COMPLETED_TESTS successful tests${normal}, ${red}$FAILED_TESTS failed tests${normal}, ${white}$OPTIONAL_TESTS_REMAINING optional tests remaining${normal}"

if [ $FAILED_PROFILES -eq 0 ] && [ $FAILED_GROUPS -eq 0 ] && [ $FAILED_CONTROLS -eq 0 ] && [ $FAILED_TESTS -eq 0 ]
then
	if [ $OPTIONAL_PROFILES_REMAINING -eq 0 ] && [ $OPTIONAL_GROUPS_REMAINING -eq 0 ] && [ $OPTIONAL_CONTROLS_REMAINING -eq 0 ] && [ $OPTIONAL_TESTS_REMAINING -eq 0 ] && [ $ANY_OPTIONAL = true ]
	then
		printf "%5s%s\n\n" "" "🎉🎉 💯 🎉🎉"
	else
		printf "%5s%s\n\n" "" "💯"
	fi
fi


################################
# Parse output with extra help #
################################

# Enable additional help output to guide students to the relevant lab sections for errors
if [ "$1" = "--help" ]
then
	FIRST_ERROR=true
	sync
	for i in $(cat /out-text-help | sort -n)
	do
		STEP=$(echo $i | awk '{print $1}')
		STATUS=$(echo $i | awk '{print $2}')
		TEST_INFO=$(echo $i | cut -d' ' -f3-)

		if [ "$STATUS" = "failed" ] && [ $FIRST_ERROR = true ]
		then
			printf "%18s%s\n" "" "➞ Step $STEP: $TEST_INFO"
			FIRST_ERROR=false
		else
			printf "%20s%s\n" "" "Step $STEP: $TEST_INFO"
		fi
	done
fi
