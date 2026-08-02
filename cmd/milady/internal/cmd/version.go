package cmd

import (
	"fmt"

	"github.com/kalandramo/milady/pkg/version"
	"github.com/spf13/cobra"
)

// newVersion 构建 version 子命令。
func newVersion() *cobra.Command {
	var short, json bool

	cmd := &cobra.Command{
		Use:   "version",
		Short: "打印版本构建信息",
		Run: func(cmd *cobra.Command, args []string) {
			info := version.Get()

			// --json 模式：仅输出 JSON，不显示 Logo
			if json {
				fmt.Println(info.ToJSON())
				return
			}

			// 非 --short 模式：先输出 Logo
			if !short {
				fmt.Println(version.Logo)
				fmt.Println()
			}

			fmt.Println(info.String())
		},
	}

	cmd.Flags().BoolVar(&short, "short", false, "仅输出版本信息，不显示 Logo")
	cmd.Flags().BoolVarP(&json, "json", "j", false, "以 JSON 格式输出版本信息")

	return cmd
}
