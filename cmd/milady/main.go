// cmd/milady/main.go 是 milady 命令行工具的入口文件，
// 目前只提供 init 子命令，用于从远程 milady 模板生成新项目。
package main

import (
	"fmt"
	"flag"
	"runtime/debug"
	"strings"

	"github.com/kalandramo/milady/pkg/version"
)

var verbose = flag.Bool("v", false, "print version info")

func main() {
	flag.Parse()
	printBanner()
}

func printBanner() {
	v := version.Get()

	fmt.Println("____       ____      _")
	fmt.Println("   / ___| ___ |  _ \\ ___| | ___  __ _ ___  ___ _ __")
	fmt.Println("  | |  _ / _ \\| |_) / _ \\ |/ _ \\/ _` / __|/ _ \\ '__|")
	fmt.Println("  | |_| | (_) |  _ <  __/ |  __/ (_| \\__ \\  __/ |")
	fmt.Println("   \\____|\\___/|_| \\_\\___|_|\\___|\\__,_|\\___/|_|")
	fmt.Println("milady: Release engineering, simplified.")
	fmt.Println("https://milady.dev")
	fmt.Println()
	fmt.Println("GitVersion:   ", v.GitVersion)
	fmt.Println("GitCommit:    ", v.GitCommit)
	fmt.Println("GitTreeState: ", v.GitTreeState)
	fmt.Println("BuildDate:    ", v.BuildTime)
	fmt.Println("BuiltBy:      ", v.BuildBy)
	fmt.Println("GoVersion:    ", v.GoVersion)
	fmt.Println("Compiler:     ", v.Compiler)
	fmt.Println("Platform:     ", v.Platform)

	// 尝试从构建信息中获取 ModuleSum
	if buildInfo, ok := debug.ReadBuildInfo(); ok {
		var moduleSum string
		for _, setting := range buildInfo.Settings {
			if strings.HasPrefix(setting.Key, "module-sum") {
				moduleSum = setting.Value
				break
			}
		}
		if moduleSum == "" {
			moduleSum = "unknown"
		}
		fmt.Println("ModuleSum:    ", moduleSum)
	}
}
