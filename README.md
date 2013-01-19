Install-script of OpenStack Folsom on Ubuntu-12.10
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
'''
cp setuprc-example setuprc
'''

Modify setuprc
'''
a
'''

History
--------------------------
* Originally written by Akira Yoshiyama as a single node installation
for beginers to try Folsom version.
* Added Cinder configuration.
* Changed messaging system from QPID to RabbitMQ.
* Added a script for setup separate nova-compute node.
