# Dockerfile to deploy Mercurial web heads

FROM centos
MAINTAINER Ben Kero <bkero@bke.ro>

ADD setup.sh /
RUN sh /setup.sh

EXPOSE 80
ENTRYPOINT /usr/sbin/httpd -D FOREGROUND
