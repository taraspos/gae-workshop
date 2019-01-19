# Level 1 - Provision an webserver and ping it from GAE

## 1.0 - Configure Terraform

> **Why [Terraform](https://www.terraform.io) ❓**

> Because in the real world, no-one provisions the infrastructure by clicking in the WebConsole.
> Defining infrastructure as code is always a good practice and we love good practices. Also, it can be used as documentation later as well as reused.

To start, we will neeed to generate credentials to be used with Terraform:

- Open [Google Cloud Shell](https://console.cloud.google.com/appengine?cloudshell=true&_ga=2.219504537.-1092609672.1545216569)

    - Change directory to the go-app/ created in the [Level 0](https://cloud.google.com/appengine/docs/standard/go111/building-app/) and export your project id as a variable  
    `cd go-app/`    
    `export PROJECT_ID=<YOUR PROJECT ID>`   
    - Create service user for terraform:   
     `gcloud iam service-accounts create terraform --display-name "Terraform admin account"`   
    - Create `terraform.json` key    
      `gcloud iam service-accounts keys create terraform.json --iam-account terraform@${PROJECT_ID}.iam.gserviceaccount.com`
    - Grant owner permissions to a service account for the Project:    
      `gcloud projects add-iam-policy-binding ${PROJECT_ID} --member serviceAccount:terraform@${PROJECT_ID}.iam.gserviceaccount.com --role roles/owner`

    **Terraform is not installed in the Cloud Shell environment ([official installation guide](https://www.terraform.io/intro/getting-started/install.html)), consider using [Cloud Shell editor](https://cloud.google.com/shell/docs/features#code_editor) to edit `.tf`, `.go` and `.yaml` files (which is very similar to Visual Studio Code), or you can use console based text editors like `vim`, `emacs` or `nano`.**
    
    - Download and unzip terraform in Cloud Shell:          
    `wget https://releases.hashicorp.com/terraform/0.11.11/terraform_0.11.11_linux_amd64.zip && unzip terraform_0.11.11_linux_amd64.zip`

- Create `server.tf` file and put folliwing lines in there replacing placeholders within `<PATH TO YOUR JSON FILE>` and `<YOUR PROJECT ID>` with actual values
    ```hcl
    provider "google" {
        credentials = "${file("<PATH TO YOUR JSON FILE>")}"
        project     = "<YOUR PROJECT ID>"
        region      = "us-central1"
    }
    ```

## 1.1 Create provision script for our future server

We will use [CoreOS](https://coreos.com/why/) based server, and we are going to provision it with [cloud-config](https://coreos.com/os/docs/latest/cloud-config.html).

> **Why [CoreOS](https://coreos.com/why/) ❓**

> Mostly for demonstration purpose. Everybody used CentOS or Ubuntu.
> And it is completely, from bottom to top, about containers. And we will use containers in this workshop! 

> **Why [Cloud-Config](https://coreos.com/os/docs/latest/cloud-config.html) ❓**

> Because it is the simplest way to provision the cloud native Linux server, especially CoreOS.
> This is still real world, ofcourse we are not going to SSH into the server and do the configurations manually 🤢

_Note: Cloud-Config is deprecated in favor of [Ignition](https://coreos.com/ignition/docs/latest/), however in this workshop we will stick to Cloud-Config, since it is easier to understand._

For demonstration purposes we will use [Traefik](https://traefik.io/) and [whoami demo app](https://github.com/containous/whoami).

> **Why [Traefik](https://traefik.io/) ❓**

> Traefik is container and cloud native reverse proxy and loadbalancer
> with nice dashboard and awesome features (like reading configurations from docker labels and other features we will useer in Level 2)

CoreOS is SystemD based distribution, so we will run this tools as Docker containers managed by SystemD units.

First, create `cloud-config.yaml` file, add next lines:

```yaml
#cloud-config

coreos:
    units:
```

Then, add `whoami` unit configurations (append it to the `cloud-config.yaml` file):

```yaml
      - name: whoami.service
        command: start
        content: |
          [Unit]
          Description=Whoami API
          After=docker.service
          Requires=docker.service

          [Service]
          TimeoutStartSec=0
          Restart=always
          ExecStartPre=-/usr/bin/docker kill whoami
          ExecStartPre=-/usr/bin/docker rm whoami
          ExecStartPre=/usr/bin/docker pull containous/whoami
          ExecStart=/usr/bin/docker run --rm --name whoami \
                                        --label traefik.frontend.rule=Path:/whoami \
                                          containous/whoami
          ExecStop=/usr/bin/docker stop whoami
```

_where `--label traefik.frontend.rule=Path:/whoami` is traefik configuration, which tells that traffic
coming to HTTP path `/whoami` will be forwarded to the `whoami` container._

and `traefik` unit as well  (append it to the `cloud-config.yaml` file):

```yaml
      - name: traefik.service
        command: start
        content: |
          [Unit]
          Description=Traefik Container
          After=docker.service
          Requires=docker.service

          [Service]
          TimeoutStartSec=0
          Restart=always
          ExecStartPre=-/usr/bin/docker kill traefik
          ExecStartPre=-/usr/bin/docker rm traefik
          ExecStartPre=/usr/bin/docker pull traefik
          ExecStart=/usr/bin/docker run --rm --name traefik \
                                        -v /var/run/docker.sock:/var/run/docker.sock \
                                        -p 80:80 \
                                        -p 8080:8080 \
                                          traefik --api --docker
          ExecStop=/usr/bin/docker stop traefik
```

**Be carefull with indents! This is YAML, [indents are important](https://www.reddit.com/r/ProgrammerHumor/comments/9fhvyl/writing_yaml/)**

## 1.2 Now we need a ~~server~~ public IP address

Thing is, GAE Standard environment (free one) can't access your resources by it's private IP, so we will need a static public one (we could use DNS name instead, but to do that, we would need to buy domain). 

Append following code to our `server.tf` file

```hcl
resource "google_compute_address" "workshop-static-ip" {
  name = "workshop-static-ip"
  network_tier = "STANDARD"
  address_type = "EXTERNAL"
}
```

## 1.3 Now we need a server 

In the following code replace `<PATH TO CLOUD-CONFIG>` placeholder with real value and append to the `server.tf` file

```hcl
resource "google_compute_instance" "workshop-server" {
  name         = "workshop-server"
  machine_type = "f1-micro"
  zone         = "us-central1-a"
  description  = "Server for GDG Cloud Lviv workshop!"

  tags = ["api"]

  boot_disk {
    initialize_params {
      image = "family/coreos-stable"
      size = 30
      type = "pd-standard"
    }
  }

  network_interface {
    network = "default"

    access_config {
        network_tier = "STANDARD"
        nat_ip = "${google_compute_address.workshop-static-ip.address}"
    }
  }

  metadata {
    user-data = "${file("<PATH TO CLOUD-CONFIG>")}"
  }
}
```

### 1.4 Wide open 80 port on Firewall

GCP doesn't provide a way to allow traffic only from GAE environment and since it has dynamic IPs
we neeed to wide open port 80, to be able access our services from local machine and GAE Enironment.

```hcl
resource "google_compute_firewall" "api" {
  name    = "api"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
}
```

### 1.5 Open port 8080 for our IP only

Traefik serves its dashboard on port 8080, we don't need to access it from our GAE but having access from local machine would be useful.
So lets open firewall access from our current public IP only.

Go to https://ifconfig.me/ or do `curl ifconfig.me` to find your public ip and put it instead of `<MY PUBLIC IP>` placeholder

```hcl
resource "google_compute_firewall" "traefik" {
  name    = "traefik"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }

  source_ranges = ["<MY PUBLIC IP>/32"]
}
```

### 1.6 Apply our infrastructure as code definitions

Run `terraform init` and `terraform apply` (or `./terraform` in go-app/ directory, if the binary not in your `PATH`), find the generated Static Public IP address (somewhere in the output of previous command) and save it for later, we will need it.

Try opening next URLs:
- `<STATIC PUBLIC IP>:8080`        - you should see the Traefik dashboard here
- `<STATIC PUBLIC IP>:80/whoami`   - you should see details of your requests, provided by whoami demo app.

### 1.7 Modify our app code, to do the request to our deployed server

We don't want deploy our credentials and not releant files with our app code.
To avoid packaging them, we need to create `.gcloudignore` (if not present) file and put there following glob patterns:

```
*terraform*
*.tf
cloud-config.yaml
*.json
```

Append to the `app.yaml` file next configurations (do not forget to replace placeholder `<STATIC_PUBLIC_IP>` with actual value):

```yaml
env_variables:
  HOST_ENDPOINT: http://<STATIC_PUBLIC_IP>:80
```

Now we want our app to communicate with our server (do the request to the `/whoami` endpoint from GAE environment)

To do that we need to create new HTTP handler with all the acutal logic to the `main.go` file.
We need to start by adding `"io/ioutil"` to the list of imports and following handler function:

```go
// demoHandler sends request to our HOST_ENDPOINT, and responses with received response
func demoHandler(w http.ResponseWriter, r *http.Request) {
  hostEndpoint := os.Getenv("HOST_ENDPOINT")
  if hostEndpoint == "" {
    log.Fatal("HOST_ENDPOINT env variable not provided")
  }

  hostEndpoint += "/whoami"

  rs, err := http.Get(hostEndpoint)
  if err != nil {
    log.Fatal(err)
  }

  defer rs.Body.Close()

  bodyBytes, err := ioutil.ReadAll(rs.Body)
  if err != nil {
    log.Fatal(err)
  }

  bodyString := string(bodyBytes)
  fmt.Fprintf(w, "We got a response form %s!\nResponse body:\n%s", hostEndpoint, bodyString)
}
```

Now we want this logic to be excuted when we go to the `/demo` path of our app.
This will require following routing rule on beginning of `func main()`:

```go
  http.HandleFunc("/demo", demoHandler)
```

Deploy the updated app code with `gcloud app deploy` and open the `<APP_URL>/demo` (_To find out `APP_URL` you can call `gcloud app browse`_).

You should see the similar results as you did on URL `<STATIC PUBLIC IP>:80/whoami`.

Done? Now it's going to get interesting! 

## [Click here to open LEVEL 2](../level2/README.md)
