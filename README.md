# Conjur SSE-C S3 Demo

![GitHub (pre-)release](https://img.shields.io/github/release/infamousjoeg/conjur-sse-c-s3-demo/all.svg)
 [![GitHub issues](https://img.shields.io/github/issues/infamousjoeg/conjur-sse-c-s3-demo.svg)](https://github.com/infamousjoeg/conjur-sse-c-s3-demo/issues)
 [![GitHub license](https://img.shields.io/github/license/infamousjoeg/conjur-sse-c-s3-demo.svg)](https://github.com/infamousjoeg/conjur-sse-c-s3-demo/blob/master/LICENSE)

Demonstrating upload and download of an object to an [AWS S3](https://docs.aws.amazon.com/AmazonS3/latest/dev/Welcome.html) bucket that is encrypted/decrypted utilizing a [customer-provided AES256 key](https://docs.aws.amazon.com/AmazonS3/latest/dev/ServerSideEncryptionCustomerKeys.html) that is securely stored and retrieved from [CyberArk Conjur](https://conjur.org).

* [Conjur SSE-C S3 Demo](#conjur-sse-c-s3-demo)
    * [Pre-Requisites](#pre-requisites)
        * [Docker Quick Start](#docker-quick-start)
    * [Video Demonstration](#video-demonstration)
    * [Detailed Demo Walkthrough](#detailed-demo-walkthrough)
        * [./0-start.sh](#0-startsh)
        * [./1-upload.sh](#1-uploadsh)
            * [Ansible Playbook - s3-sse-c-upload.yml](#ansible-playbook---s3-sse-c-uploadyml)
        * [AWS S3 Objects Uploaded](#aws-s3-objects-uploaded)
        * [./2-download.sh](#2-downloadsh)
            * [Ansible Playbook - s3-sse-c-download.yml](#ansible-playbook---s3-sse-c-downloadyml)
        * [AWS S3 Objects Downloaded](#aws-s3-objects-downloaded)
        * [./3-clean.sh](#3-cleansh)
    * [Policy Walkthrough - aws-sse-c-policy.yml](#policy-walkthrough---aws-sse-c-policyyml)

## Pre-Requisites

* Docker CE
    * To easily install Docker CE on Linux:
    ```shell
    $ curl -fsSL http://get.docker.com -o get-docker.sh && ./get-docker.sh
    ```
    * You will have to add yourself to the Docker group & refresh:
    ```shell
    $ sudo usermod -aG docker $USERNAME
    $ newgrp docker
    ```
* Docker Compose
    * To easily install Docker Compose on Linux:
    ```shell
    $ sudo curl -L https://github.com/docker/compose/releases/download/1.18.0/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
    $ sudo chmod +x /usr/local/bin/docker-compose
    ```

* CyberArk Conjur v4 Enterprise Edition Docker Image
    * If you have ConjurOps v2 credentials:
    ```shell
    $ docker login -u $CONJUROPS_USERNAME https://registry2.itci.conjur.net
    $ docker pull registry2.itci.conjur.net/conjur-appliance:4.9-stable
    ```

### Docker Quick Start

To super duper easily install both Docker Community Edition (CE) and Docker Compose on Ubuntu all at once, you can run this script:
```shell
$ sudo ./_deps.sh
```

## Video Demonstration

[![asciicast](https://asciinema.org/a/171634.png)](https://asciinema.org/a/171634)

## Detailed Demo Walkthrough

```shell
$ git clone https://github.com/infamousjoeg/conjur-sse-c-s3-demo.git
$ cd conjur-sse-c-s3-demo
```

### ./0-start.sh

This script brings up and configures a Conjur Master in the local Docker host.

```shell
$ docker-compose up -d conjur
$ docker exec conjur-master \
    evoke configure master -h conjur-master -p Cyberark1 demo
```

The configured Conjur Master's public key certificate is copied to a freshly created ./certs directory.

```shell
$ mkdir certs
$ docker cp conjur-master:/opt/conjur/etc/ssl/ca.pem ./certs/ca.crt
$ openssl x509 -in ./certs/ca.pem -inform PEM -out ./certs/ca.crt
```

After a healthy Conjur Master is detected, Conjur is logged into via CLI and the Policy plugin is installed.

**In a real world scenario, the following steps would be done manually by a Security Admin -- Conjur's equivalent to a CyberArk Vault Admin.**

**These steps have been automated for the sake of this demonstration.**

After logging in as `admin`, we need to install the `policy` plugin

```shell
$ docker exec conjur-master /bin/bash -c "
    conjur authn login -u admin -p Cyberark1
    conjur plugin install policy
    conjur policy load --as-group security_admin /src/policies/aws-sse-c-policy.yml
    conjur variable values add aws-sse-c/aws-s3/aes256_key $(openssl rand -hex 16)
    conjur variable values add aws-sse-c/aws-iam/access_key_id $AWS_ACCESS_KEY_ID
    conjur variable values add aws-sse-c/aws-iam/secret_access_key $AWS_SECRET_ACCESS_KEY
"
```

Finally, we pre-build the Docker image our S3-Workers will use to upload and download our [HIPAA Authorization PDF](assets/hipaa-authorization.pdf) to AWS S3 both encrypted and unencrypted.

The [S3-Worker Docker image](build/ansible/Dockerfile) is an Ubuntu based container with Ansible installed during build.  It is built to run Ansible Playbooks ephemerally, whether remote or local.

```shell
$ docker-compose build s3-worker
```

### ./1-upload.sh

This script first generates a Host Factory token within Conjur to allow our S3-Uploader container to receive a trusted machine identity.

Using the Conjur CLI available on the Conjur Master, we create a Host Factory token from our `s3-workers_factory` that is associated with the `s3-workers` layer that is established in our previously loaded [Conjur Policy](policies/aws-sse-c-policy.yml).

```shell
$ output=$(docker exec conjur-master conjur hostfactory tokens create --duration-minutes 1 aws-sse-c/s3-workers_factory  | jq -r '.[0].token')

$ hf_token=$(echo "$output" | tail -1 | tr -d '\r')
```

Now that the Host Factory token has been generated with a one (1) minute time-to-live (TTL), the S3-Uploader container can be run.  But first, we need to get the AWS Access Key ID and AWS Secret Access Key from within Conjur.

```shell
$ AWS_ACCESS_KEY_ID=$(docker exec conjur-master conjur variable value aws-sse-c/aws-iam/access_key_id)
$ AWS_SECRET_ACCESS_KEY=$(docker exec conjur-master conjur variable value aws-sse-c/aws-iam/secret_access_key)
```

Finally, we can start up the S3-Uploader container as ephemeral `--rm` and provide it the relevant variables for the [CyberArk.Conjur-Host-Identity Ansible Role](https://galaxy.ansible.com/cyberark/conjur-host-identity/) and the [SSILab.AWS-CLI Ansible Role](https://galaxy.ansible.com/ssilab/aws-cli/) to work properly.

Within the container, we are going to set the Conjur Master's hostname into `/etc/hosts`, install the two (2) aforementioned Ansible Roles from [Ansible Galaxy](https://galaxy.ansible.com), and then start up our [s3-sse-c-upload.yml](playbooks/s3-sse-c-upload.yml) Ansible Playbook.

```shell
$ docker-compose run --rm --name s3-uploader \
  -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
  -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
  -e AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION \
  -e CONJUR_MAJOR_VERSION=4 \
  s3-worker bash -c "
    echo '192.168.3.10 conjur-master' >> /etc/hosts
    ansible-galaxy install cyberark.conjur-host-identity
    ansible-galaxy install ssilab.aws-cli
    HFTOKEN=$hf_token ansible-playbook -i \"localhost,\" -c local /src/playbooks/s3-sse-c-upload.yml
  "
```

After the Ansible Playbook completes running, the S3-Uploader Docker container disappears.

#### Ansible Playbook - s3-sse-c-upload.yml

In this Playbook, we start off by installing two (2) Roles.  The first is CyberArk's very own Conjur-Host-Identity role.  It is very straight-forward in it's configuration requirements.

The `$HFTOKEN` variable that is looked up using the Environment Variable lookup module is giving during the run of the Playbook.  You'll also notice the use of the File lookup module to get the Conjur Master's public key certificate that was created during [0-start.sh](0-start.sh) for proper validation.

```yaml
- role: cyberark.conjur-host-identity
    conjur_appliance_url: 'https://conjur-master/api'
    conjur_account: 'demo'
    conjur_host_factory_token: '{{ lookup("env", "HFTOKEN") }}'
    conjur_host_name: 's3-uploader'
    conjur_ssl_certificate: '{{ lookup("file", "/src/certs/ca.crt") }}'
    conjur_validate_certs: true
```

The second Role that is installed via this Playbook is SSILab's AWS-CLI.  It simply needs to know a default region for AWS to target, an AWS Access Key ID, and an AWS Secret Access Key with proper permissions to do it's job.

I setup an AWS Access Key that only has permission to the specific AWS S3 bucket that is used in this demonstration and I rotate frequently as a best practice.

```yaml
- role: ssilab.aws-cli
    aws_output_format: 'json'
    aws_region: '{{ lookup("env", "AWS_DEFAULT_REGION") }}'
    aws_access_key_id: '{{ lookup("env", "AWS_ACCESS_KEY_ID") }}'
    aws_secret_access_key: '{{ lookup("env", "AWS_SECRET_ACCESS_KEY") }}'
```

Finally, we have our tasks.  I'll break them down one-by-one:

The first task is just to upload the HIPAA Authorization Form unencrypted to prove that we can at least do that.

```yaml
- name: Upload HIPAA Authorization Form to AWS S3 unencrypted
  shell: "aws s3 cp /src/assets/hipaa-authorization.pdf s3://conjur-sse-c-s3-demo/hipaa-authorization-unencrypted.pdf"
```

Second and third go hand-in-hand, a quick Summon test is run to pull the AES256 Key and print the debug JSON response returned to prove out the methods.

**In a real world scenario, this would never be done except in DEV while troubleshooting/testing.**

```yaml
- name: Run Summon Test - Pull AES256 Key from Conjur
  shell: "summon --yaml 'AES_KEY: !var aws-sse-c/aws-s3/aes256_key' printenv AES_KEY"
  register: aes256_key
- name: Show AES256 Key Returned Value from Conjur
  debug:
    var: aes256_key
```

Finally, the star of the show!  Uploading the HIPAA Authorization Form using an AES256 Key that is fetched on-demand from Conjur and injected into the `bash` process as an Environment Variable by [Summon](https://cyberark.github.io/summon).

```yaml
- name: Upload HIPAA Authorization Form to AWS S3 encrypted w/ AES256 Key (SSE-C)
  shell: "summon --yaml 'AES_KEY: !var aws-sse-c/aws-s3/aes256_key' bash -c 'aws s3 cp /src/assets/hipaa-authorization.pdf s3://conjur-sse-c-s3-demo/hipaa-authorization-AES256.pdf --sse-c AES256 --sse-c-key $AES_KEY'"
```

### AWS S3 Objects Uploaded

At this point, the [hipaa-authorization.pdf](assets/hipaa-authorization.pdf) has been uploaded twice to the `s3://conjur-sse-c-s3-demo` S3 bucket.  Once unencrypted and a second time encrypted using the Conjur-provided AES256 key.

Use this time to show how one is accessible and readable while the encrypted one is not without the proper AES256 key to decrypt.

### ./2-download.sh

This script is a spitting mirror image of [1-upload.sh](1-upload.sh) in the sense that it grabs a Host Factory token in the same manner and also the AWS Access Key ID and Secret Access Key from Conjur via CLI.

The difference comes in the Ansible Playbook that is run in this script as detailed in the below Docker `run` command:

```shell
$ docker-compose run --rm --name s3-downloader \
  -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
  -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
  -e AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION \
  -e CONJUR_MAJOR_VERSION=4 \
  s3-worker bash -c "
    echo '192.168.3.10 conjur-master' >> /etc/hosts
    ansible-galaxy install cyberark.conjur-host-identity
    ansible-galaxy install ssilab.aws-cli
    HFTOKEN=$hf_token ansible-playbook -i \"localhost,\" -c local /src/playbooks/s3-sse-c-download.yml
  "
```

#### Ansible Playbook - s3-sse-c-download.yml

As with the previous section, this also doesn't undergo any changes with the exception of the order in which we provide input and output paths to the `aws s3 cp` command:

```yaml
tasks:
  - name: Download HIPAA Authorization Form from AWS S3 unencrypted
    shell: "aws s3 cp s3://conjur-sse-c-s3-demo/hipaa-authorization-unencrypted.pdf /src/assets/downloads/"
  - name: Run Summon Test - Pull AES256 Key from Conjur
    shell: "summon --yaml 'AES_KEY: !var aws-sse-c/aws-s3/aes256_key' printenv AES_KEY"
    register: aes256_key
  - name: Show AES256 Key Returned Value from Conjur
    debug:
      var: aes256_key
  - name: Download HIPAA Authorization Form from AWS S3 decrypted w/ AES256 Key (SSE-C)
    shell: "summon --yaml 'AES_KEY: !var aws-sse-c/aws-s3/aes256_key' bash -c 'aws s3 cp s3://conjur-sse-c-s3-demo/hipaa-authorization-AES256.pdf /src/assets/downloads/ --sse-c AES256 --sse-c-key $AES_KEY'"
```

### AWS S3 Objects Downloaded

Finally, we taken what was uploaded previously, both unencrypted and encrypted versions of our HIPAA Authorization PDF, and downloaded it locally to `./assets/downloads/`.

Both files should be readable as the one labeled AES256 was encrypted in AWS S3, but has since been decrypted using the same AES256 key from Conjur to be readable now.

### ./3-clean.sh

**This script will not prompt for permission!**

This will bring down the entire orchestrated demonstration!

```shell
$ docker-compose down --remove-orphans
$ rm -rf ./certs
$ rm -f ./playbooks/*.retry
$ rm -f ./assets/downloads/*.pdf
```

## Policy Walkthrough - aws-sse-c-policy.yml

The policy file that was created for this demonstration is a very straight-forward and simple one.

A policy with the id `aws-sse-c` is created along with the namespace for three (3) secrets:

* aws-s3/aes256_key
* aws-iam/access_key_id
* aws-iam/secret_access_key

```yaml
---
- !policy
  id: aws-sse-c
  body:
    - &keys
      - !variable aws-s3/aes256_key
      - !variable aws-iam/access_key_id
      - !variable aws-iam/secret_access_key
```

No secret values are stored or pushed as part of a policy file.  I do that as part of [0-start.sh](0-start.sh).  Therefore, it's safe for me to commit it to Source Control Management without worry as I did here: [policies/aws-sse-c-policy.yml](policies/aws-sse-c-policy.yml).

A Layer is created and named `s3-workers`.  This allows me to apply this policy there and dynamically enroll Hosts to be a member of that Layer (like nesting groups in Active Directory) and inherit the policy.  This allows us to scale out or in as needed without having to create and manage additional policies.

```yaml
    - !layer s3-workers
```

Since dynamic enrollment will be utilized, a Host Factory is established to generate nonforgeable tokens to allow entrance into the Layer by a Host when it is given back to our Conjur Master along with the public key certificate of our Master.

In this particular instance, a Host Factory named `s3-workers_factory` is created and associated with the `s3-workers` layer.  Any Host turning in a token generated from this Host Factory will allow entrance into the `s3-workers` layer only.

```yaml
    - !host-factory
      id: s3-workers_factory
      layers: [ !layer s3-workers ]
```

Finally, we can set our AuthZ (authorization).  We use the keywords `!permit` or `!deny` based on whether or not to permit a role privileges to a resource.

In this instance, the permitted role is our `s3-workers` Layer and the resource it is gaining privileges on is our `*keys` anchor that includes our three (3) previously defined secret namespaces.

```yaml
    - !permit
      role: !layer s3-workers
      privileges: [ read, execute ]
      resource: *keys
```

The policy as a whole isn't much and won't require any further modification unless additional Layers or Groups need access to the secrets established within this policy.

```yaml
---
- !policy
  id: aws-sse-c
  body:
    - &keys
      - !variable aws-s3/aes256_key
      - !variable aws-iam/access_key_id
      - !variable aws-iam/secret_access_key

    - !layer s3-workers

    - !host-factory
      id: s3-workers_factory
      layers: [ !layer s3-workers ]

    - !permit
      role: !layer s3-workers
      privileges: [ read, execute ]
      resource: *keys
```
