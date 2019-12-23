FROM tvial/docker-mailserver

RUN apt-get update && apt-get install -y build-essential libglib2.0-dev libssl-dev libcurl4-openssl-dev wget asciidoc
RUN wget https://megatools.megous.com/builds/megatools-1.10.2.tar.gz
RUN zcat megatools-1.10.2.tar.gz > megatools.tar
RUN tar -xf megatools.tar
RUN bash megatools-1.10.2/configure
RUN make
RUN make install

COPY scripts/* /usr/local/bin/

# clean up
RUN rm -rf megatools*