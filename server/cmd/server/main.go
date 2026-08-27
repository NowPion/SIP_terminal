package main

import (
	"log"
	"os"
	"time"

	"github.com/nie/sip-terminal/server/internal/api"
	"github.com/nie/sip-terminal/server/internal/store"
)

func env(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}

func main() {
	dsn := env("MYSQL_DSN", "root:root@tcp(host.docker.internal:7778)/sip_terminal?charset=utf8mb4&parseTime=True&loc=Local")
	secret := env("JWT_SECRET", "dev-secret-change-me")
	addr := ":" + env("PORT", "8080")

	var st *store.Store
	var err error
	for i := 1; i <= 15; i++ { // 等 MySQL 就绪（容器冷启动）
		if st, err = store.Open(dsn); err == nil {
			break
		}
		log.Printf("[retry %d] mysql connect: %v", i, err)
		time.Sleep(2 * time.Second)
	}
	if err != nil {
		log.Fatalf("mysql unreachable: %v", err)
	}

	r := api.New(st, secret)
	log.Printf("listening on %s", addr)
	log.Fatal(r.Run(addr))
}
