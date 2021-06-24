#! /bin/bash

function install_xfsprogs(){
        echo "-->Instalando el paquete xfsprogs desde pacman..."
        pacman -Sy xfsprogs
        echo "-->Configurando el disco o particion ingresada..."
        mkfs.xfs -f -i size=2048 $1
        echo "-->Ingresando la particion en fstab.."
        echo $1 '/mnt/osd xfs rw,noatime,inode64 0 0' >> /etc/fstab
        echo "-->Creando carpetas en /mnt ..."
        existe_directorio "/mnt/osd"
        mkdir -p /mnt/osd && mount /mnt/osd
}

function existe_directorio(){
        if [ -d $1 ]; then
                echo "-->INFO: el directorio ya existe: $1";
        fi
}

function instalando_ceph(){
        pacman -Sy ceph
        ssh root@$1 cat /root/.configsCluster/ips_cluster > /root/.configsCluster/ips_cluster
        archivo='/root/.configsCluster/ips_cluster'
        CONTADOR=0
        while read linea ; do
                ip add | grep -wom 1 ${linea}
                if [ $(echo $?) != "0" ]; then
                        array[$CONTADOR]=${linea}
                fi
                let CONTADOR=CONTADOR+1
        done <<< "`cat $archivo`"
        echo ${array[@]} ":/ /mnt/ceph ceph _netdev,name=swarm,secretfile=/root/.configsCluster/.ceph_key 0 0" >> /etc/fstab
}

# shellcheck disable=SC2120
function crear_carpeta_ceph(){
        echo "En espera del despliegue del contenedor mds en este nodo"
        sleep 90
        ssh root@$1 mount /mnt/ceph
        existe_directorio "/mnt/ceph"
        mkdir /mnt/ceph && mount /mnt/ceph
        mount -a
}

function obteniendo_llave_ceph(){
        ssh root@$1 cat /root/.configsCluster/.ceph_key > /root/.configsCluster/.ceph_key
}

function main(){
        install_xfsprogs $2
        instalando_ceph $1
        obteniendo_llave_ceph $1
        crear_carpeta_ceph $1
        echo "-->listo"
}

main $1 $2