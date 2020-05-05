FROM alpine
ARG mega_version=1.10.3

# install megatools
RUN apk add --update build-base libcurl curl-dev openssl-dev glib-dev glib libtool automake autoconf wget tar
RUN wget https://megatools.megous.com/builds/megatools-$mega_version.tar.gz
RUN tar -xzf megatools-$mega_version.tar.gz
RUN bash megatools-$mega_version/configure --disable-docs
RUN make -j4
RUN make install
RUN rm -rf megatools*

# install email stuff
RUN apk add --update dovecot postfix supervisor

ADD scripts/* /usr/local/bin/
ADD dovecot/* /etc/dovecot/conf.d/
ADD postfix/master.cf /etc/postfix/
RUN chmod +x /usr/local/bin/*

ADD postfix/install.sh /install.sh
RUN /install.sh
CMD /usr/bin/supervisord -c /etc/supervisor/supervisord.conf