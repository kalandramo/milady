// Package cmd 注册并管理 milady 命令行工具的根命令及子命令。
package cmd

import (
	"fmt"

	"github.com/kalandramo/milady/pkg/version"
	"github.com/spf13/cobra"
)

// const version = "v1.0.0"

// NewRootCmd 构建并返回根命令。
func NewRootCmd() *cobra.Command {
	var showVersion bool
	root := &cobra.Command{
		Use:   "milady",
		Short: "milady CLI tool",
		Long:  "用于初始化和管理 milady 项目的命令行工具。",
		RunE: func(cmd *cobra.Command, args []string) error {
			if showVersion {
				info := version.Get()
				fmt.Println(info.String())
				return nil
			}
			return cmd.Help()
		},
	}
	root.Flags().BoolVarP(&showVersion, "version", "v", false, "打印版本号")
	root.CompletionOptions.DisableDefaultCmd = true
	root.AddCommand(newInitCmd())
	root.AddCommand(newGenCmd())
	root.AddCommand(newGofumptCmd())
	root.AddCommand(newVersion())
	return root
}
