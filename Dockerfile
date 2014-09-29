# Dockerfile to deploy Mercurial web heads

FROM centos:centos6
MAINTAINER Ben Kero <bkero@bke.ro>

RUN /bin/rpm -ivh http://yum.puppetlabs.com/el/6/products/x86_64/puppetlabs-release-6-11.noarch.rpm
RUN /bin/rpm -ivh http://mirrors.kernel.org/fedora-epel/6/x86_64/epel-release-6-8.noarch.rpm

RUN /usr/bin/yum install -y git
RUN /usr/bin/yum install -y puppet

RUN mkdir /repo_local
RUN mkdir /repo
RUN /bin/ln -sf /repo_local/mozilla /repo/hg

ADD . /etc/puppet/modules/hg
RUN /usr/bin/puppet apply -v -e 'class {"hg::webhead": mercurial_version => "http://staff.osuosl.org/~bkero/mercurial-3.1.1-0.x86_64.rpm"}'

RUN /usr/bin/hg clone https://hg.mozilla.org/hgcustom/version-control-tools /version-control-tools
RUN /usr/bin/hg clone https://hg.mozilla.org/hgcustom/library_overrides/ /repo_local/mozilla/library_overrides
RUN /usr/bin/hg clone https://hg.mozilla.org/hgcustom/pushlog /repo_local/mozilla/extensions
RUN /bin/cp -a /version-control-tools/hghooks/* /repo_local/mozilla/libraries/
RUN /bin/cp -a /version-control-tools/hgtemplates/* /repo_local/mozilla/hg_templates/

RUN /usr/bin/hg clone https://hg.mozilla.org/venkman /repo_local/mozilla/mozilla/venkman

RUN cp /etc/puppet/modules/hg/hgweb.config /repo_local/mozilla/webroot_wsgi/hgweb.config
RUN cp /etc/puppet/modules/hg/hgweb.wsgi /repo_local/mozilla/webroot_wsgi/hgweb.wsgi
RUN chown apache:apache /repo_local/mozilla/webroot_wsgi/hgweb.config /repo_local/mozilla/webroot_wsgi/hgweb.wsgi

ENV APACHE_RUN_USER apache
ENV APACHE_RUN_GROUP apache
ENV APACHE_LOG_DIR /var/log/apache2

EXPOSE 80
ENTRYPOINT ["/usr/sbin/httpd"]
CMD ["-D", "FOREGROUND"]
