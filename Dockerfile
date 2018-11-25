FROM mysql

RUN	mkdir -p /usr/sql
RUN	chmod 644 /usr/sql
COPY ["db/init.sql", "/usr/sql/init.sql"]
RUN echo "CREATE DATABASE $MYSQL_NAME; GRANT SELECT ON $MYSQL_NAME.* TO '$MYSQL_USER'@'127.0.0.1' IDENTIFIED BY '$MYSQL_PASS'; FLUSH PRIVILEGES; USE $MYSQL_NAME;$(cat /usr/sql/init.sql)" > "/usr/sql/init.sql"
RUN cp /usr/sql/init.sql /docker-entrypoint-initdb.d/

#ARG DOMAIN
#ARG MYSQL_ROOT_PASSWORD
#ARG MYSQL_NAME
#ARG MYSQL_USER
#ARG MYSQL_PASS
#
## install packages
#RUN apt-get update -q --fix-missing
#RUN DEBIAN_FRONTEND=noninteractive apt-get install -y postfix
#RUN apt-get -y install postfix && \
#    apt-get -y install --no-install-recommends \
#        postfix-mysql \
#        dovecot-core \
#        dovecot-imapd \
#        dovecot-pop3d \
#        dovecot-lmtpd \
#        dovecot-mysql \
#        openssl \
#    && apt-get autoclean && \
#    rm -rf /var/lib/apt/lists/* && \
#    rm -rf /usr/share/locale/* && \
#    rm -rf /usr/share/man/* && \
#    rm -rf /usr/share/doc/*
#
## create folders and users
#RUN mkdir -p /var/mail/vhosts/$DOMAIN
#RUN ls /var/mail/vhosts/$DOMAIN
#RUN mkdir -p /etc/ssl/
#RUN groupadd -g 5000 vmail
#RUN useradd -g vmail -u 5000 vmail -d /var/mail
#
## create cert
#RUN openssl req -new -x509 -days 1000 -nodes -out "/etc/ssl/dovecot.cert" -keyout "/etc/ssl/dovecot.key"
#
## move all config files
#COPY configs/* /etc/
#
## customise configs
#RUN echo -e "user = $MYSQL_USER\npassword = $MYSQL_PASS\nhosts = 127.0.0.1\ndbname = $MYSQL_NAME\nquery = SELECT 1 FROM virtual_users WHERE email='%s'" > /etc/postfix/mysql-virtual-mailbox-maps.cf
#RUN echo -e "user = $MYSQL_USER\npassword = $MYSQL_PASS\nhosts = 127.0.0.1\ndbname = $MYSQL_NAME\nquery = SELECT 1 FROM virtual_domains WHERE name='%s'" > /etc/postfix/mysql-virtual-mailbox-domains.cf
#RUN echo -e "connect = host=127.0.0.1 dbname=$MYSQL_NAME user=$MYSQL_USER password=$MYSQL_PASS" >> /etc/dovecot/dovecot-sql.conf.ext
#RUN echo -e "myhostname = $DOMAIN" >> /etc/postfix/main.cf
#RUN echo -e "export MAIL_DB_NAME='$MYSQL_NAME'\nexport MAIL_DB_USER='$MYSQL_USER'\nexport MAIL_DB_PASS='$MYSQL_PASS'" >> ~/.bashrc
#RUN . ~/.bashrc
#
## set permissions
#RUN chmod -R o-rwx /etc/postfix
#RUN chown -R vmail:vmail /var/mail
#RUN chown -R vmail:dovecot /etc/dovecot
#RUN chmod -R o-rwx /etc/dovecot
#RUN	chmod 644 /etc/ssl/
#
## restart services
#RUN service restart postfix
#RUN service restart dovecot
#
#COPY scripts/* /usr/local/bin/
#
## add domain email
#RUN /usr/local/bin/add-domain.sh "$DOMAIN"
#
#EXPOSE 25 465 587 993 995