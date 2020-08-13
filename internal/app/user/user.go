package user

import (
	"context"

	"github.com/grpc-ecosystem/grpc-gateway/runtime"
	"github.com/pthethanh/usersrv/pkg/api/user"
	"google.golang.org/grpc"
)

type (
	// Server is an implementation of user.UsersServer.
	Server struct {
		// TODO use unimplemented server for demonstration only.
		// please remember to implement me.
		user.UnimplementedUsersServer
	}
)

// New return new instance of Server.
func New() *Server {
	return &Server{}
}

// Register implements server.Service.
func (s *Server) Register(srv *grpc.Server) {
	user.RegisterUsersServer(srv, s)
}

// RegisterWithEndpoint implements server.EndpointService.
func (s *Server) RegisterWithEndpoint(ctx context.Context, mux *runtime.ServeMux, addr string, opts []grpc.DialOption) {
	user.RegisterUsersHandlerFromEndpoint(ctx, mux, addr, opts)
}
