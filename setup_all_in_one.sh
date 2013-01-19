#!/bin/bash -xe
#
# Author: Akira Yoshiyama
# 
# Modfied by Koji Tanaka for adjusting parameters 
# for FutureGrid Resources and also for FG Users
#

source setuprc

HTTP_PROXY=$http_proxy
unset http_proxy

##############################################################################
## Install necessary packages
##############################################################################

export DEBIAN_FRONTEND=noninteractive

/usr/bin/aptitude -y update
/usr/bin/aptitude -y upgrade
/usr/bin/aptitude -y install \
	nova-api \
	nova-cert \
	nova-network \
	nova-compute \
	nova-scheduler \
	keystone \
	glance \
	nova-consoleauth \
	nova-novncproxy \
	novnc \
	qpidd \
	python-qpid \
	mysql-server \
	linux-image-extra-virtual

##############################################################################
## Make a script to start/stop all services
##############################################################################

/bin/cat << EOF > openstack.sh
#!/bin/bash

NOVA="network scheduler cert consoleauth novncproxy api"
GLANCE="registry api"
KEYSTONE=""

case "\$1" in
start|restart|status)
	/sbin/\$1 keystone
	for i in \$GLANCE; do
		/sbin/\$1 glance-\$i
	done
	for i in \$NOVA; do
		/sbin/\$1 nova-\$i
	done
	;;
stop)
	for i in \$NOVA; do
		/sbin/stop nova-\$i
	done
	for i in \$GLANCE; do
		/sbin/stop glance-\$i
	done
	/sbin/stop keystone
	;;
esac
exit 0
EOF
/bin/chmod +x openstack.sh

##############################################################################
## Stop all services.
##############################################################################

./openstack.sh stop

##############################################################################
## Modify configuration files of Nova, Glance and Keystone
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
public_interface=$PUBLIC_INTERFACE
flat_network_bridge=br101
flat_interface=$FLAT_INTERFACE
fixed_range=$FIXED_RANGE

# NOVNC
novncproxy_base_url=http://\$my_ip:6080/vnc_auto.html
vncserver_proxyclient_address=\$my_ip
vncserver_listen=\$my_ip

# Cinder
##volume_api_class=nova.volume.cinder.API
EOF

for i in /etc/nova/api-paste.ini \
	/etc/glance/glance-api.conf \
	/etc/glance/glance-registry.conf \
	/etc/keystone/keystone.conf
do
	test -f $i.orig || /bin/cp $i $i.orig
done

CONF=/etc/nova/api-paste.ini
/bin/sed \
	-e 's/%SERVICE_TENANT_NAME%/service/' \
	-e 's/%SERVICE_USER%/nova/' \
	-e "s/%SERVICE_PASSWORD%/$MYSQLPASS/" \
	$CONF.orig > $CONF

CONF=/etc/glance/glance-api.conf
/bin/sed \
	-e 's/%SERVICE_TENANT_NAME%/service/' \
	-e 's/%SERVICE_USER%/glance/' \
	-e "s/%SERVICE_PASSWORD%/$MYSQLPASS/" \
	-e "s/^sql_connection *=.*/sql_connection = mysql:\/\/openstack:$MYSQLPASS@$CONTROLLER\/glance/" \
	-e 's/^#* *config_file *=.*/config_file = \/etc\/glance\/glance-api-paste.ini/' \
	-e 's/^#*flavor *=.*/flavor=keystone/' \
	$CONF.orig > $CONF

CONF=/etc/glance/glance-registry.conf
/bin/sed \
	-e 's/%SERVICE_TENANT_NAME%/service/' \
	-e 's/%SERVICE_USER%/glance/' \
	-e "s/%SERVICE_PASSWORD%/$MYSQLPASS/" \
	-e "s/^sql_connection *=.*/sql_connection = mysql:\/\/openstack:$MYSQLPASS@$CONTROLLER\/glance/" \
	-e 's/^#* *config_file *=.*/config_file = \/etc\/glance\/glance-registry-paste.ini/' \
	-e 's/^#*flavor *=.*/flavor=keystone/' \
	$CONF.orig > $CONF

CONF=/etc/keystone/keystone.conf
/bin/sed \
	-e "s/^#*connection *=.*/connection = mysql:\/\/openstack:$MYSQLPASS@$CONTROLLER\/keystone/" \
	-e "s/^#* *admin_token *=.*/admin_token = $MYSQLPASS/" \
	$CONF.orig > $CONF

for i in nova keystone glance
do
	chown -R $i /etc/$i
done

##############################################################################
## Create accounts of Nova, Glance and Cinder on Message Queuing System
##############################################################################

/usr/sbin/service qpidd stop

PWDB=/etc/qpid/qpidd.sasldb
test -f $PWDB.orig || /bin/mv $PWDB $PWDB.orig
/bin/cp $PWDB.orig $PWDB
/bin/chgrp qpidd $PWDB
for i in nova glance cinder; do
	echo $QPID_PASS | /usr/sbin/saslpasswd2 -c -p -f $PWDB -u $i $i
done

ACL=/etc/qpid/qpidd.acl
test -f $ACL.orig || /bin/mv $ACL $ACL.orig
/bin/cat << EOF > $ACL 
# Group definitions
group admin admin@QPID
group openstack nova@nova cinder@cinder glance@glance

# Admin is allowed to do everything
acl allow admin all
acl allow openstack all

# Deny everything else by default
acl deny all all
EOF

