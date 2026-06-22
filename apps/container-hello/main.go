package main

import (
	"net/http"
	"os"
)

// Container baseline: same handler/logic as the Spin app, but packaged as a
// normal OCI container image and run as a standard Kubernetes Deployment.
// Keeping the logic identical isolates the variable we care about:
// the execution model (Wasm via shim vs container via runc).
func main() {
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{"runtime":"container","msg":"hello from Go"}`))
	})

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	_ = http.ListenAndServe(":"+port, nil)
}
