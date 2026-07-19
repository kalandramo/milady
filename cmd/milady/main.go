// cmd/milady/main.go 是 milady 命令行工具的入口文件，
// 目前只提供 init 子命令，用于从远程 milady 模板生成新项目。
package main

import (
	"fmt"
	"os"

	"github.com/kalandramo/milady/cmd/milady/internal/cmd"
)

func main() {
	if err := cmd.NewRootCmd().Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
