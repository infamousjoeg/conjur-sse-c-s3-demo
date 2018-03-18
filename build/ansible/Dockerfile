FROM ubuntu:latest

RUN apt-get update && apt-get install -y \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    curl

RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -

RUN add-apt-repository \
    "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) \
    stable"

RUN apt-add-repository ppa:ansible/ansible

RUN apt-get update && apt-get install -y ansible docker-ce python-pip

RUN pip install --upgrade pip && pip install docker