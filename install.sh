#!/bin/bash
#set -x
#
#   version 	v0.1
#   date    	2018-12-05
#
#   function:	Install and configure a veil node
# 		Run this script w/ the desired parameters. Leave blank or use -h for help.
#
# Twitter 	@marsmensch

# Useful variables
declare -r DATE_STAMP="$(date +%y-%m-%d-%s)"
declare -r SCRIPTPATH="$(cd $(dirname ${BASH_SOURCE[0]}) > /dev/null; pwd -P)"
declare -r MASTERPATH="$(dirname "${SCRIPTPATH}")"
declare -r SCRIPT_VERSION="v0.1"
declare -r SCRIPT_LOGFILE="/tmp/installer_${DATE_STAMP}_out.log"
declare -r IPV4_DOC_LINK="https://www.vultr.com/docs/add-secondary-ipv4-address"
declare -r DO_NET_CONF="/etc/network/interfaces.d/50-cloud-init.cfg"
declare -r NETWORK_BASE_TAG="$(dd if=/dev/urandom bs=2 count=1 2>/dev/null | od -x -A n | sed -e 's/^[[:space:]]*//g')"
declare -r CODENAME="veil"
declare -r NODE_DAEMON=${NODE_DAEMON:-/usr/local/bin/veild}
declare -r NODE_INBOUND_PORT=${MNODE_INBOUND_PORT:-8223}
declare -r GIT_URL="https://github.com/paddingtonsoftware/veil"
declare -r SCVERSION="master"
declare -r SSH_INBOUND_PORT=${SSH_INBOUND_PORT:-22}
declare -r SYSTEMD_CONF=${SYSTEMD_CONF:-/etc/systemd/system}
declare -r NETWORK_CONFIG=${NETWORK_CONFIG:-/etc/rc.local}
declare -r NODE_CONF_BASE=${NODE_CONF_BASE:-/etc/nodes}
declare -r NODE_DATA_BASE=${NODE_DATA_BASE:-/var/lib/nodes}
declare -r NODE_USER=${NODE_USER:-veil}
declare -r NODE_HELPER="/usr/local/bin/start_veil_nodes"
declare -r NODE_SWAPSIZE=${NODE_SWAPSIZE:-5000}
declare -r CODE_DIR="code"
declare -r SETUP_NODES_COUNT=${SETUP_MODES_COUNT:-1}
NETWORK_TYPE=${NETWORK_TYPE:-4}
ETH_INTERFACE=${ETH_INTERFACE:-ens3}

function showbanner() {
echo $(tput bold)$(tput setaf 2)
cat << "EOF"
.:.                                  .:.
.8 8S8: .  .  . .  . .  . .  . . .SX888:
 ; 88 S8%   .     .         .  ;88   :: 
   8888S@8.    .     . .  .   % 888 X.. 
  .;88 8X@X.     .          .8 8@8:;:   
   :    @  8.. .   . .  . . tX...X@.   .
 .    S.t;;XS          .   :tt@;:8;  .  
   .   8.t ;@% . .  .    .:X%X8S8t      
      . S8 :8 S:  .   ..;@S:888t: . . . 
  .      88: ;t8S:8XX8SX8888:8@S        
    .    ;88 %. :t.88888t.X..@@: .  .  .
   .   ...t@.;.t8tt:88t8;8:.8;.      .  
     .     ;8%X8 ;;8t888;t%8%   . .     
 .  .  . . .X:%88;.tt.:;Xt88t .     .  .
           .  88.8;8:;tSt88t:    .      
  .  .  .     S@ ;;: ;t; :. .  .   . .  
          .    Xt8:8t;t8  .  .         .
  .  . .   .  : ;8tX%;8%   .   . .  .   
   .     .      .S8S888      .    .   . 
       .   .  . . @8;8... .    .    .   
 .  .       .      X@.  .   .    .     .
        .
.    .   .   @marsmensch 2018  .    .   .
EOF
echo "$(tput sgr0)$(tput setaf 3)Have fun, this is crypto after all!$(tput sgr0)"
echo "$(tput setaf 6)Donations (BTC): 33ENWZ9RCYBG7nv6ac8KxBUSuQX64Hx3x3"
echo "Questions: marsmensch@protonmail.com$(tput sgr0)"
}

