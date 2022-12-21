#!/bin/bash

# Enable needed environments
#ENVIRONMENTS=("AWS" "GCP" "AZURE" "KUBERNETES" "LOCAL" "REMOTE_SSH")
ENVIRONMENTS=("AWS" "REMOTE_SSH")

# Source credentials file. Will prompt for values and save if they are not written to the file.
. ./secrets/.credentials


REQUIRED_ENVS=()
for i in ${ENVIRONMENTS[@]}
do
	case $i in
		AWS)
			REQUIRED_ENVS+=("AWS_ACCESS_KEY_ID" "AWS_SECRET_ACCESS_KEY" "AWS_REGION")
			;;
		GCP)
			REQUIRED_ENVS+=("GOOGLE_APPLICATION_CREDENTIALS")
			;;
		AZURE)
			REQUIRED_ENVS+=("AZURE_CLIENT_ID" "AZURE_CLIENT_SECRET" "AZURE_SUBSCRIPTION_ID" "AZURE_TENANT_ID")
			;;
		KUBERNETES)
			REQUIRED_ENVS+=("KUBECONFIG")
			;;
		LOCAL)
			#
			;;
		REMOTE_SSH)
			#
			;;
		*)
			echo "Environment $i not supported."
			;;
	esac
done


DOCKER_PARAMETERS=""
for i in ${REQUIRED_ENVS[@]}
do
	VALUE=${!i}
	if [ "x$VALUE" = "x" ]
	then
		read -p "$i : " VALUE
		echo "$i=$VALUE" >> ./secrets/.credentials
	fi

	DOCKER_PARAMETERS+="-e $i=$VALUE "
done




if !(docker images | grep "^inspec-test " > /dev/null)
then
	docker build -t inspec-test -f Dockerfile.Inspec .
fi

if [ "x$1" = "x" ]
then
	docker run -it --rm \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v $(pwd):/test \
		$DOCKER_PARAMETERS \
		inspec-test /bin/bash /test/test.sh
elif [ "$1" = "--help" ]
then
	docker run -it --rm \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v $(pwd):/test \
		$DOCKER_PARAMETERS \
		inspec-test /bin/bash /test/test.sh --help
elif [ "$1" = "--debug" ]
then
	docker run -it --rm \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v $(pwd):/test \
		$DOCKER_PARAMETERS \
		inspec-test /bin/bash
else
	echo "Wrong arguments. Script only accepts '--help' or none."
fi
