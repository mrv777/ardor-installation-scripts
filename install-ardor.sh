#!/bin/bash

#
# This script installs an ardor node (https://ardorplatform.org/) on an ubuntu server.
# It is based on the official installation guide
# (https://ardordocs.jelurida.com/Getting_started)
#

###################################################################################################
# DEFAULTS
###################################################################################################
RELEASEMAINDEFAULT=yes
RELEASETESTDEFAULT=no
OPENAPIDEFAULT=no
HAVEDOMAINDEFAULT=no
ARCHIVALDEFAULT=no

SETUP_DOMAIN_MAINNET=false
IS_ARCHIVAL_MAINNET_NODE=false

SETUP_DOMAIN_TESTNET=false
IS_ARCHIVAL_TESTNET_NODE=false

ENABLE_LETSENCRYPT=false
ENABLE_SELF_SIGNED_CERTIFICATE=false

DEFAULT_INSTALL_LOCATION=$( pwd )

###################################################################################################
# CONFIGURATION
###################################################################################################

#INSTALL_MAINNET_NODE=true
MAINNET_DOMAIN="<domain of mainnet node>"

DOWNLOAD_MAINNET_BLOCKCHAIN=true



#INSTALL_TESTNET_NODE=true
TESTNET_DOMAIN="<domain of testnet node>"

DOWNLOAD_TESTNET_BLOCKCHAIN=true


LETSENCRYPT_RENEW_EVENT="30 2 1 */1 *" # At 02:30 on day-of-month 1 in every month.

REBOOT=true


###################################################################################################
# DEFINES
###################################################################################################

ARDOR_MAINNET_FOLDER="ardor-mainnet"
ARDOR_TESTNET_FOLDER="ardor-testnet"

ARDOR_MAINNET_SERVICE="ardor-mainnet"
ARDOR_TESTNET_SERVICE="ardor-testnet"


LOCAL_USER=$(whoami)


PROFILE_LANGUAGE_VARIABLE="
export LANGUAGE=\"en_US.UTF-8\"
export LANG=\"en_US.UTF-8 \"
export LC_ALL=\"en_US.UTF-8\"
export LC_CTYPE=\"en_US.UTF-8\"
"


NGINX_SELFSIGNED_MAINNET_GATEWAY_CONFIGURATION_FILE_CONTENT="
server {
  server_name ${MAINNET_DOMAIN};

  location / {
    proxy_bind 127.0.0.1;
    proxy_set_header Host \$host;
    proxy_pass http://127.0.0.1:27876/;
  }

    listen 443 ssl;
    ssl_certificate /etc/nginx/ssl/mainnet/cert.pem;
    ssl_certificate_key /etc/nginx/ssl/mainnet/key.pem;

}

server {
  if (\$host = ${MAINNET_DOMAIN}) {
    return 301 https://\$host\$request_uri;
  }

  listen 80;

  server_name ${MAINNET_DOMAIN};
  return 404;
}
"


NGINX_SELFSIGNED_TESTNET_GATEWAY_CONFIGURATION_FILE_CONTENT="
server {
  server_name ${TESTNET_DOMAIN};

  location / {
    proxy_bind 127.0.0.1;
    proxy_set_header Host \$host;
    proxy_pass http://127.0.0.1:26876/;
  }

    listen 443 ssl;
    ssl_certificate /etc/nginx/ssl/testnet/cert.pem;
    ssl_certificate_key /etc/nginx/ssl/testnet/key.pem;

}

server {
  if (\$host = ${TESTNET_DOMAIN}) {
    return 301 https://\$host\$request_uri;
  }

  listen 80;

  server_name ${TESTNET_DOMAIN};
  return 404;
}
"


ARDOR_MAINNET_SERVICE_FILE_CONTENT="
[Unit]
Description=Ardor-Mainnet
After=syslog.target
After=network.target

[Service]
RestartSec=2s
Type=simple
WorkingDirectory=/home/${LOCAL_USER}/${ARDOR_MAINNET_FOLDER}/
ExecStart=/bin/bash /home/${LOCAL_USER}/${ARDOR_MAINNET_FOLDER}/run.sh
Restart=always

[Install]
WantedBy=multi-user.target
"


ARDOR_TESTNET_SERVICE_FILE_CONTENT="
[Unit]
Description=Ardor-Testnet
After=syslog.target
After=network.target