function get_confirmation() {
    # call with a prompt string or use a default
    read -r -p "${1:-Are you sure? [y/N]} " response
    case "$response" in
        [yY][eE][sS]|[yY])
            true
            ;;
        *)
            false
            ;;
    esac
}

function show_help(){
    clear
    showbanner
    echo "veil node installer, version $SCRIPT_VERSION";
    echo "Usage example:";
    echo "install.sh [(-h|--help)] [(-n|--net) int] [(-c|--count) int] [(-w|--wipe)]";
    echo "Options:";
    echo "-h or --help: Displays this information.";
    echo "-n or --net: IP address type t be used (4 vs. 6).";
    echo "-c or --count: Number of nodes to be installed.";
    echo "-w or --wipe: Wipe ALL local data for a node type.";
    
    echo "exit 1"
    exit 1;
}

function check_distro() {

    # currently only for Ubuntu 16.04 & 18.04
    if [[ -r /etc/os-release ]]; then
        . /etc/os-release
        if [[ "${VERSION_ID}" != "16.04" ]] && [[ "${VERSION_ID}" != "18.04" ]] ; then
            echo "This script only supports Ubuntu 16.04 & 18.04 LTS, exiting."
            exit 1
        fi
    else
        # no, thats not ok!
        echo "This script only supports Ubuntu 16.04 & 18.04 LTS, exiting."
        exit 1
    fi
}

function install_packages() {
    # development and build packages
    # these are common on all cryptos
    echo "* Package installation!"
    add-apt-repository -yu ppa:bitcoin/bitcoin  &>> ${SCRIPT_LOGFILE}
    apt-get -qq -o=Dpkg::Use-Pty=0 -o=Acquire::ForceIPv4=true update  &>> ${SCRIPT_LOGFILE}
    apt-get -qqy -o=Dpkg::Use-Pty=0 -o=Acquire::ForceIPv4=true install build-essential libtool \
            autotools-dev automake pkg-config pv bsdmainutils python3 libssl-dev \
            libevent-dev libboost-system-dev libboost-filesystem-dev git libboost-chrono-dev \
            libboost-test-dev libboost-thread-dev software-properties-common libqt5gui5 \
            libqt5core5a libqt5dbus5 qttools5-dev qttools5-dev-tools libprotobuf-dev \
            protobuf-compiler unzip libqrencode-dev libgmp-dev net-tools && 
            add-apt-repository -y ppa:bitcoin/bitcoin && 
	    apt-get -y install libdb4.8-dev libdb4.8++-dev &>> ${SCRIPT_LOGFILE}

}

function swaphack() {
#check if swap is available
if [ $(free | awk '/^Swap:/ {exit !$2}') ] || [ ! -f "/var/node_swap.img" ];then
    echo "* No proper swap, creating it"
    # needed because ant servers are ants
    rm -f /var/node_swap.img
    dd if=/dev/zero of=/var/node_swap.img bs=1024k count=${NODE_SWAPSIZE} &>> ${SCRIPT_LOGFILE}
    chmod 0600 /var/node_swap.img &>> ${SCRIPT_LOGFILE}
    mkswap /var/node_swap.img &>> ${SCRIPT_LOGFILE}
    swapon /var/node_swap.img &>> ${SCRIPT_LOGFILE}
    echo '/var/node_swap.img none swap sw 0 0' | tee -a /etc/fstab &>> ${SCRIPT_LOGFILE}
    echo 'vm.swappiness=10' | tee -a /etc/sysctl.conf               &>> ${SCRIPT_LOGFILE}
    echo 'vm.vfs_cache_pressure=50' | tee -a /etc/sysctl.conf		&>> ${SCRIPT_LOGFILE}
else
    echo "* All good, we have a swap"
fi
}

function create_node_user() {

    # our new mnode unpriv user acc is added
    if id "${NODE_USER}" >/dev/null 2>&1; then
        echo "user exists already, do nothing" &>> ${SCRIPT_LOGFILE}
    else
        echo "Adding new system user ${NODE_USER}"
        adduser --disabled-password --gecos "" ${NODE_USER} &>> ${SCRIPT_LOGFILE}
    fi

}

