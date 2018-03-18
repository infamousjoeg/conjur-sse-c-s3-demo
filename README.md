# Conjur SSE S3 Demo

## Development

1. Write a simple policy with a layer (group of hosts) that has read & execute privileges to a variable (secret).
2. Generate and upload an AES256 key to the variable.
3. Start two containers, both with AWS CLI installed.  These containers are dynamically added to the layer created in Step 1.
4. Upload a file from the first container to S3 along with the AES256 key to use for encrypting the object:
```
summon --yaml 'AES_KEY: !var:file /path/to/variable' aws s3 cp /path/to/localfile s3://mybucket --sse-c-key $AES_KEY
```
5. Download the file from the other container:
```
summon --yaml 'AES_KEY: !var:file /path/to/variable' aws s3 cp s3://mybucket/localfile /path/to/download --sse-c3-key $AES_KEY
```