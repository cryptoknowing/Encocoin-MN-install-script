#!/bin/bash

TMP_FOLDER=$(mktemp -d)
CONFIG_FILE='encocoin.conf'
CONFIGFOLDER='/root/.encocoin'
COIN_DAEMON='encocoind'
COIN_CLI='encocoin-cli'
COIN_PATH='/usr/local/bin/'
COIN_TGZC='https://github.com/Encocoin/encocoin-posmn/releases/download/v1.0.0.0/encocoin-qt-linux.tar.gz'
COIN_TGZD='https://github.com/Encocoin/encocoin-posmn/releases/download/v1.0.0.0/encocoin-daemon-linux.tar.gz'
COIN_ZIPC=$(echo $COIN_TGZC | awk -F'/' '{print $NF}')
COIN_ZIPD=$(echo $COIN_TGZD | awk -F'/' '{print $NF}')
COIN_NAME='encocoin'
PROJECT_NAME='Encocoin PoS (XNK-PoS)'
COIN_EXPLORER='http://explorer.encocoin.net'
COIN_PORT=12044
RPC_PORT=12043

NODEIP=$(curl -s4 icanhazip.com)

BLUE="\033[0;34m"
YELLOW="\033[0;33m"
CYAN="\033[0;36m" 
PURPLE="\033[0;35m"
RED='\033[0;31m'
GREEN="\033[0;32m"
NC='\033[0m'
MAG='\e[1;35m'

purgeOldInstallation() {
    echo -e "${YELLOW}Searching and removing old ${BLUE}$PROJECT_NAME Masternode ${YELLOW}files and configurations${NC}"
	#stopping service
	# systemctl stop $COIN_NAME.service
    #kill wallet daemon
	killall $COIN_DAEMON
    #remove old ufw port allow
    ufw delete allow $COIN_PORT/tcp
    #remove old files
    rm $COIN_CLI $COIN_DAEMON
    rm -rf ~/.$COIN_NAME
    #remove binaries and $PROJECT_NAME utilities
    cd /usr/local/bin && sudo rm $COIN_CLI $COIN_DAEMON && cd
    echo -e "${GREEN}* Done${NONE}";
}

function install_sentinel() {
  echo -e "${GREEN}Installing sentinel.${NC}"
  apt-get -y install python-virtualenv virtualenv
  git clone $SENTINEL_REPO $CONFIGFOLDER/sentinel
  cd $CONFIGFOLDER/sentinel
  virtualenv ./venv
  ./venv/bin/pip install -r requirements.txt
  echo  "* * * * * cd $CONFIGFOLDER/sentinel && ./venv/bin/python bin/sentinel.py >> $CONFIGFOLDER/sentinel.log 2>&1" > $CONFIGFOLDER/$COIN_NAME.cron
  crontab $CONFIGFOLDER/$COIN_NAME.cron
  rm $CONFIGFOLDER/$COIN_NAME.cron
}

function download_node() {
  echo -e "${GREEN}Downloading and Installing VPS $PROJECT_NAME Daemon${NC}"
  cd $TMP_FOLDER
  wget -q $COIN_TGZD
  wget -q $COIN_TGZC
  compile_error
#   unzip $COIN_ZIP
  tar zxvf $COIN_ZIPD
  tar zxvf $COIN_ZIPC
  compile_error
#   cd linux
  chmod +x $COIN_DAEMON
  chmod +x $COIN_CLI
  cp $COIN_DAEMON $COIN_PATH
  cp $COIN_DAEMON /root/
  cp $COIN_CLI $COIN_PATH
  cp $COIN_CLI /root/
  cd ~
  rm -rf $TMP_FOLDER
  clear
}

