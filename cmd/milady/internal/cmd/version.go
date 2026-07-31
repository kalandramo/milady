package cmd

import (
	"fmt"

	"github.com/kalandramo/milady/pkg/version"
	"github.com/spf13/cobra"
)

// newVersion 构建 version 子命令。
func newVersion() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "version",
		Short: "打印版本构建信息",
		Run: func(cmd *cobra.Command, args []string) {
			fmt.Println(version.Get().String())
		},
	}

	return cmd
}
