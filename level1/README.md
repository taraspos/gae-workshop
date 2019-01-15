# Level 1 - Provision an webserver and ping it from GAE

## 1.0 - Configure Terraform

> **Why terraform ❓**

> Because in the real world, no-one provisions the infrastructure by clicking in the WebConsole.
> Defining infrastructure as code is always a good practice and we love good practices. Also, it can be used as documentation later as well as reused.

To start, we will neeed to generate credentials to be used with Terraform:

- As we started previously with `gloud` go to the [Google Cloud Shell](https://console.cloud.google.com/appengine?cloudshell=true&_ga=2.219504537.-1092609672.1545216569)

    - Change directory to the go-app/ created in the previous [Level 0](https://cloud.google.com/appengine/docs/standard/go111/building-app/) and export your project id as a variable  
    `cd go-app/`    
    `export PROJECT_ID=<YOUR PROJECT ID>`   
    - Create service user for terraform:   
     `gcloud iam service-accounts create terraform --display-name "Terraform admin account"`   
    - **Next**
    - Create Key -> **JSON**    
      `gcloud iam service-accounts keys create terraform.json --iam-account terraform@${PROJECT_ID}.iam.gserviceaccount.com`
    - **Next**
    - Grant owner permissions to a service account for the Project:    
      `gcloud projects add-iam-policy-binding ${PROJECT_ID} --member serviceAccount:terraform@${PROJECT_ID}.iam.gserviceaccount.com --role roles/owner`

    **Terraform is not installed in the Cloud Shell environment ([official installation guide](https://www.terraform.io/intro/getting-started/install.html)), so it is up to you where to perform this steps, Cloud Shell is still preffered, but you will need to use console based text editors like `vim`, `emacs`, `nano` or [Cloud Shell editor](https://cloud.google.com/shell/docs/features#code_editor) which is very similar to Visual Studio Code. If you can't use them, better stick to your laptop.**
    
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

> **Why CoreOS ❓**

> Mostly for demonstration purpose. Evverybody used CentOS or Ubuntu.
> And it is completely, from bottom to top, about containers. And we will use containers in this workshop! 

> **Why Cloud-Config ❓**

> Because it is the simplest way to provision the cloud native Linux server, especially CoreOS.
> This is still real world, ofcourse we are not going to SSH into the server and do the configurations manually 🤢

_Note: Cloud-Config is deprecated in favor of [Ignition](https://coreos.com/ignition/docs/latest/), however in this workshop we will stick to Cloud-Config, since it is easier to understand._

For demonstration purposes (and its amzing container native features!) we will use [Traefik](https://traefik.io/) and [whoami demo app](https://github.com/containous/whoami).

CoreOS is SystemD based distribution, so we will run this tools as Docker Container managed by SystemD units.

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

## 1.2 Now we need a ~~server~~ public IP address

Thing is, GAE Standard environment can't access your resources by it's private IP, so we will need a static public one (we could you DNS name instead, but to do that, we would need to buy domain). Append following code to our `server.tf` file

```hcl
resource "google_compute_address" "workshop-static-ip" {
  name = "workshop-static-ip"
  network_tier = "STANDARD"
  address_type = "EXTERNAL"
}
```

## 1.3 Now we need a server (replace `<PATH TO CLOUD-CONFIG>` placeholder with real value)

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

Go to https://ifconfig.me/ or do `curl ifconfig.me` to find your public ip and put it instead of `<MY PUBLIC IP` placeholder

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

Run `terraform init` and `terraform apply` (in Google Cloud Shell run `./terraform` in go-app/ directory), find the generated Static Public IP address and try opening it in the browser.

Try opening `<STATIC PUBLIC IP>:8080` and `<STATIC PUBLIC IP>:80` in the browser as well.

### 1.7 Modify our app code, to do the request to our deployed server

Create `.gcloudignore` (if not present) file and put there files not needed for our app to function:

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

Now we need to create new HTTP handler for our app, to do so, we will need to add
`"io/ioutil"` to the list of imports and write next handler code:

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

And add routing rule for our new handler at the begining of `func main()`:

```go
  http.HandleFunc("/demo", demoHandler)
```

Deploy the updated app with `gcloud app deploy` and open the `<APP_URL>/demo`, to find out `APP_URL` you can call `gcloud app browse`
