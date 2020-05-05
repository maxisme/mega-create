FROM tvial/docker-mailserver

ARG mega_version=1.10.3

# install megatools on top of mailserver
RUN apt-get update && apt-get install -y build-essential libglib2.0-dev libssl-dev libcurl4-openssl-dev wget
RUN wget https://megatools.megous.com/builds/megatools-$mega_version.tar.gz
RUN tar -xzf megatools-$mega_version.tar.gz
RUN bash megatools-$mega_version/configure --disable-docs
RUN make
RUN make install
RUN rm -rf megatools*

ADD scripts/mega-create.sh /usr/local/bin/mega-create.sh

CMD supervisord -c /etc/supervisor/supervisord.conf