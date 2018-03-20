FROM alpine:3.6

RUN apk update && apk upgrade && apk --update add --no-cache \
    jq \
    ruby-dev \
    ruby-bundler \
    ruby-rdoc \
    ruby-irb \
    ruby-bigdecimal \
    g++ \
    make \
    bash \
    ca-certificates

RUN echo 'root:Cyberark1' | chpasswd

RUN gem install conjur-cli -v 5.6.5

ENTRYPOINT [ "/bin/sh", "-c", "sleep 100000000" ]