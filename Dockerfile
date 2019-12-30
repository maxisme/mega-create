FROM tvial/docker-mailserver

# install megatools on top of mailserver
RUN apt-get update && apt-get install -y build-essential libglib2.0-dev libssl-dev libcurl4-openssl-dev wget openssh-server
RUN wget https://megatools.megous.com/builds/megatools-1.10.2.tar.gz
RUN tar -xzf megatools-1.10.2.tar.gz
RUN bash megatools-1.10.2/configure --disable-docs
RUN make
RUN make install
RUN rm -rf megatools*

# create jailed ssh user
RUN mkdir /var/run/sshd
RUN echo -e "PermitRootLogin no\nPasswordAuthentication no\nPort 6622\n" >> /etc/ssh/sshd_config
RUN echo -e "Match User root\nForceCommand bash /usr/local/bin/mega-create.sh" >> /etc/ssh/sshd_config