function create_node_dirs() {

    # individual data dirs for now to avoid problems
    echo "* Creating node directories"
    mkdir -p ${NODE_CONF_BASE}
    for NUM in $(seq 1 ${count}); do
        if [ ! -d "${NODE_DATA_BASE}/${CODENAME}${NUM}" ]; then
             echo "creating data directory ${NODE_DATA_BASE}/${CODENAME}${NUM}" &>> ${SCRIPT_LOGFILE}
             mkdir -p ${NODE_DATA_BASE}/${CODENAME}${NUM} &>> ${SCRIPT_LOGFILE}
        fi
    done

}

function configure_firewall() {

    echo "* Configuring firewall rules"
    # disallow everything except ssh and node inbound ports
    ufw default deny                          &>> ${SCRIPT_LOGFILE}
    ufw logging on                            &>> ${SCRIPT_LOGFILE}
    ufw allow ${SSH_INBOUND_PORT}/tcp         &>> ${SCRIPT_LOGFILE}
    # KISS, its always the same port for all interfaces
    ufw allow ${MNODE_INBOUND_PORT}/tcp       &>> ${SCRIPT_LOGFILE}
    # This will only allow 6 connections every 30 seconds from the same IP address.
    ufw limit OpenSSH	                      &>> ${SCRIPT_LOGFILE}
    ufw --force enable                        &>> ${SCRIPT_LOGFILE}
    echo "* Firewall ufw is active and enabled on system startup"

}

function validate_netchoice() {

    echo "* Validating network rules"

    # break here of net isn't 4 or 6
    if [ ${net} -ne 4 ] && [ ${net} -ne 6 ]; then
        echo "invalid NETWORK setting, can only be 4 or 6!"
        exit 1;
    fi

    # generate the required ipv6 config
    if [ "${net}" -eq 4 ]; then
        IPV6_INT_BASE="#NEW_IPv4_ADDRESS_FOR_MASTERNODE_NUMBER"
        echo "IPv4 address generation needs to be done manually atm!"  &>> ${SCRIPT_LOGFILE}
    fi	# end ifneteq4

}

function create_node_configuration() {

        echo "in create_node_configuration"

        # always return to the script root
        cd ${SCRIPTPATH}

        # create one config file per node
        for NUM in $(seq 1 ${count}); do
        PASS=$(date | md5sum | cut -c1-24)

            # we dont want to overwrite an existing config file
            if [ ! -f ${NODE_CONF_BASE}/${CODENAME}_n${NUM}.conf ]; then
                echo "individual node config doesn't exist, generate it!"                  &>> ${SCRIPT_LOGFILE}

                # if a template exists, use this instead of the default
                if [ -e ${CODENAME}.conf ]; then
                    echo "custom configuration template for ${CODENAME} found, use this instead"  &>> ${SCRIPT_LOGFILE}
                    cp ${SCRIPTPATH}/${CODENAME}.conf ${NODE_CONF_BASE}/${CODENAME}_n${NUM}.conf  &>> ${SCRIPT_LOGFILE}
                else
                    echo "No ${CODENAME} template found, using the default configuration template"	             &>> ${SCRIPT_LOGFILE}
                    cp ${SCRIPTPATH}/config/default.conf ${NODE_CONF_BASE}/${CODENAME}_n${NUM}.conf                  &>> ${SCRIPT_LOGFILE}
                fi
                # replace placeholders
                echo "running sed on file ${NODE_CONF_BASE}/${CODENAME}_n${NUM}.conf"                                &>> ${SCRIPT_LOGFILE}
                sed -e "s/XXX_GIT_PROJECT_XXX/${CODENAME}/" -e "s/XXX_NUM_XXY/${NUM}]/" -e "s/XXX_NUM_XXX/${NUM}/" -e "s/XXX_PASS_XXX/${PASS}/" -e "s/XXX_IPV6_INT_BASE_XXX/[${IPV6_INT_BASE}/" -e "s/XXX_NETWORK_BASE_TAG_XXX/${NETWORK_BASE_TAG}/" -e "s/XXX_MNODE_INBOUND_PORT_XXX/${MNODE_INBOUND_PORT}/" -i ${NODE_CONF_BASE}/${CODENAME}_n${NUM}.conf
            fi
        done

}

