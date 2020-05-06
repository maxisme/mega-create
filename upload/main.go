package main

import (
	"encoding/json"
	"fmt"
	"github.com/t3rm1n4l/go-mega"
	"io/ioutil"
	"log"
	"mime"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"sync"
)

const maxUploadSize = 1 * 1024 * 1024 * 1024 // 1 GB
const uploadPath = "./tmp"

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

	//go pool.FillPool()
	s := Server{m, &pool}

	// cron
	//c := cron.New()
	//_, err := c.AddFunc("* * * * *", pool.FillPool)
	//if err != nil {
	//	panic(err)
	//}
	//c.Start()

	// web handlers
	http.HandleFunc("/upload", s.uploadFileHandler)
	http.HandleFunc("/code", s.newCodeHandler)
	http.HandleFunc("/size", s.poolSizeHandler)
	log.Fatal(http.ListenAndServe(":8080", nil))
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
		log.Println(err.Error())
		renderError(w, "CANT_WRITE_FILE", http.StatusInternalServerError)
		return
	}
	defer newFile.Close() // idempotent, okay to call twice
	if _, err := newFile.Write(fileBytes); err != nil || newFile.Close() != nil {
		renderError(w, "CANT_WRITE_FILE", http.StatusInternalServerError)
		return
	}

	// write file to mega
	acnt, err := s.pool.getMegaAccount()
	if err != nil {
		log.Println(err.Error())
		renderError(w, "CANT_FIND_MEGA_ACNT", http.StatusInternalServerError)
		return
	}
	err = UploadFileToMega(acnt, uint64(fileHeader.Size), newPath, r.Form.Get("mega_path"))
	if err != nil {
		log.Println(err.Error())
		renderError(w, "PROBLEM_UPLOADING", http.StatusInternalServerError)
		return
	}

	w.Write([]byte("SUCCESS"))
}

func renderError(w http.ResponseWriter, message string, statusCode int) {
	w.WriteHeader(http.StatusBadRequest)
	w.Write([]byte(message))
}