[Service]
RestartSec=2s
Type=simple
WorkingDirectory=/home/${LOCAL_USER}/${ARDOR_TESTNET_FOLDER}/
ExecStart=/bin/bash /home/${LOCAL_USER}/${ARDOR_TESTNET_FOLDER}/run.sh
Restart=always

[Install]
WantedBy=multi-user.target
"


UNATTENDED_UPGRADE_PERIODIC_CONFIG_FILE_CONTENT="
APT::Periodic::Update-Package-Lists \"1\";
APT::Periodic::Download-Upgradeable-Packages \"1\";
APT::Periodic::Unattended-Upgrade \"1\";
APT::Periodic::AutocleanInterval \"1\";
"


RENEW_CERTIFICATE_SCRIPT_CONTENT="
#!/bin/bash

echo \"[INFO] \$(date) ...\" > renew-certificate.log

echo \"[INFO] renewing certificate ...\" >> renew-certificate.log
certbot renew >> renew-certificate.log
echo \"\" >> renew-certificate.log
"

## Make sure we are in the correct directory (corsaro suggestion)
function ChangeDirectory(){
  cd ~
  eval "cd $DEFAULT_INSTALL_LOCATION"
}


###################################################################################################
# MAIN
###################################################################################################
echo ""
date +"%Y-%m-%d %H:%M:%S || [INFO] Ardor install script started"
# Verification Checks
if [ $UID -eq 0 ]; then
  echo "[ERROR] $0 should not be run as root."
  echo "You can run 'bash ./create-sudo-user.sh' to create a new user"
  echo "Exiting..."
  exit 1
fi
if [ "$OSTYPE" != "linux-gnu" ] || [ "$HOSTTYPE" != "x86_64" ]; then
  echo "Error: only Linux (x86_64) is supported."
  exit 2
fi

echo "" && echo "[INFO] Working in the directory: $DEFAULT_INSTALL_LOCATION"
ChangeDirectory

[ "${RELEASEMAIN:-}" ] || read -r -p "Would you like to install a mainnet node? (Default $RELEASEMAINDEFAULT): " RELEASEMAIN
RELEASEMAIN=${RELEASEMAIN:-$RELEASEMAINDEFAULT}
if [ "$RELEASEMAIN" == "yes" ]; then
  INSTALL_MAINNET_NODE=true
  read -r -p "Please enter an Admin Password for this node: " MAINNET_ADMIN_PASSWORD
  [ "${OPENAPIMAIN:-}" ] || read -r -p "Do you want this mainnet node to have an open API? (Default $OPENAPIDEFAULT): " OPENAPIMAIN
  OPENAPIMAIN=${OPENAPIMAIN:-$OPENAPIDEFAULT}
  if [ "$OPENAPIMAIN" == "yes" ]; then
    SETUP_OPENAPI_MAINNET=true

    [ "${HAVEDOMAINMAIN:-}" ] || read -r -p "Do you have a domain name for this mainnet node? (Default $HAVEDOMAINDEFAULT): " HAVEDOMAINMAIN
    HAVEDOMAINMAIN=${HAVEDOMAINMAIN:-$HAVEDOMAINDEFAULT}
    if [ "$HAVEDOMAINMAIN" == "yes" ]; then
      read -r -p "Please enter the domain name: " MAINNET_DOMAIN
      SETUP_DOMAIN_MAINNET=true
      ENABLE_LETSENCRYPT=true
    fi
    
  elif [ "$OPENAPIMAIN" == "no" ]; then
    SETUP_OPENAPI_MAINNET=false
  else
    echo "$OPENAPIMAIN is not valid, please check and re-execute"
    exit 2;
  fi
  [ "${ARCHIVALMAIN:-}" ] || read -r -p "Do you want this mainnet node to be an archival node? (Default $ARCHIVALDEFAULT): " ARCHIVALMAIN
  ARCHIVALMAIN=${ARCHIVALMAIN:-$ARCHIVALDEFAULT}
  if [ "$ARCHIVALMAIN" == "yes" ]; then
    IS_ARCHIVAL_MAINNET_NODE=true    
  fi
elif [ "$RELEASEMAIN" == "no" ]; then
  INSTALL_MAINNET_NODE=false
else
  echo "$RELEASEMAIN is not valid, please check and re-execute"
  exit 2;
