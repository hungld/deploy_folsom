#!/bin/bash -xe
# setup_compute.sh - Installs OpenStack compute node.
# Author: Akira Yoshiyama
# 
# Modfied by Koji Tanaka for adjusting parameters 
# for FutureGrid Resources.
#

source setuprc

HTTP_PROXY=$http_proxy
unset http_proxy

##############################################################################
## 必要なパッケージのインストール
##############################################################################

export DEBIAN_FRONTEND=noninteractive

/usr/bin/aptitude -y update
/usr/bin/aptitude -y upgrade
/usr/bin/aptitude -y install \
	nova-compute \
	nova-network \
    python-keystone \
    nova-api-metadata \
	novnc \
	python-qpid \
	linux-image-extra-virtual

##############################################################################
## OpenStack サービス一括起動／停止スクリプト作成
##############################################################################

/bin/cat << EOF > openstack.sh
#!/bin/bash

NOVA="compute network"

case "\$1" in
start|restart|status)
	for i in \$NOVA; do
		/sbin/\$1 nova-\$i
	done
	;;
stop)
	for i in \$NOVA; do
		/sbin/stop nova-\$i
	done
	;;
esac
exit 0
EOF
/bin/chmod +x openstack.sh

##############################################################################
## OpenStack 全サービス停止
##############################################################################

./openstack.sh stop

##############################################################################
## Nova, Glance, Keystone の設定ファイル調整
##############################################################################

/bin/cat << EOF > /etc/nova/nova.conf
[DEFAULT]
verbose=True
debug=True
multi_host=True

# PATH
logdir=/var/log/nova
state_path=/var/lib/nova
lock_path=/var/lock/nova

# SCHEDULER
compute_scheduler_driver=nova.scheduler.filter_scheduler.FilterScheduler

# HYPERVISOR
libvirt_type=kvm
compute_driver=libvirt.LibvirtDriver
libvirt_use_virtio_for_bridges=True
connection_type=libvirt
root_helper=sudo nova-rootwrap /etc/nova/rootwrap.conf

# APIs
ec2_private_dns_show_ip=True
api_paste_config=/etc/nova/api-paste.ini
enabled_apis=ec2,osapi_compute,metadata

# DB
sql_connection=mysql://openstack:$MYSQLPASS@$CONTROLLER/nova

# AMQP
rpc_backend=nova.openstack.common.rpc.impl_qpid
qpid_hostname=$CONTROLLER
qpid_username=nova@nova
qpid_password=$QPID_PASS

# KEYSTONE
auth_strategy=keystone

# GLANCE
image_service=nova.image.glance.GlanceImageService
glance_api_servers=$CONTROLLER:9292

# NETWORK
network_manager=nova.network.manager.FlatDHCPManager
force_dhcp_release=True
dhcpbridge_flagfile=/etc/nova/nova.conf
dhcpbridge=/usr/bin/nova-dhcpbridge
firewall_driver=nova.virt.libvirt.firewall.IptablesFirewallDriver
public_interface=eth1
#vlan_interface=eth0
flat_network_bridge=br101
flat_interface=eth0
fixed_range=$FIXED_RANGE

# NOVNC
novncproxy_base_url=http://\$my_ip:6080/vnc_auto.html
vncserver_proxyclient_address=\$my_ip
vncserver_listen=\$my_ip
vnc_keymap=ja

# Cinder
##volume_api_class=nova.volume.cinder.API
EOF

#CONF=/etc/nova/api-paste.ini
#test -f $CONF || /bin/cp $CONF ${CONF}.orig
#/bin/sed \
#	-e 's/%SERVICE_TENANT_NAME%/service/' \
#	-e 's/%SERVICE_USER%/nova/' \
#	-e "s/%SERVICE_PASSWORD%/$MYSQLPASS/" \
#	$CONF.orig > $CONF

chown -R nova /etc/nova

##############################################################################
## OpenStack サービス群起動
##############################################################################

./openstack.sh start
sleep 5

/sbin/reboot
