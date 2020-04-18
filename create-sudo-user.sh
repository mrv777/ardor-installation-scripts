#!/bin/bash

###################################################################################################
# DEFAULT CONFIGURATION
###################################################################################################

# USER_NAME="<default name of new sudo user>"
# USER_PASSWORD="<default password of new sudo user>"


###################################################################################################
# PARAMETER PARSING
###################################################################################################

while getopts "h?u:p:" opt; do
    case "$opt" in
    h|\?)
        echo "Description:"
        echo "This script creates a sudo user and locks the root account."
        echo "You can use it with or without parameters in any combination."
        echo "If no parameter is specified, the default value set in the script is used."
        echo ""
        echo "Usage:"
        echo "As explained above, you don't have to use all or at least one parameter "
        echo "if you do your configuration with the default parameter inside the script."
        echo "This is just an example of using all parameter to show how to use them."
        echo ""
        echo "$(basename "$0") -u <user name> -p <passoword>"
        echo ""
        echo "Parameter:"
        echo "-u  user name"
        echo "-p  password"
        exit 0
        ;;
    u)  USER_NAME=$OPTARG
        ;;
    p)  USER_PASSWORD=$OPTARG
        ;;
    esac
done

if [ -z "$(grep -Ei 'debian|ubuntu|mint' /etc/*release)" ]; then
  echo "Error: only debian based OS is supported."
  exit 2
fi

if [ -z "$USER_NAME" ]
then
    echo "[ERROR] No User Name provided."
    echo "Expected format: $(basename "$0") -u <user name> -p <passoword>"
    echo "Exiting..."
    exit 1
elif [ -z "$USER_PASSWORD" ]
then
    echo "[ERROR] No User Password provided."
    echo "Expected format: $(basename "$0") -u <user name> -p <passoword>"
    echo "Exiting..."
    exit 1
fi


###################################################################################################
# MAIN
###################################################################################################

echo "[INFO] creating user ${USER_NAME} ..."
adduser ${USER_NAME} --gecos "First Last,RoomNumber,WorkPhone,HomePhone" --disabled-password


echo "[INFO] setting user password ..."
echo "${USER_NAME}:${USER_PASSWORD}" | chpasswd


echo "[INFO] adding user to sudo group ..."
usermod -aG sudo ${USER_NAME}


echo "[INFO] copying public keys ..."
mkdir /home/${USER_NAME}/.ssh
cp /root/.ssh/authorized_keys /home/${USER_NAME}/.ssh/
chown -R ${USER_NAME} /home/${USER_NAME}/.ssh/

# setting permissions
# make public keys folder visible, accessible and changeable only by new user
# make keys visible and changeable only by new user
su -c "cd ~ ; chmod 700 .ssh ; chmod 600 .ssh/authorized_keys" "${USER_NAME}"


echo "[INFO] removing public keys from root account and disabling SSH root login ..."
rm /root/.ssh/authorized_keys
sed -i -e "s/PermitRootLogin yes/PermitRootLogin no/g" /etc/ssh/sshd_config


echo "[INFO] ...finished. All things are done. Close connection and login as ${USER_NAME} again ..."
service ssh restart
exit