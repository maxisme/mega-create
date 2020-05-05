#!/bin/bash

#supervisor
mkdir -p /etc/supervisor /var/log/supervisor
touch /etc/supervisor/supervisord.conf

cat >  /etc/supervisor/supervisord.conf <<EOF
[supervisord]
logfile=/tmp/supervisord.log
nodaemon=true

[program:postfix]
process_name=master
directory=/etc/postfix
command=/usr/sbin/postfix start
startsecs=0
autorestart=false
stdout_logfile=/var/log/supervisor/%(program_name)s.log
stderr_logfile=/var/log/supervisor/%(program_name)s.log

[program:dovecot]
command=/usr/sbin/dovecot -c /etc/dovecot/dovecot.conf -F
autorestart=true
stdout_logfile=/var/log/supervisor/%(program_name)s.log
stderr_logfile=/var/log/supervisor/%(program_name)s.log
EOF

############
#  postfix
############
cat >> /opt/postfix.sh <<EOF
#!/bin/bash
service postfix start
tail -f /var/log/mail.log
EOF
chmod +x /opt/postfix.sh
postconf -e myhostname=$maildomain
postconf -e "mydestination = $maildomain, $HOSTNAME, localhost.localdomain, localhost"
postconf -e 'smtpd_sasl_type = dovecot'
postconf -e 'smtpd_sasl_auth_enable = yes'
postconf -e 'smtpd_recipient_restrictions = permit_sasl_authenticated,permit_mynetworks,reject_unauth_destination'
postconf -e 'smtpd_sasl_path = private/auth'
postconf -e message_size_limit=52428800
