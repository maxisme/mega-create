package main

import (
	"fmt"
	"github.com/robfig/cron/v3"
	"github.com/t3rm1n4l/go-mega"
	"io/ioutil"
	"log"
	"mime"
	"net/http"
	"os"
	"path/filepath"
	"sync"
)

const maxUploadSize = 1 * 1024 * 1024 * 1024 // 1 GB
const uploadPath = "./tmp"

type Server struct {
	m    *mega.Mega
	pool *MegaAccountPool
}

func main() {
	m := mega.New()
	if err := m.SetUploadWorkers(4); err != nil {
		panic(err)
	}

	var p []*MegaAccount
	pool := MegaAccountPool{
		p,
		sync.RWMutex{},
		sync.WaitGroup{},
	}

	s := Server{m, &pool}

	// cron
	c := cron.New()
	_, _ = c.AddFunc("1 * * * *", pool.managePool)
	c.Start()

	// web handlers
	http.HandleFunc("/upload", s.uploadFileHandler)
	log.Fatal(http.ListenAndServe(":8080", nil))
}

func (s *Server) uploadFileHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method == "GET" {
		return
	}
	if err := r.ParseMultipartForm(maxUploadSize); err != nil {
		fmt.Printf("Could not parse multipart form: %v\n", err)
		renderError(w, "CANT_PARSE_FORM", http.StatusInternalServerError)
		return
	}

	// parse and validate file and post parameters
	file, fileHeader, err := r.FormFile("file")
	if err != nil {
		renderError(w, "INVALID_FILE", http.StatusBadRequest)
		return
	}
	defer file.Close()

	// Get and print out file size
	if fileHeader.Size > maxUploadSize {
		renderError(w, "FILE_TOO_BIG", http.StatusBadRequest)
		return
	}
	fileBytes, err := ioutil.ReadAll(file)
	if err != nil {
		renderError(w, "INVALID_FILE", http.StatusBadRequest)
		return
	}
	fileName := fileHeader.Filename
	detectedFileType := http.DetectContentType(fileBytes)
	fileEndings, err := mime.ExtensionsByType(detectedFileType)
	if err != nil {
		renderError(w, "CANT_READ_FILE_TYPE", http.StatusInternalServerError)
		return
	}
	newPath := filepath.Join(uploadPath, fileName+fileEndings[0])

	// write file
	newFile, err := os.Create(newPath)
	if err != nil {
		renderError(w, "CANT_WRITE_FILE", http.StatusInternalServerError)
		return
	}
	defer newFile.Close() // idempotent, okay to call twice
	if _, err := newFile.Write(fileBytes); err != nil || newFile.Close() != nil {
		renderError(w, "CANT_WRITE_FILE", http.StatusInternalServerError)
		return
	}

	// write file to mega

	w.Write([]byte("SUCCESS"))
}

func renderError(w http.ResponseWriter, message string, statusCode int) {
	w.WriteHeader(http.StatusBadRequest)
	w.Write([]byte(message))
}