fi
if [ "$INSTALL_MAINNET_NODE" == true ]; then
  NXT_MAINNET_PROPERTIES_FILE_CONTENT="
  nxt.adminPassword=${MAINNET_ADMIN_PASSWORD}
  nxt.enablePeerUPnP=false
  nxt.apiServerEnforcePOST=true
  $(if [ ${SETUP_OPENAPI_MAINNET} == true ]; then
    echo nxt.apiServerHost=0.0.0.0
    echo nxt.allowedBotHosts=*
  fi)
  $(if [ ${SETUP_DOMAIN_MAINNET} == true ]; then
    echo "nxt.myAddress=${MAINNET_DOMAIN}"
  fi)
  $(if [ ${IS_ARCHIVAL_MAINNET_NODE} == true ]; then
    echo "nxt.maxPrunableLifetime=-1"
  fi)

  ## Contract Runnner Configuration ##
  ## see https://ardordocs.jelurida.com/Lightweight_Contracts for detailed informations ##
  # nxt.addOns=nxt.addons.ContractRunner
  # addon.contractRunner.secretPhrase=<secretphrase>
  # addon.contractRunner.feeRateNQTPerFXT.IGNIS=250000000
  "
  NGINX_MAINNET_GATEWAY_CONFIGURATION_FILE_CONTENT="
  server {
    listen 80;

    server_name ${MAINNET_DOMAIN};

    location / {
        proxy_bind 127.0.0.1;
        proxy_set_header Host \$host;
        proxy_pass http://127.0.0.1:27876/;
    }
  }
  "
fi

[ "${RELEASETEST:-}" ] || read -r -p "Would you like to install a testnet node? (Default $RELEASETESTDEFAULT): " RELEASETEST
RELEASETEST=${RELEASETEST:-$RELEASETESTDEFAULT}
if [ "$RELEASETEST" == "yes" ]; then
  INSTALL_TESTNET_NODE=true
  read -r -p "Please enter an Admin Password for this node: " TESTNET_ADMIN_PASSWORD
  [ "${OPENAPITEST:-}" ] || read -r -p "Do you want this testnet node to have an open API? (Default $OPENAPIDEFAULT): " OPENAPITEST
  OPENAPITEST=${OPENAPITEST:-$OPENAPIDEFAULT}
  if [ "$OPENAPITEST" == "yes" ]; then
    SETUP_OPENAPI_TESTNET=true

    [ "${HAVEDOMAINTEST:-}" ] || read -r -p "Do you have a domain name for this testnet node? (Default $HAVEDOMAINDEFAULT): " HAVEDOMAINTEST
    HAVEDOMAINTEST=${HAVEDOMAINTEST:-$HAVEDOMAINDEFAULT}
    if [ "$HAVEDOMAINTEST" == "yes" ]; then
      read -r -p "Please enter the domain name: " TESTNET_DOMAIN
      SETUP_DOMAIN_TESTNET=true
      ENABLE_LETSENCRYPT=true
    fi
    
  elif [ "$OPENAPITEST" == "no" ]; then
    SETUP_OPENAPI_TESTNET=false
  else
    echo "$OPENAPITEST is not valid, please check and re-execute"
    exit 2;
  fi
  [ "${ARCHIVALTEST:-}" ] || read -r -p "Do you want this mainnet node to be an archival node? (Default $ARCHIVALDEFAULT): " ARCHIVALTEST
  ARCHIVALTEST=${ARCHIVALTEST:-$ARCHIVALDEFAULT}
  if [ "$ARCHIVALTEST" == "yes" ]; then
    IS_ARCHIVAL_TESTNET_NODE=true    
  fi
elif [ "$RELEASETEST" == "no" ]; then
  INSTALL_TESTNET_NODE=false
else
  echo "$RELEASETEST is not valid, please check and re-execute"
  exit 2;
