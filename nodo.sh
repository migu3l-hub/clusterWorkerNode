#! /bin/bash

function validacion(){
    if [ $1 != "0" ]; then
        echo -e "\e[31m       Mal\e[0m";
        exit 1;
    fi
        echo -e "\e[32m       OK\e[0m";
}

function validarParams(){
    [[ ! $# -eq 3 ]] && { echo -e "\e[31mTu número de parámetros no es el correcto\e[0m"; modoUso; exit 1; }
    validar_direccion_ip $1
    validar_punto_montaje $2
    validar_interface $3
}

function modoUso(){
    echo 'Para ejecutar el script: nodo.sh IP-MANAGER PUNTO-MONTAJE'
    echo 'Ejemplo: ./nodo.sh 192.168.1.1 /dev/sda1 ens33'
}

function usuario_root(){
    if [ $EUID -eq 0 ]; then
        echo -e "\e[32m       OK\e[0m";
    else
        echo -e "\e[31mDebes ser el usuario root para realizar esto\e[0m";
        exit 1;
    fi
}

function validar_interface(){
  ip add | grep -wom 1 $1
  validacion "$(echo $?)"
}

function validar_punto_montaje(){
    echo '-->Comprobando punto de montaje'
    fdisk -l | grep -w $1
    validacion $(echo $?)
}

function validar_os(){
    hostnamectl | grep -w Arch
    validacion $(echo $?)
}

function acceso_internet(){
    curl www.google.com >/dev/null 2>&1
    validacion $(echo $?)
}

function validar_docker(){
    docker --version > /dev/null
    validacion $(echo $?)
}

function permitir_root_login(){
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
    systemctl restart sshd
    echo -e "\e[32m       OK\e[0m";
}

function conectarse_swarm(){
    DOCKER_SWARM=$(ssh root@$1 cat /root/.configsCluster/.key_swarm)
    $DOCKER_SWARM
    echo -e "\e[32m       OK\e[0m";
}

function install_keepalived(){
         docker run -d --name keepalived --restart=always \
              --cap-add=NET_ADMIN --cap-add=NET_BROADCAST --cap-add=NET_RAW --net=host \
              -e KEEPALIVED_INTERFACE=$4 \
              -e KEEPALIVED_UNICAST_PEERS="#PYTHON2BASH:[$1,$2]" \
              -e KEEPALIVED_VIRTUAL_IPS=$3 \
              -e KEEPALIVED_PRIORITY=100 \
              osixia/keepalived
}

function keepalived(){
        IP_VIRTUAL=$(ssh root@$1 cat /root/.configsCluster/ip_virtual)
        IP_NODO=$(ssh root@$1 cat /root/.configsCluster/ip_nodo_backup)
        install_keepalived $1 $IP_NODO $IP_VIRTUAL $2
}

function comprobaciones(){
        validarParams "$@"
        echo '-->Comprobando si eres usuario root:'
        usuario_root
        echo '-->Comprobando sistema operativo'
        validar_os
        echo '-->Acceso a internet'
        acceso_internet
        echo '-->Comprobando docker'
        validar_docker
}

function validar_direccion_ip(){
        if [[ $1 =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                OIFS=$IFS
                IFS='.'
                ip=($1)
                IFS=$OIFS
                if [[ ${ip[0]} -le 255 && ${ip[1]} -le 255  && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]; then
                        echo -e "\e[32m OK\e[0m";
                else
                        echo -e "\e[31m Error\e[0m";
                        exit 1;
                fi
        else
                echo -e "\e[31m Tu seleccion es erronea\e[0m";
                exit 1;
        fi
}

function validar_ip_backup(){
        ip_nodo=$(ssh root@$1 cat /root/.configsCluster/ip_nodo_backup)
        ip add | grep $ip_nodo
        if [[ "$(echo $?)" == "0" ]]; then
                echo '-->Instalando keepalived'
                keepalived "$1" "$2"
        fi
}

function agregar_script_montaje(){
        git clone https://github.com/migu3l-hub/montajeCeph.git
        mv $PWD/montajeCeph/mountMaster.sh $PWD/montajeCeph/rc.local
        mv $PWD/montajeCeph/rc.local /etc/
        chmod +x /etc/rc.local
        echo -e "\n [Install] \n WantedBy=multi-user.target \n \n [Unit] \n Description=/etc/rc.local Compatibility \n ConditionPathExists=/etc/rc.local \n \n [Service] \n Type=simple \n ExecStart=/etc/rc.local start \n TimeoutSec=0 \n StandardOutput=tty \n RemainAfterExit=yes \n SysVStartPriority=99" > /etc/systemd/system/rc-local.service
        systemctl enable rc-local.service
        systemctl daemon-reload
        systemctl start rc-local.service
}

function main(){
        comprobaciones $1 $2 $3
        echo '-->Permitir login ssh root'
        permitir_root_login
        mkdir /root/.configsCluster
        echo '-->Conectandose a swarm'
        conectarse_swarm $1
        echo 'Iniciando la instalacion de ceph..'
        chmod +x ceph/install_ceph.sh
        chmod -R +x ceph/
        cd ceph/ && bash ./install_ceph.sh "$1" "$2"
        validar_ip_backup $1 $3
        agregar_script_montaje
}

#ip_master=$1
#punto_montaje=$2
#interface=$3

main $1 $2 $3

