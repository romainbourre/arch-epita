#!/bin/sh

clear

VM=default
DOCKER_MACHINE=/usr/local/bin/docker-machine
VBOXMANAGE=/Applications/VirtualBox.app/Contents/MacOS/VBoxManage

unset DYLD_LIBRARY_PATH
unset LD_LIBRARY_PATH

#clear all_proxy if not socks address
printf "[CLEAR PROXY]"

if  [[ $ALL_PROXY != socks* ]]; then
	unset ALL_PROXY
fi
if  [[ $all_proxy != socks* ]]; then
	unset all_proxy
fi

printf "...\033[32mOK\033[0m\n"

# Check and connect docker-machine
printf "[CHECK DOCKER MACHINE]"
if [ -f "${DOCKER_MACHINE}" ] && [ -f "${VBOXMANAGE}" ]; then

	"${VBOXMANAGE}" list vms | grep \""${VM}"\" &> /dev/null
	VM_EXISTS_CODE=$?

	if [ $VM_EXISTS_CODE -eq 1 ]; then
		"${DOCKER_MACHINE}" rm -f "${VM}" &> /dev/null
		rm -rf ~/.docker/machine/machines/"${VM}"
		#set proxy variables if they exists
		if [ "${HTTP_PROXY}" ]; then
			PROXY_ENV="$PROXY_ENV --engine-env HTTP_PROXY=$HTTP_PROXY"
		fi
		if [ "${HTTPS_PROXY}" ]; then
			PROXY_ENV="$PROXY_ENV --engine-env HTTPS_PROXY=$HTTPS_PROXY"
		fi
		if [ "${NO_PROXY}" ]; then
			PROXY_ENV="$PROXY_ENV --engine-env NO_PROXY=$NO_PROXY"
		fi
		"${DOCKER_MACHINE}" create -d virtualbox $PROXY_ENV --virtualbox-memory 2048 --virtualbox-disk-size 204800 "${VM}"
	fi

	VM_STATUS="$( set +e ; ${DOCKER_MACHINE} status ${VM} )"
	if [ "${VM_STATUS}" != "Running" ]; then
		"${DOCKER_MACHINE}" start "${VM}"
		yes | "${DOCKER_MACHINE}" regenerate-certs "${VM}"
	fi

	eval "$(${DOCKER_MACHINE} env --shell=bash --no-proxy ${VM})"

	printf "...\033[32mSTARTED\033[0m\n"

else

	printf "...\033[33mNO MACHINE\033[0m\n"

fi

# Pull and run arch-epita
printf "[CLEAR ARCH-EPITA]"
$(docker stop arch-epita 2>&1 > /dev/null \
	&& docker rm arch-epita 2>&1 > /dev/null)
c=$?
if [ $c -eq 0 ]; then
	printf "...\033[32mOK\033[0m\n"
else
	printf "...\033[31mFAILED\033[0m\n"
	exit 1
fi

cd ~

# Pull arch-epita
printf "[PULL ARCH-EPITA]"
$(docker pull romainbourre/arch-epita 2>&1 > /dev/null)
c=$?
if [ $c -eq 0 ]; then
	printf "...\033[32mOK\033[0m\n"
else
	printf "...\033[31mFAILED\033[0m\n"
	exit 1
fi

# Run arch-epita
printf "[RUN ARCH-EPITA]"
$(docker run \
	--cap-add=SYS_PTRACE \
	--security-opt seccomp=unconfined \
	--name arch-epita \
	-dti \
	-v $(pwd):/tmp/app \
	romainbourre/arch-epita:latest 2>&1 > /dev/null)
c=$?
if [ $c -eq 0 ]; then
	printf "...\033[32mOK\033[0m\n"
else
	printf "...\033[31mFAILED\033[0m\n"
	exit 1
fi

clear

docker exec -ti arch-epita /bin/zsh

