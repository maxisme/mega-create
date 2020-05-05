FROM alpine
ARG mega_version=1.10.3

# install dovecot
RUN apk add --update dovecot
#COPY dovecot/dovecot.conf /etc/dovecot/dovecot.conf

# install megatools
RUN apk add --update build-base libcurl curl-dev openssl-dev glib-dev glib libtool automake autoconf wget tar
RUN wget https://megatools.megous.com/builds/megatools-$mega_version.tar.gz
RUN tar -xzf megatools-$mega_version.tar.gz
RUN bash megatools-$mega_version/configure --disable-docs
RUN make -j4
RUN make install
RUN rm -rf megatools*

ADD scripts/* /usr/local/bin/
RUN chmod +x /usr/local/bin/*

CMD ["/usr/sbin/dovecot", "-F"]