function create_systemd_configuration() {

    echo "* (over)writing systemd config files for nodes"
    # create one config file per node
    for NUM in $(seq 1 ${count}); do
    PASS=$(date | md5sum | cut -c1-24)
        echo "* (over)writing systemd config file ${SYSTEMD_CONF}/${CODENAME}_n${NUM}.service"  &>> ${SCRIPT_LOGFILE}
		cat > ${SYSTEMD_CONF}/${CODENAME}_n${NUM}.service <<-EOF
			[Unit]
			Description=${CODENAME} distributed currency daemon
			After=network.target

			[Service]
			User=${NODE_USER}
			Group=${NODE_USER}

			Type=forking
			PIDFile=${NODE_DATA_BASE}/${CODENAME}${NUM}/${CODENAME}.pid
			ExecStart=${NODE_DAEMON} -daemon -pid=${NODE_DATA_BASE}/${CODENAME}${NUM}/${CODENAME}.pid -conf=${NODE_CONF_BASE}/${CODENAME}_n${NUM}.conf -datadir=${NODE_DATA_BASE}/${CODENAME}${NUM}

			Restart=always
			RestartSec=5
			PrivateTmp=true
			TimeoutStopSec=60s
			TimeoutStartSec=5s
			StartLimitInterval=120s
			StartLimitBurst=15

			[Install]
			WantedBy=multi-user.target
		EOF
    done

}

#
# /* set all permissions to the node user */
#
function set_permissions() {

	# maybe add a sudoers entry later
	chown -R ${NODE_USER}:${NODE_USER} ${NODE_CONF_BASE} ${NODE_DATA_BASE} &>> ${SCRIPT_LOGFILE}
    # make group permissions same as user, so vps-user can be added to node group
    chmod -R g=u ${NODE_CONF_BASE} ${NODE_DATA_BASE} &>> ${SCRIPT_LOGFILE}

}

#
# /* wipe all files and folders generated by the script for a specific project */
#
function wipe_all() {

    echo "Deleting all ${project} related data!"
    rm -f /etc/nodes/${project}_n*.conf
    rmdir --ignore-fail-on-non-empty -p /var/lib/nodes/${project}*
    rm -f /etc/systemd/system/${project}_n*.service
    rm -f ${NODE_DAEMON}
    echo "DONE!"
    exit 0

}

#
# /*
# remove packages and stuff we don't need anymore and set some recommended
# kernel parameters
# */
#
function cleanup_after() {

    #apt-get -qqy -o=Dpkg::Use-Pty=0 --force-yes autoremove
    apt-get -qqy -o=Dpkg::Use-Pty=0 --allow-downgrades --allow-change-held-packages autoclean

    echo "kernel.randomize_va_space=1" > /etc/sysctl.conf  &>> ${SCRIPT_LOGFILE}
    echo "net.ipv4.conf.all.rp_filter=1" >> /etc/sysctl.conf &>> ${SCRIPT_LOGFILE}
    echo "net.ipv4.conf.all.accept_source_route=0" >> /etc/sysctl.conf &>> ${SCRIPT_LOGFILE}
    echo "net.ipv4.icmp_echo_ignore_broadcasts=1" >> /etc/sysctl.conf &>> ${SCRIPT_LOGFILE}
    echo "net.ipv4.conf.all.log_martians=1" >> /etc/sysctl.conf &>> ${SCRIPT_LOGFILE}
    echo "net.ipv4.conf.default.log_martians=1" >> /etc/sysctl.conf &>> ${SCRIPT_LOGFILE}
    echo "net.ipv4.conf.all.accept_redirects=0" >> /etc/sysctl.conf &>> ${SCRIPT_LOGFILE}
    echo "net.ipv6.conf.all.accept_redirects=0" >> /etc/sysctl.conf &>> ${SCRIPT_LOGFILE}
    echo "net.ipv4.conf.all.send_redirects=0" >> /etc/sysctl.conf &>> ${SCRIPT_LOGFILE}
    echo "kernel.sysrq=0" >> /etc/sysctl.conf &>> ${SCRIPT_LOGFILE}
    echo "net.ipv4.tcp_timestamps=0" >> /etc/sysctl.conf &>> ${SCRIPT_LOGFILE}
    echo "net.ipv4.tcp_syncookies=1" >> /etc/sysctl.conf &>> ${SCRIPT_LOGFILE}
    echo "net.ipv4.icmp_ignore_bogus_error_responses=1" >> /etc/sysctl.conf &>> ${SCRIPT_LOGFILE}
    sysctl -p

}

#
# /* project as parameter, sources the project specific parameters and runs the main logic */
#

