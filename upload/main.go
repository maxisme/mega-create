package main

import (
	"encoding/json"
	"fmt"
	mega "github.com/t3rm1n4l/go-mega"
	"io"
	"io/ioutil"
	"log"
	"mime"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"sync"
)

const maxUploadSize = 9 * 1024 * 1024 * 1024 // 10 GB
const uploadPath = "./tmp"

func main() {
	http.HandleFunc("/upload", uploadFileHandler())
	log.Fatal(http.ListenAndServe(":8080", nil))
}

func uploadFileHandler() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
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
		userBytes, err := ioutil.ReadFile("/.username")
		passBytes, err := ioutil.ReadFile("/.password")
		m := mega.New()
		if err := m.Login(string(userBytes), string(passBytes)); err != nil {
			user, err := megaCreate()
			if err != nil {
				log.Println(err.Error())
				renderError(w, "FAILED_CREATING_ACCOUNT", http.StatusInternalServerError)
				return
			}
			if err := m.Login(user.Email, user.Password); err != nil {
				log.Println(err.Error())
				renderError(w, "FAILED_LOGGING_IN_NEW_ACCOUNT", http.StatusInternalServerError)
				return
			}
		}
		//m.UploadFile(newPath, m, r.Form.Get("name"), m.FS.root)

		w.Write([]byte("SUCCESS"))
	}
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

// Upload a file to the filesystem
func UploadBytes(srcpath string, parent *mega.Node, name string, progress *chan int) (node *mega.Node, err error) {
	defer func() {
		if progress != nil {
			close(*progress)
		}
	}()

	var infile *os.File
	var fileSize int64

	info, err := os.Stat(srcpath)
	if err == nil {
		fileSize = info.Size()
	}

	infile, err = os.OpenFile(srcpath, os.O_RDONLY, 0666)
	if err != nil {
		return nil, err
	}
	defer func() {
		e := infile.Close()
		if err == nil {
			err = e
		}
	}()

	if name == "" {
		name = filepath.Base(srcpath)
	}

	u, err := m.NewUpload(parent, name, fileSize)
	if err != nil {
		return nil, err
	}

	workch := make(chan int)
	errch := make(chan error, m.ul_workers)
	wg := sync.WaitGroup{}

	// Fire chunk upload workers
	for w := 0; w < m.ul_workers; w++ {
		wg.Add(1)

		go func() {
			defer wg.Done()

			for id := range workch {
				chk_start, chk_size, err := u.ChunkLocation(id)
				if err != nil {
					errch <- err
					return
				}
				chunk := make([]byte, chk_size)
				n, err := infile.ReadAt(chunk, chk_start)
				if err != nil && err != io.EOF {
					errch <- err
					return
				}
				if n != len(chunk) {
					errch <- errors.New("chunk too short")
					return
				}

				err = u.UploadChunk(id, chunk)
				if err != nil {
					errch <- err
					return
				}

				if progress != nil {
					*progress <- chk_size
				}
			}
		}()
	}

	// Place chunk download jobs to chan
	err = nil
	for id := 0; id < u.Chunks() && err == nil; {
		select {
		case workch <- id:
			id++
		case err = <-errch:
		}
	}

	close(workch)

	wg.Wait()

	if err != nil {
		return nil, err
	}

	return u.Finish()
}
