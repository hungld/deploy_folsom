Scripts for deploying OpenStack Folsom on Ubuntu-12.10
======================================================

This script is originally written by Akira Yoshiyama who met
several people who wanted to try OpenStack and don't have time to
study OpenStack. Those people have the same questions, "where should I begin?"
"What is the easiest way to try?" And the general answer is, "try devstack!" 

However, devstack is for developers not for absolutely-beginners.
So here's the script for absolutely-beginners of OpenStack.

Update
======
* Changed the static passwords nova/openstack to valiables, so that user can set it.
* Make it able to build multiple nodes. Scripts are splitted into all_in_one, controller
and compute.