# source the default and desired crypto configuration files
function source_config() {

    # first things first, to break early if things are missing or weird
    check_distro
        project=${CODENAME}
        echo "Script version ${SCRIPT_VERSION}, you picked: $(tput bold)$(tput setaf 2) ${project} $(tput sgr0), running on Ubuntu ${VERSION_ID}"
        echo "apply config file for ${project}"	&>> ${SCRIPT_LOGFILE}

        # count is from the default config but can ultimately be
        # overwritten at runtime
        if [ -z "${count}" ]
        then
            count=${SETUP_MNODES_COUNT}
            echo "No number given, installing default number of nodes: ${SETUP_MNODES_COUNT}" &>> ${SCRIPT_LOGFILE}
        fi

        # release is from the default project config but can ultimately be
        # overwritten at runtime
        if [ -z "$release" ]
        then
            release=${SCVERSION}
            echo "release empty, setting to project default: ${SCVERSION}"  &>> ${SCRIPT_LOGFILE}
        fi

        # net is from the default config but can ultimately be
        # overwritten at runtime
        if [ -z "${net}" ]; then
            net=${NETWORK_TYPE}
            echo "net EMPTY, setting to default: ${NETWORK_TYPE}" &>> ${SCRIPT_LOGFILE}
        fi

        echo "************************* Installation Plan *****************************************"
        echo ""
        echo "I am going to install and configure "
        echo "$(tput bold)$(tput setaf 2) => ${count} ${project} node(s) in version ${release} $(tput sgr0)"
        echo "for you now."
        echo ""
        echo "Stay tuned!"
        echo ""
        # show a hint for MANUAL IPv4 configuration
        if [ "${net}" -eq 4 ]; then
            NETWORK_TYPE=4
            echo "IPV4WARNING:"
        fi

        echo ""
        echo "A logfile for this run can be found at the following location:"
        echo "${SCRIPT_LOGFILE}"
        echo ""
        echo "*************************************************************************************"
        sleep 5


        echo "**** MAIN TRIGGER ****"

        # main routine
        prepare_node_interfaces
        swaphack
        install_packages
        build_node_from_source
        create_node_user
        create_node_dirs
        configure_firewall
        create_node_configuration
        create_systemd_configuration
        set_permissions
        cleanup_after
        showbanner
        final_call

}

function build_node_from_source() {

        echo "build_from_source"

        # daemon not found compile it
        if [ ! -f ${NODE_DAEMON} ] || [ "$update" -eq 1 ]; then
                # create code directory if it doesn't exist
                if [ ! -d ${SCRIPTPATH}/${CODE_DIR} ]; then
                    mkdir -p ${SCRIPTPATH}/${CODE_DIR}              &>> ${SCRIPT_LOGFILE}
                fi
                # if coin directory (CODENAME) exists, we remove it, to make a clean git clone
                if [ -d ${SCRIPTPATH}/${CODE_DIR}/${CODENAME} ]; then
                    echo "deleting ${SCRIPTPATH}/${CODE_DIR}/${CODENAME} for clean cloning" &>> ${SCRIPT_LOGFILE}
                    rm -rf ${SCRIPTPATH}/${CODE_DIR}/${CODENAME}    &>> ${SCRIPT_LOGFILE}
                fi
                cd ${SCRIPTPATH}/${CODE_DIR}                        &>> ${SCRIPT_LOGFILE}
                git clone ${GIT_URL} ${CODENAME}                    &>> ${SCRIPT_LOGFILE}
                cd ${SCRIPTPATH}/${CODE_DIR}/${CODENAME}            &>> ${SCRIPT_LOGFILE}
                echo "* Checking out desired GIT tag: ${release}"
                git checkout ${release}                             &>> ${SCRIPT_LOGFILE}

                if [ "$update" -eq 1 ]; then
                    echo "update given, deleting the old daemon NOW!" &>> ${SCRIPT_LOGFILE}
                    rm -f ${NODE_DAEMON}
                    # old daemon must be removed before compilation. Would be better to remove it afterwards, however not possible with current structure
                    if [ -f ${NODE_DAEMON} ]; then
                            echo "UPDATE FAILED!"
                            exit 1
                    fi
                fi

                # compilation starts here
                source ${SCRIPTPATH}/${CODENAME}.compile | pv -t -i0.1
        else
                echo "* Daemon already in place at ${NODE_DAEMON}, not compiling"
        fi

        # if it's not available after compilation, theres something wrong
        if [ ! -f ${NODE_DAEMON} ]; then
                echo "COMPILATION FAILED! Sorry!"
                exit 1
        fi
}

