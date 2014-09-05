#!/bin/bash

/usr/bin/yum install -y http://yum.puppetlabs.com/el/6/products/x86_64/puppetlabs-release-6-7.noarch.rpm
/usr/bin/yum -y install puppet git
git clone https://github.com/bkero/puppet-module-hg.git /etc/puppet/modules/hg

puppet module install puppetlabs-vcsrepo --version 1.1.0

puppet apply -v -e 'include hg'
puppet apply -v -e 'include hg::webhead'

cat << EOF > /repo_local/mozilla/webroot_wsgi/hgweb.wsgi
config = "/repo_local/mozilla/webroot_wsgi/hgweb.config"
from mercurial import demandimport; demandimport.enable()
from mercurial.hgweb import hgweb
import os
os.environ["HGENCODING"] = "UTF-8"               
application = hgweb(config)
EOF

cat << EOF > /repo_local/mozilla/webroot_wsgi/hgweb.config
[web]
style = gitweb_mozilla

[paths]
venkman = /repo_local/mozilla/mozilla/venkman
EOF

/usr/bin/hg clone http://hg.mozilla.org/venkman /repo_local/mozilla/mozilla/venkman
