// Modified version the original code:
// https://github.com/GoogleCloudPlatform/golang-samples/blob/master/appengine/go11x/helloworld/helloworld.go
// Copyright 2018 Google Inc. All rights reserved.
// Use of this source code is governed by the Apache 2.0
// License file reference:
// https://github.com/GoogleCloudPlatform/golang-samples/blob/master/LICENSE

// Sample helloworld is an App Engine app.
package main

import (
	"crypto/tls"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"
)

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

func main() {
	http.HandleFunc("/demo", demoHandler)
	http.HandleFunc("/", indexHandler)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
		log.Printf("Defaulting to port %s", port)
	}

	log.Printf("Listening on port %s", port)
	log.Fatal(http.ListenAndServe(fmt.Sprintf(":%s", port), nil))
}

// indexHandler responds to requests with our greeting.
func indexHandler(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}
	fmt.Fprint(w, "Hello, World!")
}

// demoHandler sends request to our HOST_ENDPOINT, and responses with received response
func demoHandler(w http.ResponseWriter, r *http.Request) {
	hostEndpoint := os.Getenv("HOST_ENDPOINT")
	if hostEndpoint == "" {
		log.Fatal("HOST_ENDPOINT env variable not provided")
	}

	hostEndpoint += "/whoami"

	rs, err := client.Get(hostEndpoint)
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
