Install-script of OpenStack Folsom on Ubuntu-12.10
======================================================

This script is originally written by Akira Yoshiyama who met
several people who wanted to try OpenStack and don't have time to
study OpenStack. Those people have the same questions, "where should I begin?"
"What is the easiest way to try?" And the general answer is, "why don't you 
try devstack?"

However, devstack is made for developers, not for absolutely-beginners.
So here's the script for absolutely-beginners. The script builds OpenStack
Folsom on Ubuntu-12.10, with FlatDHCP Manager. The machine will be rebooted
at the end of the installation.

Update
--------------
* Changed the static passwords nova/openstack to valiables, so that user can set it.
* Made it able to build multiple nodes. The script are splitted into all_in_one, controller
and compute.
