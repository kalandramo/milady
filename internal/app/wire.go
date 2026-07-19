//go:build wireinject

package app

import (
	"log/slog"
	"net/http"

	"github.com/google/wire"

	"github.com/kalandramo/milady/internal/conf"
	"github.com/kalandramo/milady/internal/data"
	"github.com/kalandramo/milady/internal/web/api"
)

func WireApp(bc *conf.Bootstrap, log *slog.Logger) (http.Handler, func(), error) {
	panic(wire.Build(data.ProviderSet, api.ProviderVersionSet, api.ProviderSet))
}
