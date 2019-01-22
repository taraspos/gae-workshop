# gae-workshop

This workshop guides you through the process of creating a simple and completely free backend on Google Cloud Platform, utilizing only [always free](https://cloud.google.com/free/) resources, along with configuration of [TLS Mutual Authentication](https://medium.com/sitewards/the-magic-of-tls-x509-and-mutual-authentication-explained-b2162dec4401) betweeen Google App Engine application and Google Compute Engine server.

<details><summary>Diagram HERE</summary>
<p>

![diagram](./gae-workshop-diagram.png)

</p>
</details>

## Prerequisites

Start by following the steps in [Google Cloud Shell](https://console.cloud.google.com/appengine?cloudshell=true&_ga=2.219504537.-1092609672.1545216569), since it will give you a pre-configured environment with most of the tools you'll need.

On [Google Cloud Shell](https://console.cloud.google.com/appengine?cloudshell=true&_ga=2.219504537.-1092609672.1545216569), you will be prompted to create a new project (if you don't have any). Do so and you can skip *Creating a GCP project* in [Level 0](https://cloud.google.com/appengine/docs/standard/go111/building-app/).

If you already have a GCP project, better to create a new one for this workshop so you can safely remove it afterwards.


## [Level 0](https://cloud.google.com/appengine/docs/standard/go111/building-app/)

There are two types of App Engine environments:
- Standard
- Flexible

We will be using **App Engine Standard Environment**. More information about environment types [here](https://cloud.google.com/appengine/docs/the-appengine-environments).

Go through the official guide [Building a Go App on App Engine](https://cloud.google.com/appengine/docs/standard/go111/building-app/)!

**Note**: Using `us-central` region.
Also, you need to enable Google Cloud APIs to be able to run deploy via 
`gcloud app deploy` command:

- Google Cloud Build API `gcloud services enable cloudbuild.googleapis.com`
- Google Compute Engine API `gcloud services enable compute.googleapis.com`

**Note**: After finishing the official tutorial, proceed to [Level 1](./level1/README.md), **not** to the Next Steps page.

## [Level 1](./level1/README.md)

Deploy and provision a simple webserver with terraform, then access it from the GAE app.

## [Level 2](./level2/README.md)

Secure the connection between app and server with [TLS Mutual Authentication](https://medium.com/sitewards/the-magic-of-tls-x509-and-mutual-authentication-explained-b2162dec4401).
