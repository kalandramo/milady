package versionapi

import (
	"log/slog"

	"gorm.io/gorm"

	"github.com/kalandramo/milady/domain/version"
	"github.com/kalandramo/milady/domain/version/store/versiondb"
	"github.com/kalandramo/milady/pkg/orm"
)

// 通过修改版本号，来控制是否执行表迁移
var (
	DBVersion = "0.0.1"
	DBRemark  = "debug"
)

// NewVersionCore ...
func NewVersionCore(db *gorm.DB) version.Core {
	vdb := versiondb.NewDB(db)
	core := version.NewCore(vdb)
	isOK := core.IsAutoMigrate(DBVersion)
	vdb.AutoMigrate(isOK)
	if isOK {
		slog.Info("更新数据库表结构")
		orm.SetEnabledAutoMigrate(true)
	}
	return core
}