function configure_systemd() {
  cat << EOF > /etc/systemd/system/$COIN_NAME.service
[Unit]
Description=$COIN_NAME service
After=network.target
[Service]
User=root
Group=root
Type=forking
#PIDFile=$CONFIGFOLDER/$COIN_NAME.pid
ExecStart=$COIN_PATH$COIN_DAEMON -daemon -conf=$CONFIGFOLDER/$CONFIG_FILE -datadir=$CONFIGFOLDER
ExecStop=-$COIN_PATH$COIN_CLI -conf=$CONFIGFOLDER/$CONFIG_FILE -datadir=$CONFIGFOLDER stop
Restart=always
PrivateTmp=true
TimeoutStopSec=60s
TimeoutStartSec=10s
StartLimitInterval=120s
StartLimitBurst=5
[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  sleep 3
  systemctl start $COIN_NAME.service
  systemctl enable $COIN_NAME.service >/dev/null 2>&1
  echo -e "\n${GREEN}Encocoin PoS (XNK-PoS) Service Status\n${NC}"
  systemctl status $COIN_NAME.service
  echo -e "\n${BLUE}=======================================================================================================${NC}\n"

  if [[ -z "$(ps axo cmd:100 | egrep $COIN_DAEMON)" ]]; then
    echo -e "${RED}$COIN_NAME is not running${NC}, please investigate. You should start by running the following commands as root:"
    echo -e "${GREEN}systemctl start $COIN_NAME.service"
    echo -e "systemctl status $COIN_NAME.service"
    echo -e "less /var/log/syslog${NC}"
    exit 1
  fi
}


function create_config() {
  mkdir $CONFIGFOLDER
  RPCUSER=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w10 | head -n1)
  RPCPASSWORD=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w22 | head -n1)
  cat << EOF > $CONFIGFOLDER/$CONFIG_FILE
rpcuser=$RPCUSER
rpcpassword=$RPCPASSWORD
rpcport=$RPC_PORT
rpcallowip=127.0.0.1
port=$COIN_PORT
listen=1
server=1
daemon=1
txindex=1
staking=0
EOF
}

function create_key() {
  echo -e "${YELLOW}Enter your ${BLUE}$PROJECT_NAME Masternode Private Key${YELLOW} produced on your local wallet by ${RED}createmasternodekey${YELLOW} command or press enter for a Masternode Private Key is generated automatically${NC}"
  read -e COINKEY
  if [[ -z "$COINKEY" ]]; then
  $COIN_PATH$COIN_DAEMON -daemon
  sleep 30
  if [ -z "$(ps axo cmd:100 | grep $COIN_DAEMON)" ]; then
   echo -e "${RED}$COIN_NAME server couldn not start. Check /var/log/syslog for errors.${$NC}"
   exit 1
  fi
  COINKEY=$($COIN_PATH$COIN_CLI createmasternodekey)
  if [ "$?" -gt "0" ];
    then
    echo -e "${RED}Wallet not fully loaded. Let us wait and try again to generate the Masternode Private Key${NC}"
    sleep 30
    COINKEY=$($COIN_PATH$COIN_CLI createmasternodekey)
  fi
  $COIN_PATH$COIN_CLI stop
fi
clear
}

function update_config() {
  sed -i 's/daemon=1/daemon=0/' $CONFIGFOLDER/$CONFIG_FILE
  cat << EOF >> $CONFIGFOLDER/$CONFIG_FILE
maxconnections=256
bind=$NODEIP
masternode=1
masternodeaddr=$NODEIP:$COIN_PORT
masternodeprivkey=$COINKEY
#ADDNODES
addnode=136.144.171.201:12044
addnode=167.86.90.167:12044
addnode=51.15.253.90:12044
addnode=194.160.80.211:12044
addnode=207.180.218.133:12044
addnode=108.61.78.52:12044
addnode=140.82.13.75:12044
addnode=144.202.14.77:12044
addnode=164.68.112.217:12044
addnode=45.77.123.172:12044
addnode=149.248.10.145:12044
addnode=207.246.108.24:12044
addnode=45.76.61.66:12044
addnode=149.28.94.156:12044
EOF
}


function enable_firewall() {
  echo -e "Installing and setting up firewall to allow ingress on port ${GREEN}$COIN_PORT${NC}"
  ufw allow $COIN_PORT/tcp comment "$COIN_NAME MN port" >/dev/null
  ufw allow ssh comment "SSH"
  ufw limit ssh/tcp
  ufw default allow outgoing
  echo "y" | ufw enable
}


