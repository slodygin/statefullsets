FROM bitnami/postgresql-repmgr:17.4.0-debian-12-r11
#ENV HOME="/" \
#    OS_ARCH="amd64" \
#    OS_FLAVOUR="debian-11" \
#    OS_NAME="linux"
#RUN id

USER root

RUN mkdir -p /var/lib/apt/lists/partial
RUN mkdir -p /var/cache/apt/archives/partial
RUN apt-get update
RUN install_packages supervisor openssh-server
RUN sed -i 's/var\/log\/supervisor/var\/log/g' /etc/supervisor/supervisord.conf
RUN sed -i 's/var\/run/opt\/bitnami\/repmgr\/logs/g' /etc/supervisor/supervisord.conf
RUN sed -i 's/var\/log/opt\/bitnami\/repmgr\/logs/g' /etc/supervisor/supervisord.conf

#user postgres
RUN addgroup --gid 1001 postgres
RUN adduser --uid 1001 --ingroup postgres postgres
RUN usermod -a -G shadow postgres
RUN mkdir /home/postgres/.ssh
RUN chmod 700 /home/postgres/.ssh
COPY authorized_keys id_rsa /home/postgres/.ssh/
RUN chown 1001 -R /home/postgres/.ssh
RUN chgrp 1001 -R /home/postgres/.ssh
RUN chmod 600 /home/postgres/.ssh/*
RUN chown 1001 /etc/ssh/ssh_host*
RUN chgrp 1001 /etc/shadow

RUN cp /opt/bitnami/repmgr/bin/repmgr /opt/bitnami/postgresql/bin/repmgr 
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY bashrc /.bashrc
RUN chown 1001:1001 /.bashrc

USER 1001

CMD ["/usr/bin/supervisord", "-n"]
