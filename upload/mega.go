package main

import (
	"encoding/json"
	"fmt"
	"github.com/t3rm1n4l/go-mega"
	"log"
	"os/exec"
	"sync"
)

const accountPoolSize = 5

type MegaAccountPool struct {
	pool []*MegaAccount
	sync.RWMutex
	sync.WaitGroup
}
type MegaAccount struct {
	Email    string `json:"email"`
	Password string `json:"password"`
	storage  *mega.QuotaResp
	login    *mega.Mega
	inUse    bool
}

func (p *MegaAccountPool) managePool() {
	log.Println("starting manager")
	for i := 0; i < accountPoolSize-len(p.pool); i++ {
		account, err := addMegaAccount()
		if err != nil {
			log.Println(err.Error())
		}
		log.Printf("added account %v\n", account)
		p.pool = append(p.pool, &account)
	}
}

func CreateMegaAccount() ([]byte, error) {
	return exec.Command("/usr/bin/local/mega-create.sh").Output()
}

func addMegaAccount() (user MegaAccount, err error) {
	//out, err := CreateMegaAccount()
	//if err != nil {
	//	return
	//}
	out := []byte("{\"email\": \"1588709080565468113@dlme.ga\", \"password\": \"XK5xo1syVmFqwqjfk9Q0WZlt9Hxi2RJ1YMcEiEN7UT6jBcJd1w\"}")
	err = json.Unmarshal(out, &user)
	return
}

// getMegaAccount fetches the logged in account with most storage left out of the pool
func (p *MegaAccountPool) getMegaAccount() (*MegaAccount, error) {
	p.Lock()
	for _, account := range p.pool {
		go func() {
			p.Add(1)
			defer p.Done()
			if account.storage == nil {
				m := mega.New()
				err := m.Login(account.Email, account.Password)
				if err != nil {
					log.Println(err.Error())
				} else {
					q, err := m.GetQuota()
					if err != nil {
						log.Println(err.Error())
					} else {
						account.storage = &q
					}
				}
			}
		}()
	}
	p.Unlock()
	p.Wait()

	// find account with most bytesLeft
	var maxBytesLeft uint64
	var maxAccount MegaAccount
	for _, account := range p.pool {
		if account.storage.Cstrg > maxBytesLeft {
			maxBytesLeft = account.storage.Cstrg
			maxAccount = *account
		}
	}

	m := mega.New()
	err := m.Login(maxAccount.Email, maxAccount.Password)
	if err != nil {
		return nil, err
	}
	maxAccount.login = m
	return &maxAccount, err
}

func UploadFileToMega(account *MegaAccount, fileSize uint64, path, filename string) error {
	if account.storage.Mstrg-(fileSize+account.storage.Cstrg) <= 0 {
		return fmt.Errorf("total allowed: %d left: %d upload: %d", account.storage.Mstrg, account.storage.Cstrg, fileSize)
	}

	// upload file to mega
	_, err := account.login.UploadFile(path, account.login.FS.GetRoot(), filename, nil)
	if err != nil {
		return err
	}
	account.storage.Cstrg += fileSize
	return nil
}