fi
if [ "$INSTALL_TESTNET_NODE" == true ]; then
  NXT_TESTNET_PROPERTIES_FILE_CONTENT="
  nxt.isTestnet=true
  nxt.adminPassword=${TESTNET_ADMIN_PASSWORD}
  nxt.enablePeerUPnP=false
  nxt.apiServerEnforcePOST=true
  $(if [ ${SETUP_OPENAPI_TESTNET} == true ]; then
    echo nxt.apiServerHost=0.0.0.0
    echo nxt.allowedBotHosts=*
  fi)
  $(if [ ${SETUP_DOMAIN_TESTNET} == true ]; then
      echo "nxt.myAddress=${TESTNET_DOMAIN}"
  fi)
  $(if [ ${IS_ARCHIVAL_TESTNET_NODE} == true ]; then
      echo "nxt.maxPrunableLifetime=-1"
  fi)

  ## Contract Runnner Configuration ##
  ## see https://ardordocs.jelurida.com/Lightweight_Contracts for detailed informations ##
  # nxt.addOns=nxt.addons.ContractRunner
  # addon.contractRunner.secretPhrase=<secretphrase>
  # addon.contractRunner.feeRateNQTPerFXT.IGNIS=250000000
  "
  NGINX_TESTNET_GATEWAY_CONFIGURATION_FILE_CONTENT="
  server {
    listen 80;

    server_name ${TESTNET_DOMAIN};

    location / {
        proxy_bind 127.0.0.1;
        proxy_set_header Host \$host;
        proxy_pass http://127.0.0.1:26876/;
    }
  }
  "
fi

UPDATE_ARDOR_NODES_SCRIPT_CONTENT="
#!/bin/bash

###################################################################################################
# CONFIGURATION
###################################################################################################

UPDATE_MAINNET_NODE=${INSTALL_MAINNET_NODE}
UPDATE_TESTNET_NODE=${INSTALL_TESTNET_NODE}


###################################################################################################
# MAIN
###################################################################################################