function get_ip() {
  declare -a NODE_IPS
  for ips in $(netstat -i | awk '!/Kernel|Iface|lo/ {print $1," "}')
  do
    NODE_IPS+=($(curl --interface $ips --connect-timeout 2 -s4 icanhazip.com))
  done

  if [ ${#NODE_IPS[@]} -gt 1 ]
    then
      echo -e "${GREEN}More than one IP. Please type 0 to use the first IP, 1 for the second and so on...${NC}"
      INDEX=0
      for ip in "${NODE_IPS[@]}"
      do
        echo ${INDEX} $ip
        let INDEX=${INDEX}+1
      done
      read -e choose_ip
      NODEIP=${NODE_IPS[$choose_ip]}
  else
    NODEIP=${NODE_IPS[0]}
  fi
}


function compile_error() {
if [ "$?" -gt "0" ];
 then
  echo -e "${RED}Failed to compile $COIN_NAME. Please investigate.${NC}"
  exit 1
fi
}


function checks() {
# if [[ $(lsb_release -d) != *16.04* ]]; then
#   echo -e "${RED}You are not running Ubuntu 16.04. Installation is cancelled.${NC}"
#   exit 1
# fi

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}$0 must be run as root.${NC}"
   exit 1
fi

if [ -n "$(pidof $COIN_DAEMON)" ] || [ -e "$COIN_DAEMOM" ] ; then
  echo -e "${RED}$COIN_NAME is already installed.${NC} Please Run again.."
  exit 1
fi
}

function prepare_system() {
echo -e "${YELLOW}Preparing the VPS to setup ${BLUE}$PROJECT_NAME Masternode${NC}"

rm /var/lib/apt/lists/lock
rm /var/cache/apt/archives/lock
rm /var/lib/dpkg/lock

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get update
DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y -qq upgrade
apt install -y software-properties-common
echo -e "${PURPLE}Adding bitcoin PPA repository"
apt-add-repository -y ppa:bitcoin/bitcoin
echo -e "Installing required packages, it may take some time to finish.${NC}"
apt-get update
apt-get install -y libdb4.8-dev libdb4.8++-dev
apt-get install libzmq3-dev -y
apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" make software-properties-common \
build-essential libtool autoconf libssl-dev libboost-dev libboost-chrono-dev libboost-filesystem-dev libboost-program-options-dev \
libboost-system-dev libboost-test-dev libboost-thread-dev sudo automake git wget curl bsdmainutils \
libminiupnpc-dev libgmp3-dev ufw pkg-config libevent-dev libdb5.3++ libstdc++6 unzip libzmq5

if [[ $(lsb_release -d) == *16.04* ]]; then
	add-apt-repository -y ppa:ubuntu-toolchain-r/test
	apt-get update
	apt-get -y upgrade
	apt-get -y dist-upgrade
fi

if [ "$?" -gt "0" ];
  then
    echo -e "${RED}Not all required packages were installed properly. Try to install them manually by running the following commands:${NC}\n"
    echo "apt-get update"
    echo "apt -y install software-properties-common"
    echo "apt-add-repository -y ppa:bitcoin/bitcoin"
    echo "apt-get update"
    echo "apt install -y make build-essential libtool software-properties-common autoconf libssl-dev libboost-dev libboost-chrono-dev libboost-filesystem-dev \
libboost-program-options-dev libboost-system-dev libboost-test-dev libboost-thread-dev sudo automake git curl libdb4.8-dev \
bsdmainutils libdb4.8++-dev libminiupnpc-dev libgmp3-dev ufw pkg-config libevent-dev libdb5.3++ unzip libzmq5"
 exit 1
fi
clear
}

function set_scripts_and_aliases() {
cat << EOF > /root/encocoin-general-info
echo -e "\n\n${BLUE}=======================================================================================================${NC}\n"
echo -e "${GREEN}$PROJECT_NAME General Info: ${NC}"
$COIN_CLI getinfo
echo -e "\n${BLUE}=======================================================================================================${NC}\n"
EOF
chmod +x /root/encocoin-general-info

cat << EOF > /root/encocoin-fee-info
echo -e "\n\n${BLUE}=======================================================================================================${NC}\n"
echo -e "${GREEN}$PROJECT_NAME Fee Info: ${NC}"
$COIN_CLI getfeeinfo 100
echo -e "\n${BLUE}=======================================================================================================${NC}\n"
EOF
chmod +x /root/encocoin-fee-info

cat << EOF > /root/encocoin-networkinfo
echo -e "\n\n${BLUE}=======================================================================================================${NC}\n"
echo -e "${GREEN}$PROJECT_NAME Network Info: ${NC}"
$COIN_CLI getnetworkinfo
echo -e "\n${BLUE}=======================================================================================================${NC}\n"
EOF
chmod +x /root/encocoin-networkinfo

cat << EOF > /root/encocoin-masternode-stats
echo -e "\n\n${BLUE}=======================================================================================================${NC}\n"
echo -e "${GREEN}Last Block: ${NC}"
$COIN_CLI getblockcount
echo -e "\n${GREEN}Masternode Sync Status: ${NC}"
$COIN_CLI mnsync status
echo -e "\n${GREEN}Masternode Status: ${NC}"
$COIN_CLI getmasternodestatus
echo -e "\n${BLUE}=======================================================================================================${NC}\n"
EOF
chmod +x /root/encocoin-masternode-stats

cp /root/.bashrc /root/.bashrc.backup
sed '/feestats/d' /root/.bashrc | sed '/networkstats/d' | sed '/mnstats/d' | sed '/encocoininfo/d' > /root/tmp
mv /root/tmp /root/.bashrc
echo -e "alias encocoininfo='/root/encocoin-networkinfo'" >> /root/.bashrc
echo -e "alias feestats='/root/encocoin-fee-info'" >> /root/.bashrc
echo -e "alias networkstats='/root/encocoin-networkinfo'" >> /root/.bashrc
echo -e "alias mnstats='/root/encocoin-masternode-stats'" >> /root/.bashrc
$( . /root/.bashrc )
# cd -
}

function important_information() {
 echo
 echo -e "${BLUE}================================================================================================================================${NC}"
 echo -e "$PROJECT_NAME Masternode is up and running listening on port ${GREEN}$COIN_PORT${NC}."
 echo -e "Configuration file is: ${RED}$CONFIGFOLDER/$CONFIG_FILE${NC}"
 echo -e "Start: ${RED}systemctl start $COIN_NAME.service${NC}"
 echo -e "Stop: ${RED}systemctl stop $COIN_NAME.service${NC}"
 echo -e "Check Status: ${RED}systemctl status $COIN_NAME.service${NC}"
 echo -e "VPS_IP:PORT ${GREEN}$NODEIP:$COIN_PORT${NC}"
 echo -e "MASTERNODE PRIVATE KEY is: ${RED}$COINKEY${NC}"
 echo -e "Check ${RED}$COIN_CLI getblockcount${NC} and compare to ${GREEN}$COIN_EXPLORER${NC}."
 echo -e "Check ${GREEN}Collateral${NC} already full confirmed and start masternode."
 echo -e "Use ${RED}$COIN_CLI getmasternodestatus${NC} to check your MN Status."
 echo -e "Use ${RED}$COIN_CLI mnsync status${NC} to see if the node is synced with the network."
 echo -e "Use ${RED}$COIN_CLI help${NC} for help."
 echo -e "You can also use ${RED}encocoininfo${NC}, ${RED}feestats${NC}, ${RED}networkstats${NC} and ${RED}mnstats${NC} commands for a nice looking infos."
 echo -e "${BLUE}================================================================================================================================${NC}"
# if [[ -n $SENTINEL_REPO  ]]; then
#  echo -e "${RED}Sentinel${NC} is installed in ${RED}/root/sentinel_$COIN_NAME${NC}"
#  echo -e "Sentinel logs is: ${RED}$CONFIGFOLDER/sentinel.log${NC}"
#  fi
}

function setup_node() {
  get_ip
  create_config
  create_key
  update_config
  enable_firewall
  #install_sentinel
  important_information
  configure_systemd
}


##### Main #####
clear

purgeOldInstallation
checks
prepare_system
download_node
setup_node
set_scripts_and_aliases
