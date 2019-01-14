# gae-workshop

GDG Cloud Lviv workshop for Google App Engine

## Prerequisites

Better to follow the workshop steps in the [Google Cloud Shell](https://console.cloud.google.com/appengine?cloudshell=true&_ga=2.219504537.-1092609672.1545216569), since it will give you already configured environment with most of the tools you need.

In order to access [Google Cloud Shell](https://console.cloud.google.com/appengine?cloudshell=true&_ga=2.219504537.-1092609672.1545216569), you will be prompted to create a new project (if you don't have any), do so, and then you can skip *Creating a GCP project* in the [Level 0](https://cloud.google.com/appengine/docs/standard/go111/building-app/).

If you already have some GCP project, better to create new one for this workshop, so you can safely remove it afterwards


## [Level 0](https://cloud.google.com/appengine/docs/standard/go111/building-app/)

Go through official guide [Building a Go App on App Engine](https://cloud.google.com/appengine/docs/standard/go111/building-app/)!

**Note**: Using `us-central` region.
Also, you need to enable Google Cloud APIs to be able to run deploy via 
`gcloud app deploy` command :

- Google Cloud Build API `gcloud services enable cloudbuild.googleapis.com`
- Google Compute Engine API `gcloud services enable compute.googleapis.com`

## [Level 1](./level1/README.md)

Deploy and provision simple webserver with terraform, then access it from GAE app.

## [Level 2](./level2/README.md)

Protect webserver with TLS auth, then access it securely from GAE app.