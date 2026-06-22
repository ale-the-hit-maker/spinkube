package main

import (
	"fmt"
	"net/http"
	"strconv"

	spinhttp "github.com/fermyon/spin/sdk/go/v2/http"
	"github.com/fermyon/spin/sdk/go/v2/kv"
)

// Minimal HTTP API used as the "unit under test".
//   GET /        -> plain JSON (hot path used by the benchmarks)
//   GET /count   -> increments a counter in the Spin key-value store
//                   (used only by the vertical demo to show stateful Spin)
func init() {
	spinhttp.Handle(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/count":
			store, err := kv.OpenStore("default")
			if err != nil {
				http.Error(w, err.Error(), http.StatusInternalServerError)
				return
			}
			defer store.Close()

			n := 0
			if b, err := store.Get("count"); err == nil {
				n, _ = strconv.Atoi(string(b))
			}
			n++
			_ = store.Set("count", []byte(strconv.Itoa(n)))

			w.Header().Set("Content-Type", "application/json")
			fmt.Fprintf(w, `{"runtime":"wasm","count":%d}`, n)
		default:
			w.Header().Set("Content-Type", "application/json")
			w.Write([]byte(`{"runtime":"wasm","msg":"hello from Spin"}`))
		}
	})
}

func main() {}
