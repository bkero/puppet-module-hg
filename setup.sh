#!/bin/bash

/usr/bin/yum install -y http://yum.puppetlabs.com/el/6/products/x86_64/puppetlabs-release-6-7.noarch.rpm
/usr/bin/yum -y install puppet git
git clone https://github.com/bkero/puppet-module-hg.git /etc/puppet/modules/hg

puppet module install puppetlabs-vcsrepo --version 1.1.0

puppet apply -v -e 'include hg'
puppet apply -v -e 'include hg::webhead'
