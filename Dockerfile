FROM tvial/docker-mailserver

# install megatools on top of mailserver
RUN apt-get update && apt-get install -y build-essential libglib2.0-dev libssl-dev libcurl4-openssl-dev wget ssh
RUN wget https://megatools.megous.com/builds/megatools-1.10.2.tar.gz
RUN tar -xzf megatools-1.10.2.tar.gz
RUN bash megatools-1.10.2/configure --disable-docs
RUN make
RUN make install

# create jailed ssh user
RUN useradd megajail
RUN mkdir -p /home/megajail/.ssh
RUN echo "Match User megajail \
    ChrootDirectory /home/megajail" >> /etc/ssh/sshd_config
COPY .ssh/authorized_keys /home/megajail/.ssh/authorized_keys
RUN service ssh restart

# clean up
RUN rm -rf megatools*

COPY scripts/mega-create.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/mega-create.sh