/usr/sbin/service qpidd start

##############################################################################
## Modify MySQL configuration
##############################################################################

mysqladmin -u root password $MYSQLPASS
/sbin/stop mysql

CONF=/etc/mysql/my.cnf
test -f $CONF.orig || /bin/cp $CONF $CONF.orig
/bin/sed -e 's/^bind-address[[:space:]]*=.*/bind-address = 0.0.0.0/' \
	$CONF.orig > $CONF

/sbin/start mysql
sleep 5

##############################################################################
## Create MySQL accounts and databases of Nova, Glance, Keystone and Cinder
##############################################################################

/bin/cat << EOF | /usr/bin/mysql -uroot -p$MYSQLPASS
DROP DATABASE IF EXISTS keystone;
DROP DATABASE IF EXISTS glance;
DROP DATABASE IF EXISTS nova;
DROP DATABASE IF EXISTS cinder;
CREATE DATABASE keystone;
CREATE DATABASE glance;
CREATE DATABASE nova;
CREATE DATABASE cinder;
GRANT ALL ON keystone.* TO 'openstack'@'localhost' IDENTIFIED BY '$MYSQLPASS';
GRANT ALL ON glance.*   TO 'openstack'@'localhost' IDENTIFIED BY '$MYSQLPASS';
GRANT ALL ON nova.*     TO 'openstack'@'localhost' IDENTIFIED BY '$MYSQLPASS';
GRANT ALL ON cinder.*   TO 'openstack'@'localhost' IDENTIFIED BY '$MYSQLPASS';
GRANT ALL ON keystone.* TO 'openstack'@'$CONTROLLER' IDENTIFIED BY '$MYSQLPASS';
GRANT ALL ON glance.*   TO 'openstack'@'$CONTROLLER' IDENTIFIED BY '$MYSQLPASS';
GRANT ALL ON nova.*     TO 'openstack'@'$CONTROLLER' IDENTIFIED BY '$MYSQLPASS';
GRANT ALL ON cinder.*   TO 'openstack'@'$CONTROLLER' IDENTIFIED BY '$MYSQLPASS';
GRANT ALL ON keystone.* TO 'openstack'@'$MYSQL_ACCESS'         IDENTIFIED BY '$MYSQLPASS';
GRANT ALL ON glance.*   TO 'openstack'@'$MYSQL_ACCESS'         IDENTIFIED BY '$MYSQLPASS';
GRANT ALL ON nova.*     TO 'openstack'@'$MYSQL_ACCESS'         IDENTIFIED BY '$MYSQLPASS';
GRANT ALL ON cinder.*   TO 'openstack'@'$MYSQL_ACCESS'         IDENTIFIED BY '$MYSQLPASS';
EOF

##############################################################################
## Initialize databases of Nova, Glance and Keystone
##############################################################################

/usr/bin/keystone-manage db_sync
/usr/bin/glance-manage db_sync
/usr/bin/nova-manage db sync

##############################################################################
## Start Keystone
##############################################################################

/sbin/start keystone
sleep 5
/sbin/status keystone

##############################################################################
## Create a sample data on Keystone
##############################################################################

/bin/sed -e "s/localhost/$CONTROLLER/g" /usr/share/keystone/sample_data.sh > /tmp/sample_data.sh
/bin/bash -x /tmp/sample_data.sh

##############################################################################
## Create credentials
##############################################################################

/bin/cat << EOF > admin_credential
export OS_USERNAME=admin
export OS_PASSWORD=$ADMIN_PASSWORD
export OS_TENANT_NAME=demo
export OS_AUTH_URL=http://$CONTROLLER:5000/v2.0
export OS_NO_CACHE=1
EOF

/bin/cat << EOF > demo_credential
export OS_USERNAME=demo
export OS_PASSWORD=$ADMIN_PASSWORD
export OS_TENANT_NAME=demo
export OS_AUTH_URL=http://$CONTROLLER:5000/v2.0
export OS_NO_CACHE=1
EOF

##############################################################################
## Create a nova network
##############################################################################

/usr/bin/nova-manage network create \
	--label private \
	--num_networks=1 \
	--fixed_range_v4=$FIXED_RANGE \
	--network_size=256

CONF=/etc/rc.local
test -f $CONF.orig || cp $CONF $CONF.orig
/bin/cat << EOF > $CONF
#!/bin/sh -e
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will "exit 0" on success or any other
# value on error.

iptables -A POSTROUTING -t mangle -p udp --dport 68 -j CHECKSUM --checksum-fill

exit 0
EOF

##############################################################################
## Start all srevices
##############################################################################

./openstack.sh start
sleep 5

##############################################################################
## Register Ubuntu-12.10 image on Glance
##############################################################################

http_proxy=$HTTP_PROXY /usr/bin/wget \
http://uec-images.ubuntu.com/releases/quantal/release/ubuntu-12.10-server-cloudimg-amd64-disk1.img

source admin_credential
/usr/bin/glance image-create \
	--name ubuntu-12.10 \
	--disk-format qcow2 \
	--container-format bare \
	--file ubuntu-12.10-server-cloudimg-amd64-disk1.img

/bin/rm -f ubuntu-12.10-server-cloudimg-amd64-disk1.img

##############################################################################
## Add a key pair
##############################################################################

/usr/bin/nova keypair-add key1 > key1.pem
/bin/chmod 600 key1.pem
/bin/chgrp adm key1.pem

##############################################################################
## Reboot
##############################################################################

/sbin/reboot