function final_call() {

    # note outstanding tasks that need manual work
    echo "************! ALMOST DONE !******************************"
    echo "=> $(tput bold)$(tput setaf 2) All configuration files are in: ${NODE_CONF_BASE} $(tput sgr0)"
    echo "=> $(tput bold)$(tput setaf 2) All Data directories are in: ${NODE_DATA_BASE} $(tput sgr0)"
    echo ""
    echo "$(tput bold)$(tput setaf 1)Important:$(tput sgr0) run $(tput setaf 2) /usr/local/bin/start_veil_nodes $(tput sgr0) as root to activate your nodes."

    # place future helper script accordingly on fresh install
    if [ "$update" -eq 0 ]; then
        cp ${SCRIPTPATH}/start_veil_nodes ${MNODE_HELPER}_${CODENAME}
        echo "">> ${MNODE_HELPER}_${CODENAME}

        for NUM in $(seq 1 ${count}); do
            echo "systemctl daemon-reload" >> ${MNODE_HELPER}_${CODENAME}
            echo "systemctl enable ${CODENAME}_n${NUM}" >> ${MNODE_HELPER}_${CODENAME}
            echo "systemctl restart ${CODENAME}_n${NUM}" >> ${MNODE_HELPER}_${CODENAME}
        done

        chmod u+x ${MNODE_HELPER}_${CODENAME}
    fi

    if [ "$startnodes" -eq 1 ]; then
        echo ""
        echo "** Your nodes are starting up."
        ${MNODE_HELPER}_${CODENAME}
    fi
    tput sgr0
    
}

#
# /* no parameters, create the required network configuration. IPv6 is auto.  */
#
function prepare_node_interfaces() {

    echo "prepare interfaces"

    # this allows for more flexibility since every provider uses another default interface
    # current default is:
    # * ens3 (vultr) w/ a fallback to "eth0" (Hetzner, DO & Linode w/ IPv4 only)
    #

    # check for the default interface status
    if [ ! -f /sys/class/net/${ETH_INTERFACE}/operstate ]; then
        echo "Default interface doesn't exist, switching to eth0"
        export ETH_INTERFACE="eth0"
    fi

    # check for the nuse case <3
    if [ -f /sys/class/net/ens160/operstate ]; then
        export ETH_INTERFACE="ens160"
    fi

    # get the current interface state
    ETH_STATUS=$(cat /sys/class/net/${ETH_INTERFACE}/operstate)

    # check interface status
    if [[ "${ETH_STATUS}" = "down" ]] || [[ "${ETH_STATUS}" = "" ]]; then
        echo "Default interface is down, fallback didn't work. Break here."
        exit 1
    fi

    IPV6_INT_BASE="$(ip -6 addr show dev ${ETH_INTERFACE} | grep inet6 | awk -F '[ \t]+|/' '{print $3}' | grep -v ^fe80 | grep -v ^::1 | cut -f1-4 -d':' | head -1)" &>> ${SCRIPT_LOGFILE}

    validate_netchoice
    echo "IPV6_INT_BASE AFTER : ${IPV6_INT_BASE}" &>> ${SCRIPT_LOGFILE}

    # user opted for ipv6 (default), so we have to check for ipv6 support
    # check for vultr ipv6 box active
    if [ -z "${IPV6_INT_BASE}" ] && [ ${net} -ne 4 ]; then
        echo "No IPv6 support on the VPS but IPv6 is the setup default. Please switch to ipv4 with flag \"-n 4\" if you want to continue."
        echo ""
        echo "See the following link for instructions how to add multiple ipv4 addresses on vultr:"
        echo "${IPV4_DOC_LINK}"
        exit 1
    fi

    # generate the required ipv6 config
    if [ "${net}" -eq 6 ]; then
        # vultr specific, needed to work
        sed -ie '/iface ${ETH_INTERFACE} inet6 auto/s/^/#/' ${NETWORK_CONFIG} &>> ${SCRIPT_LOGFILE}

        # move current config out of the way first
        cp ${NETWORK_CONFIG} ${NETWORK_CONFIG}.${DATE_STAMP}.bkp &>> ${SCRIPT_LOGFILE}

        # create the additional ipv6 interfaces, rc.local because it's more generic
        for NUM in $(seq 1 ${count}); do

            # check if the interfaces exist
            ip -6 addr | grep -qi "${IPV6_INT_BASE}:${NETWORK_BASE_TAG}::${NUM}"
            if [ $? -eq 0 ]
            then
              echo "IP for node already exists, skipping creation" &>> ${SCRIPT_LOGFILE}
            else
              echo "Creating new IP address for ${CODENAME} node nr ${NUM}" &>> ${SCRIPT_LOGFILE}
              if [ "${NETWORK_CONFIG}" = "/etc/rc.local" ]; then
                # need to put network config in front of "exit 0" in rc.local
                sed -e '$i ip -6 addr add '"${IPV6_INT_BASE}"':'"${NETWORK_BASE_TAG}"'::'"${NUM}"'/64 dev '"${ETH_INTERFACE}"'\n' -i ${NETWORK_CONFIG} &>> ${SCRIPT_LOGFILE}
              else
                # if not using rc.local, append normally
                  echo "ip -6 addr add ${IPV6_INT_BASE}:${NETWORK_BASE_TAG}::${NUM}/64 dev ${ETH_INTERFACE}" >> ${NETWORK_CONFIG} &>> ${SCRIPT_LOGFILE}
              fi
              sleep 2
              ip -6 addr add ${IPV6_INT_BASE}:${NETWORK_BASE_TAG}::${NUM}/64 dev ${ETH_INTERFACE} &>> ${SCRIPT_LOGFILE}
            fi
        done # end forloop
    fi # end ifneteq6

}

