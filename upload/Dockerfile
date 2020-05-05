# build stage
FROM golang:1.14 AS build-env
ARG mega_version=1.10.3

ADD . /app/
WORKDIR /app
RUN go build -o app .

RUN apt-get update && apt-get install -y dovecot-core
ADD scripts /usr/bin/local/
RUN chmod +x /usr/bin/local/*

# install megatools
RUN apt-get update && apt-get install -y build-essential libglib2.0-dev libssl-dev libcurl4-openssl-dev wget tar
RUN wget https://megatools.megous.com/builds/megatools-$mega_version.tar.gz
RUN tar -xzf megatools-$mega_version.tar.gz
RUN bash megatools-$mega_version/configure --disable-docs
RUN make -j4
RUN make install
RUN rm -rf megatools*

CMD ["/app/app"]