###
# Only check for new stable releases to mainnet for both mainnet and testnet nodes
###
date +\"%Y-%m-%d %H:%M:%S || [INFO] Checking for new ardor release\"
ALIAS_VERSION=\$(curl --connect-timeout 2 --retry 2 --retry-delay 0 --retry-max-time 2 -s -S \"http://127.0.0.1:27876/nxt?requestType=getAlias&aliasName=nrsVersion&chain=2\")
REMOTE_VERSION=\$( echo \${ALIAS_VERSION} | jq '.aliasURI' | sed -e 's/^\"//' -e 's/\"$//' | head -n1 | awk '{print \$1;}')

BLOCKCHAIN_VERSION=\$(curl --connect-timeout 2 --retry 2 --retry-delay 0 --retry-max-time 2 -s -S \"http://127.0.0.1:27876/nxt?requestType=getBlockchainStatus\")
LOCAL_VERSION=\$( echo \${BLOCKCHAIN_VERSION} | jq '.version' | sed -e 's/^\"//' -e 's/\"$//')

if [ -z \${REMOTE_VERSION} ] || [ -z \${LOCAL_VERSION} ]; then
  echo \"[WARNING] Failed to check ardor versions\"
  exit 1
fi

if [ \${REMOTE_VERSION} != \${LOCAL_VERSION} ]; then

  echo \"[INFO] downloading new ardor release ...\"
  wget https://www.jelurida.com/ardor-client.zip -q --show-progress
  wget https://www.jelurida.com/ardor-client.zip.asc -q --show-progress
  gpg --with-fingerprint --verify ardor-client.zip.asc ardor-client.zip

  echo \"\" && echo \"[INFO] unzipping new ardor release ...\"
  unzip -qq ardor-client.zip


  if [ \${UPDATE_MAINNET_NODE} == true ]; then

      echo \"\" && echo \"[INFO] stopping ardor mainnet service ...\"
      sudo systemctl stop ${ARDOR_MAINNET_SERVICE}.service


      echo \"\" && echo \"[INFO] installing new ardor release ...\"
      mkdir ardor-mainnet-update

      mv ./${ARDOR_MAINNET_FOLDER}/conf/nxt.properties ./ardor-mainnet-update/nxt.properties
      sudo mv ./${ARDOR_MAINNET_FOLDER}/nxt_db/ ./ardor-mainnet-update/nxt_db/

      rm -rf ./${ARDOR_MAINNET_FOLDER}/
      cp -r ./ardor ./${ARDOR_MAINNET_FOLDER}

      mv ./ardor-mainnet-update/nxt.properties ./${ARDOR_MAINNET_FOLDER}/conf/nxt.properties
      sudo mv ./ardor-mainnet-update/nxt_db/ ./${ARDOR_MAINNET_FOLDER}/nxt_db/


      echo \"\" && echo \"[INFO] restarting ardor mainnet service ...\"
      sudo systemctl start ${ARDOR_MAINNET_SERVICE}.service
  fi


  if [ \${UPDATE_TESTNET_NODE} == true ]; then

      echo \"\" && echo \"[INFO] stopping ardor testnet service ...\"
      sudo systemctl stop ${ARDOR_TESTNET_SERVICE}.service


      echo \"\" && echo \"[INFO] installing new ardor release ...\"
      mkdir ardor-testnet-update

      mv ./${ARDOR_TESTNET_FOLDER}/conf/nxt.properties ./ardor-testnet-update/nxt.properties
      sudo mv ./${ARDOR_TESTNET_FOLDER}/nxt_test_db/ ./ardor-testnet-update/nxt_test_db/

      rm -rf ./${ARDOR_TESTNET_FOLDER}/
      cp -r ./ardor ./${ARDOR_TESTNET_FOLDER}

      mv ./ardor-testnet-update/nxt.properties ./${ARDOR_TESTNET_FOLDER}/conf/nxt.properties
      sudo mv ./ardor-testnet-update/nxt_test_db/ ./${ARDOR_TESTNET_FOLDER}/nxt_test_db/


      echo \"\" && echo \"[INFO] restarting ardor testnet service ...\"
      sudo systemctl start ${ARDOR_TESTNET_SERVICE}.service
  fi


  echo \"\" && echo \"[INFO] cleaning up ...\"
  rm -rf ./ardor-mainnet-update ./ardor-testnet-update
  rm -rf ardor ardor-client.zip ardor-client.zip.asc

  echo \"\" && echo \"[INFO] done. Ardor nodes updated\"
else
  echo \"\" && echo \"[INFO] No update available\"
fi
"

echo "[INFO] setting language variables to solve location problems ..."
echo "${PROFILE_LANGUAGE_VARIABLE}" >> ~/.profile
source ~/.profile


echo "" && echo "[INFO] updating system ..."
sudo apt update -q
[ "${DO_UPDATE:-}" ] || read -r -p "It is recommended that you run an OS update, would you like to do that now? (Default yes): " DO_UPDATE
DO_UPDATE=${DO_UPDATE:-yes}
if [ "$DO_UPDATE" == "yes" ]; then
  sudo apt upgrade -y
fi
# sudo apt install unattended-upgrades -y
# sudo unattended-upgrades --debug cat /var/log/unattended-upgrades/unattended-upgrades.log


echo "" && echo "[INFO] installing unzip ..."
sudo apt-get install unzip -qq > /dev/null

echo "" && echo "[INFO] installing update script dependencies ..."
sudo apt-get install curl jq -qq > /dev/null


echo "" && echo "[INFO] installing OpenJDK 8 ..."
sudo apt-get install openjdk-8-jre -qq > /dev/null


# echo "" && echo "[INFO] enabling unattended-upgrade ..."
# echo "${UNATTENDED_UPGRADE_PERIODIC_CONFIG_FILE_CONTENT}" | sudo tee /etc/apt/apt.conf.d/10periodic > /dev/null


if [ ${SETUP_DOMAIN_MAINNET} == true ] || [ ${SETUP_DOMAIN_TESTNET} == true ]; then
  echo "" && echo "[INFO] installing nginx ..."
  sudo apt-get install nginx -qq > /dev/null
  sudo service nginx stop

  echo "" && echo "[INFO] configuring nginx ..."
  sudo sed -i -e "s/# server_tokens off;/server_tokens off;/g" /etc/nginx/nginx.conf
  sudo sed -i -e "s/# server_names_hash_bucket_size 64;/server_names_hash_bucket_size 64;/g" /etc/nginx/nginx.conf

  sudo rm /etc/nginx/sites-enabled/default

  if [ ${SETUP_DOMAIN_MAINNET} == true ]; then
      echo "" && echo "[INFO] creating mainnet gateway ..."
      echo "${NGINX_MAINNET_GATEWAY_CONFIGURATION_FILE_CONTENT}" | sudo tee /etc/nginx/conf.d/mainnet-gateway.conf > /dev/null
  fi

  if [ ${SETUP_DOMAIN_TESTNET} == true ]; then
      echo "" && echo "[INFO] creating testnet gateway ..."
      echo "${NGINX_TESTNET_GATEWAY_CONFIGURATION_FILE_CONTENT}" | sudo tee /etc/nginx/conf.d/testnet-gateway.conf > /dev/null
  fi

  sudo service nginx start

  if [ ${ENABLE_LETSENCRYPT} == true ]; then
    echo "" && echo "[INFO] installing Let's Encrypt certbot ..."
    sudo apt-get install software-properties-common -qq > /dev/null
    sudo add-apt-repository -y ppa:certbot/certbot
    sudo apt update
    sudo apt-get install python-certbot-nginx -qq
  fi
fi


echo "" && echo "[INFO] downloading ardor ..."
cd ~
wget https://www.jelurida.com/ardor-client.zip -q --show-progress
wget https://www.jelurida.com/ardor-client.zip.asc -q --show-progress

echo "" && echo "[INFO] checking download signiture ..."
wget https://www.jelurida.com/sites/default/files/jelurida.gpg -q --show-progress
gpg --import jelurida.gpg
rm jelurida.gpg
gpg --with-fingerprint --verify ardor-client.zip.asc ardor-client.zip

echo "" && echo "[INFO] unzipping ardor ..."
unzip -qq ardor-client.zip


if [ ${INSTALL_MAINNET_NODE} == true ]; then

    echo "" && echo "[INFO] creating ardor mainnet folder ..."
    cp -r ardor ${ARDOR_MAINNET_FOLDER}


    echo "" && echo "[INFO] creating ardor mainnet configuration ..."
    echo "${NXT_MAINNET_PROPERTIES_FILE_CONTENT}" > ${ARDOR_MAINNET_FOLDER}/conf/nxt.properties


    echo "" && echo "[INFO] creating ardor mainnet service ..."
    sudo mkdir -p /etc/systemd/system
    echo "${ARDOR_MAINNET_SERVICE_FILE_CONTENT}" | sudo tee /etc/systemd/system/${ARDOR_MAINNET_SERVICE}.service > /dev/null


    echo "" && echo "[INFO] enabling ardor mainnet service ..."
    sudo systemctl enable ${ARDOR_MAINNET_SERVICE}.service


    if [ ${DOWNLOAD_MAINNET_BLOCKCHAIN} == true ]; then

        echo "" && echo "[INFO] downloading mainnet blockchain ..."
        wget https://www.jelurida.com/Ardor-nxt_db.zip -q --show-progress

        echo "" && echo "[INFO] unzipping mainnet blockchain ..."
        unzip -qq Ardor-nxt_db.zip

        echo "" && echo "[INFO] moving mainnet blockchain to ardor mainnet folder ..."
        mv nxt_db/ ardor-mainnet/
    fi
fi


if [ ${INSTALL_TESTNET_NODE} == true ]; then

    echo "" && echo "[INFO] creating ardor testnet folder ..."
    cp -r ardor ${ARDOR_TESTNET_FOLDER}


    echo "" && echo "[INFO] creating ardor testnet configuration ..."
    echo "${NXT_TESTNET_PROPERTIES_FILE_CONTENT}" > ${ARDOR_TESTNET_FOLDER}/conf/nxt.properties


    echo "" && echo "[INFO] creating ardor testnet service ..."
    sudo mkdir -p /etc/systemd/system
    echo "${ARDOR_TESTNET_SERVICE_FILE_CONTENT}" | sudo tee /etc/systemd/system/${ARDOR_TESTNET_SERVICE}.service > /dev/null


    echo "" && echo "[INFO] enabling ardor testnet service ..."
    sudo systemctl enable ${ARDOR_TESTNET_SERVICE}.service


    if [ ${DOWNLOAD_TESTNET_BLOCKCHAIN} == true ]; then

        echo "" && echo "[INFO] downloading testnet blockchain ..."
        wget https://www.jelurida.com/Ardor-nxt_test_db.zip -q --show-progress

        echo "" && echo "[INFO] unzipping testnet blockchain ..."
        unzip -qq Ardor-nxt_test_db.zip

        echo "" && echo "[INFO] moving testnet blockchain to ardor testnet folder ..."
        mv nxt_test_db/ ardor-testnet/
    fi
fi


if [ ${ENABLE_LETSENCRYPT} == true ]; then

    MAINNET_DOMAIN_CMD=""
    TESTNET_DOMAIN_CMD=""
    
    if [ ${SETUP_DOMAIN_MAINNET} == true ]; then MAINNET_DOMAIN_CMD="-d ${MAINNET_DOMAIN}"; fi
    if [ ${SETUP_DOMAIN_TESTNET} == true ]; then TESTNET_DOMAIN_CMD="-d ${TESTNET_DOMAIN}"; fi

    echo "" && echo "[INFO] requesting Let's Encrypt certificate(s) ..."
    sudo service nginx start
    sudo certbot --nginx  --agree-tos --register-unsafely-without-email --rsa-key-size 4096 --redirect ${MAINNET_DOMAIN_CMD} ${TESTNET_DOMAIN_CMD}

    echo "" && echo "[INFO] creating renew certificate job ..."
    echo "${RENEW_CERTIFICATE_SCRIPT_CONTENT}" > /home/${LOCAL_USER}/renew-certificate.sh
    sudo chmod 700 /home/${LOCAL_USER}/renew-certificate.sh
    (sudo crontab -l 2>> /dev/null; echo "${LETSENCRYPT_RENEW_EVENT}	/bin/bash /home/${LOCAL_USER}/renew-certificate.sh") | sudo crontab -


elif [ ${ENABLE_SELF_SIGNED_CERTIFICATE} == true ]; then

    if [ ${INSTALL_MAINNET_NODE} == true ]; then

        echo "" && echo "[INFO] creating self signed certificate for mainnet ..."
        openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes -subj "/CN=${MAINNET_DOMAIN}"
        sudo mkdir -p /etc/nginx/ssl/mainnet
        sudo mv cert.pem /etc/nginx/ssl/mainnet
        sudo mv key.pem /etc/nginx/ssl/mainnet

        echo "" && echo "[INFO] updating mainnet gateway ..."
        sudo rm -f /etc/nginx/conf.d/mainnet-gateway.conf
        echo "${NGINX_SELFSIGNED_MAINNET_GATEWAY_CONFIGURATION_FILE_CONTENT}" | sudo tee /etc/nginx/conf.d/mainnet-gateway.conf > /dev/null
    fi


    if [ ${INSTALL_TESTNET_NODE} == true ]; then

        echo "" && echo "[INFO] creating self signed certificate for testnet ..."
        openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes -subj "/CN=${TESTNET_DOMAIN}"
        sudo mkdir -p /etc/nginx/ssl/testnet
        sudo mv cert.pem /etc/nginx/ssl/testnet
        sudo mv key.pem /etc/nginx/ssl/testnet

        echo "" && echo "[INFO] updating testnet gateway ..."
        sudo rm -f /etc/nginx/conf.d/testnet-gateway.conf
        echo "${NGINX_SELFSIGNED_TESTNET_GATEWAY_CONFIGURATION_FILE_CONTENT}" | sudo tee /etc/nginx/conf.d/testnet-gateway.conf > /dev/null
    fi

fi


echo "" && echo "[INFO] creating update script ..."
echo "${UPDATE_ARDOR_NODES_SCRIPT_CONTENT}" > /home/${LOCAL_USER}/update-nodes.sh
sudo chmod 700 /home/${LOCAL_USER}/update-nodes.sh

[ "${AUTO_UPDATES:-}" ] || read -r -p "Would you like to enable automatic updates? (Default yes): " AUTO_UPDATES
AUTO_UPDATES=${AUTO_UPDATES:-yes}
if [ "$AUTO_UPDATES" == "yes" ]; then
  crontab -l | { cat; echo "0 2 * * *  /bin/bash /home/${LOCAL_USER}/update-nodes.sh >/dev/null 2>&1"; } | crontab -
fi

echo "" && echo "[INFO] cleaning up ..."
sudo apt autoremove -y
rm -rf ardor install-ardor.sh *.zip *.zip.asc *.txt


echo ""
date +"%Y-%m-%d %H:%M:%S || [INFO] Server ready to go."
echo "[INFO] To update your node(s) manually you can run './update-nodes.sh',"
echo "[INFO] To run the contract runner, uncomment the parameter in <ardor folder>/conf/nxt.properties"
echo "[INFO] and configure them properly."
echo "[INFO] Press any key to continue and reboot the system"
read -n 1 -s

if [ ${REBOOT} == true ]; then
    echo "" && echo "[INFO] installation finished. Rebooting ..."
    sudo reboot
fi