##################------------Menu()---------#####################################

# Declare vars. Flags initalizing to 0.
wipe=0;
debug=0;

# Execute getopt
ARGS=$(getopt -o "h:n:c:r:wd" -l "help,net:,count:,wipe,debug" -n "install.sh" -- "$@");

eval set -- "$ARGS";

while true; do
    case "$1" in
        -h|--help)
            shift;
            # show help?!?
            ;;
        -n|--net)
            shift;
                    if [ -n "$1" ];
                    then
                        net="$1";
                        shift;
                    fi
            ;;
        -c|--count)
            shift;
                    if [ -n "$1" ];
                    then
                        count="$1";
                        shift;
                    fi
            ;;
        -w|--wipe)
            shift;
                    wipe="1";
            ;;
        -d|--debug)
            shift;
                    debug="1";
            ;;
        --)
            shift;
            break;
            ;;
    esac
done
	    
# Check required arguments
if [ "$wipe" -eq 1 ]; then
    get_confirmation "Would you really like to WIPE ALL DATA!? YES/NO y/n" && wipe_all
    exit 0
fi

main() {

    echo "starting" &> ${SCRIPT_LOGFILE}
    showbanner

    # debug
    if [ "$debug" -eq 1 ]; then
        echo "********************** VALUES AFTER CONFIG SOURCING: ************************"
        echo "START DEFAULTS => "
        echo "SCRIPT_VERSION:       $SCRIPT_VERSION"
        echo "SSH_INBOUND_PORT:     ${SSH_INBOUND_PORT}"
        echo "SYSTEMD_CONF:         ${SYSTEMD_CONF}"
        echo "NETWORK_CONFIG:       ${NETWORK_CONFIG}"
        echo "NETWORK_TYPE:         ${NETWORK_TYPE}"
        echo "ETH_INTERFACE:        ${ETH_INTERFACE}"
        echo "NODE_CONF_BASE:       ${NODE_CONF_BASE}"
        echo "NODE_DATA_BASE:       ${NODE_DATA_BASE}"
        echo "NODE_USER:            ${NODE_USER}"
        echo "NODE_HELPER:          ${NODE_HELPER}"
        echo "NODE_SWAPSIZE:        ${NODE_SWAPSIZE}"
        echo "NETWORK_BASE_TAG:     ${NETWORK_BASE_TAG}"        
        echo "CODE_DIR:             ${CODE_DIR}"
        echo "SCVERSION:            ${SCVERSION}"
        echo "RELEASE:              ${release}"
        echo "SETUP_NODES_COUNT:    ${SETUP_NODES_COUNT}"
        echo "END DEFAULTS => "
    fi

    # source project configuration
    source_config ${project}

}

main "$@"
