package main

import (
	"encoding/json"
	"github.com/go-chi/chi"
	"github.com/go-chi/chi/middleware"
	"github.com/robfig/cron"
	"github.com/t3rm1n4l/go-mega"
	"log"
	"net/http"
	"os"
	"strconv"
	"sync"
)

type Server struct {
	m    *mega.Mega
	pool *MegaAccountPool
}

func main() {
	if os.Getenv("CREDENTIALS") == "" {
		panic("No environment variable CREDENTIALS")
	}

	m := mega.New()
	if err := m.SetUploadWorkers(4); err != nil {
		panic(err)
	}

	var p []*MegaAccount
	pool := MegaAccountPool{
		p,
		false,
		false,
		sync.RWMutex{},
		sync.WaitGroup{},
	}

	go pool.FillPool()
	s := Server{m, &pool}

	// cron
	c := cron.New()
	err := c.AddFunc("0 * * * *", pool.FillPool)
	if err != nil {
		panic(err)
	}
	c.Start()

	// web handlers
	r := chi.NewRouter()
	r.Use(middleware.Logger)
	r.HandleFunc("/code", s.newCodeHandler)
	r.HandleFunc("/size", s.poolSizeHandler)
	log.Fatal(http.ListenAndServe(":8080", r))
}

func (s *Server) poolSizeHandler(w http.ResponseWriter, r *http.Request) {
	w.Write([]byte(strconv.Itoa(len(s.pool.pool))))
}

func (s *Server) newCodeHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		return
	}

	err := r.ParseForm()
	if err != nil {
		renderError(w, "CANT_PARSE_FORM", http.StatusInternalServerError)
		return
	}

	if r.Form.Get("credentials") != os.Getenv("CREDENTIALS") {
		renderError(w, "CANT_PARSE_FORM", http.StatusInternalServerError)
		return
	}

	account := s.pool.GetMegaAccount()
	accountBytes, err := json.Marshal(account)
	if err != nil {
		renderError(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.Write(accountBytes)
}

func renderError(w http.ResponseWriter, message string, statusCode int) {
	w.WriteHeader(http.StatusBadRequest)
	w.Write([]byte(message))
}
