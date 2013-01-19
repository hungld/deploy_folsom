Install-script of OpenStack Folsom for Ubuntu-12.10
======================================================

This script installs OpenStack Folsom on Ubuntu-12.10

* setuprc - is configuration file
* setup_controller.sh - Installs Keystone, Glance, Cinder and Nova.
* setup_compute - Installs nova-compute and nova-network.

How to
------
Download.
```
git clone https://github.com/kjtanaka/deploy_folsom.git
cd deploy_folsom
```

Create setuprc:
```
cp setuprc-example setuprc
```

Modify setuprc:
```
# setuprc - configuration file for deploying OpenStack

PASSWORD="DoNotMakeThisEasy"
export ADMIN_PASSWORD=$PASSWORD
export SERVICE_PASSWORD=$PASSWORD
export ENABLE_ENDPOINTS=1
MYSQLPASS=$PASSWORD
QPID_PASS=$PASSWORD
CONTROLLER="192.168.1.1"
FIXED_RANGE="192.168.201.0/24"
MYSQL_ACCESS="192.168.1.%"
PUBLIC_INTERFACE="br101"
FLAT_INTERFACE="eth0"
```

For controller node.
```
bash -ex setup_controller.sh
```
The node will reboot after the installation. You can run
your first instance(VM) by this.
```
. admin_credential
nova boot --image ubuntu-12.10 --flavor 1 --key-name key1 vm001
```
You can check the status with this command.
```
nova list
```
Once your instance become ACTIVE, you can login to it.
```
ssh -i key1.pem ubuntu@192.168.201.2
```

For nova-compute node, use the same setuprc but run setup_compute.sh
like this.
```
bash -ex setup_compute.sh
```


History
--------------------------
* Originally written by Akira Yoshiyama, under Apache License, 
as a single node installation for beginers to try Folsom version.
* Added Cinder configuration.
* Changed messaging system from QPID to RabbitMQ.
* Added a script for setup separate nova-compute node.
