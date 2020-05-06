package main

import (
	"encoding/json"
	"fmt"
	"github.com/t3rm1n4l/go-mega"
	"log"
	"os/exec"
	"sync"
	"time"
)

const accountPoolSize = 5

type MegaAccountPool struct {
	pool                []*MegaAccount
	isFilling           bool
	isGeneratingAccount bool
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

func (p *MegaAccountPool) FillPool() {
	if !p.isFilling {
		log.Println("Started filling...")
		p.isFilling = true
		for i := 0; i < accountPoolSize-len(p.pool); i++ {
			account, err := p.GenMegaAccount()
			if err != nil {
				log.Println(err.Error())
			}
			p.Lock()
			p.pool = append(p.pool, account)
			p.Unlock()
		}
		log.Println("Finished filling...")
		p.isFilling = false
	} else {
		log.Println("Already filling...")
	}
}

func (p *MegaAccountPool) CreateMegaAccount() (out []byte, err error) {
	if !p.isGeneratingAccount {
		p.isGeneratingAccount = true
		start := time.Now()
		out, err = exec.Command("/usr/bin/local/mega-create.sh").Output()
		log.Printf("account created in %v\n", time.Since(start))
		p.isGeneratingAccount = false
	} else {
		log.Println("Already generating account")
	}
	return
}

func (p *MegaAccountPool) GenMegaAccount() (user *MegaAccount, err error) {
	out, err := p.CreateMegaAccount()
	if err != nil {
		return
	}
	err = json.Unmarshal(out, &user)
	return
}

func (p *MegaAccountPool) GetMegaAccount() (account *MegaAccount) {
	if len(p.pool) == 0 {
		var err error
		account, err = p.GenMegaAccount()
		if err != nil {
			log.Println(err)
		}
	} else {
		p.Lock()
		account, p.pool = p.pool[0], p.pool[1:]
		p.Unlock()
	}
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
