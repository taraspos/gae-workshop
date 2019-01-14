# Level 2 - Add TLS protection

## Install CFSSL

Run `go get -u github.com/cloudflare/cfssl/cmd/cfssl` and `go get -u github.com/cloudflare/cfssl/cmd/cfssljson`

## Generate self signed SSL certs

Set the env variable with the ip of your server (same as in `app.yml`):
`export SERVER_IP=<Server static IP>`

Copy the content of [create-certs.sh](./create-certs.sh) to your
Cloud Shell or local environment as `create-certs.sh` and run it
with `bash create-certs.sh`

## Upload the certificates to storage bucket

Think of unique storage bucket name and run `export GS_BUCKET=gs://<unique bucket name>`

Create this bucket with command: `gsutil mb $GS_BUCKET`
Copy the certificates into the bucket: `gsutil cp cfssl/*.pem $GS_BUCKET`

## Give Read Only access to the bucket for our server

Modify the resource `google_compute_instance` in the `server.tf` file, adding next lines into the code block:

```tf
  service_account {
    scopes = ["storage-ro"]
  }
```

## Download the certificates

Add new systemd unit to the `cloud-config.yaml` file which will download the certificates from the bucket:

```yml
- name: cfssl-download.service
  command: start
  content: |
    [Unit]
    Description=Download the server certificates from storage bucket
    Before=traefik.service

    [Service]
    Type=oneshot
    ExecStartPre=/usr/bin/docker pull google/cloud-sdk:alpine
    ExecStart=/bin/bash -c \
                '/usr/bin/docker run --rm --name cfssl-lodwnload \
                          -v /etc/cfssl:/etc/cfssl \
                            google/cloud-sdk:alpine gsutil cp gs://<bucket_name>/{ca,server}* /etc/cfssl'
    RemainAfterExit=true
    StandardOutput=journal
```

## Make traefik read the certificates

Now you need to update traefik configurations to read  the certificats:

```sh
ExecStart=/usr/bin/docker run --rm --name traefik \
                              -v /var/run/docker.sock:/var/run/docker.sock \
                              -v /etc/cfssl:/etc/cfssl:ro \
                              -p 80:80 \
                              -p 443:443 \
                              -p 8080:8080 \
                                 traefik \
                                    --api --docker \
                                    --entryPoints='Name:http  Address::80  Redirect.EntryPoint:https' \
                                    --entryPoints='Name:https Address::443 TLS:/etc/cfssl/server.pem,/etc/cfssl/server-key.pem CA:/etc/cfssl/ca.pem'
```

To open 443 port in firewall, change line `ports    = ["80"]` in the `server.tf` to `ports    = ["80", "443"]`

## Update entrypoint for the `whoami` container

Add more more labels for the `whoami` container start command in the `cloud-config.yaml`

```sh
--label traefik.frontend.entryPoints=http,https \
--label traefik.frontend.redirect.entryPoint=https \
```

## Apply the changes

In order to apply the changes to our server, we will need to recreate it,
to do so, we need to mark it to be destroyed on the next run:

```tf
terraform taint  google_compute_instance.workshop-server
```

Now we can apply the the changes with `terraform apply`

## Modify the app code, to do the req with client cert

First, we need to update our `.gcloudignore` file, to ignore the not needed certificats, to do so, add next two lines:

```sh
cfssl/*
!cfssl/*client*.pem
```

This configuration will make sure, that only `client.pem` and `client-key.pem` included into code package.

Then, modify the app code, to perform **TLS Mutual Auth** request to out TLS protected webserver. To do so update next code parts:

1. Add new import "crypto/tls"

1. Create custom http client:

    ```go
    var client = &http.Client{}

    func init() {
        cert, err := tls.LoadX509KeyPair("cfssl/client.pem", "cfssl/client-key.pem")
        if err != nil {
            log.Fatal(err)
        }

        client.Transport = &http.Transport{
            TLSClientConfig: &tls.Config{
                InsecureSkipVerify: true,
                Certificates:       []tls.Certificate{cert},
            },
        }
    }
    ```

1. Replace default http client, with custom one, to do so, replace line: `rs, err := http.Get(hostEndpoint)` with `rs, err := client.Get(hostEndpoint)`

Deploy the new app version with `gcloud app deploy`.

## Verifying

TODO:

Try opening the `/whoami` url in your browser

Try opening the `/demo` url in your browser