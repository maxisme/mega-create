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
	"os/exec"
	"path/filepath"
)

const maxUploadSize = 9 * 1024 * 1024 * 1024 // 10 GB
const uploadPath = "./tmp"

type Server struct {
	m *mega.Mega
}

func main() {
	m := mega.New()
	if err := m.SetUploadWorkers(4); err != nil {
		panic(err)
	}

	s := Server{m}
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
	// read username and password from file
	userBytes, _ := ioutil.ReadFile("/.username")
	passBytes, _ := ioutil.ReadFile("/.password")
	if err := s.m.Login(string(userBytes), string(passBytes)); err != nil {
		user, err := megaCreate()
		if err != nil {
			log.Println(err.Error())
			renderError(w, "FAILED_CREATING_ACCOUNT", http.StatusInternalServerError)
			return
		}
		if err := s.m.Login(user.Email, user.Password); err != nil {
			log.Println(err.Error())
			renderError(w, "FAILED_LOGGING_IN_NEW_ACCOUNT", http.StatusInternalServerError)
			return
		}
	}

	// get space left
	q, err := s.m.GetQuota()
	if err != nil {
		panic(err)
	}
	if q.Mstrg-(uint64(fileHeader.Size)+q.Cstrg) <= 0 {
		log.Printf("Total allowed %d Left %d Upload %d", q.Mstrg, q.Cstrg, fileHeader.Size)
		renderError(w, "FILE_TOO_BIG_FOR_MEGA", http.StatusBadRequest)
		return
	}

	n, err := m.UploadFile(newPath, m.FS.GetRoot(), r.Form.Get("name"), nil)
	if err != nil {

	}
	w.Write([]byte("SUCCESS"))
}

func renderError(w http.ResponseWriter, message string, statusCode int) {
	w.WriteHeader(http.StatusBadRequest)
	w.Write([]byte(message))
}

type MegaNewUser struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

func megaCreate() (user MegaNewUser, err error) {
	out, err := exec.Command("mega-create.sh").Output()
	if err != nil {
		return
	}
	if err := json.Unmarshal(out, &user); err != nil {
		return
	}
	return
}
