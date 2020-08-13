package main

import (
	"github.com/pthethanh/micro/server"
	"github.com/pthethanh/usersrv/internal/app/user"
)

func main() {
	srv := user.New()

	if err := server.New(server.FromEnv(), server.Web("/", "web", "index.html")).ListenAndServe(srv); err != nil {
		panic(err)
	}

}
