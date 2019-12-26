FROM tvial/docker-mailserver

# install megatools
RUN apt-get update && apt-get install -y build-essential libglib2.0-dev libssl-dev libcurl4-openssl-dev wget
RUN wget https://megatools.megous.com/builds/megatools-1.10.2.tar.gz
RUN zcat megatools-1.10.2.tar.gz > megatools.tar
RUN tar -xf megatools.tar
RUN bash megatools-1.10.2/configure --disable-docs
RUN make
RUN make install

# clean up
RUN rm -rf megatools*

COPY scripts/mega-create.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/mega-create.sh
