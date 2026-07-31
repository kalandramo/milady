package version

import (
	"encoding/json"
	"fmt"
	"runtime"
	"runtime/debug"
	"strings"
	"time"

	"github.com/gosuri/uitable"
)

// 编译时通过 -ldflags 注入变量，初始默认值
var (
	// buildTime 是 ISO8601 格式的构建时间, `git log -n1 --pretty=format:"%h-%cd" --date=format:%y%m%d-%H%M%S` 命令的输出
	buildTime    = ""
	gitVersion   = "" // gitVersion 是语义化的版本号 v1.0.0
	gitCommit    = "" // gitCommit git短哈希+时间
	gitBranch    = "" // git 分支
	gitTreeState = "" // gitTreeState 代表构建时 Git 仓库的状态，可能的值有：clean, dirty.
)

// Info 结构化版本信息
type Info struct {
	GitVersion   string
	GitCommit    string
	GitBranch    string
	GitTreeState string
	BuildTime    string
	GoVersion    string
	Compiler     string
	Platform     string
}

// String 返回人性化的版本信息字符串.
func (info Info) String() string {
	var sb strings.Builder
	sb.WriteString(fmt.Sprintf("GitVersion:    %s\n", info.GitVersion))
	sb.WriteString(fmt.Sprintf("GitCommit:  %s\n", info.GitCommit))
	sb.WriteString(fmt.Sprintf("GitBranch:  %s\n", info.GitBranch))
	sb.WriteString(fmt.Sprintf("GitTreeState:  %s\n", info.GitTreeState))
	sb.WriteString(fmt.Sprintf("BuildTime:  %s\n", info.BuildTime))
	sb.WriteString(fmt.Sprintf("GoVersion:  %s\n", info.GoVersion))
	sb.WriteString(fmt.Sprintf("Platform:   %s", info.Platform))
	return sb.String()
}

// ToJSON 以 JSON 格式返回版本信息.
func (info Info) ToJSON() string {
	s, _ := json.Marshal(info)
	return string(s)
}

// Text 将版本信息编码为 UTF-8 格式的文本，并返回.
func (info Info) Text() string {
	table := uitable.New()
	table.RightAlign(0)
	table.MaxColWidth = 80
	table.Separator = " "
	table.AddRow("gitVersion:", info.GitVersion)
	table.AddRow("gitCommit:", info.GitCommit)
	table.AddRow("gitBranch:", info.GitBranch)
	table.AddRow("gitTreeState:", info.GitTreeState)
	table.AddRow("buildTime:", info.BuildTime)
	table.AddRow("goVersion:", info.GoVersion)
	table.AddRow("compiler:", info.Compiler)
	table.AddRow("platform:", info.Platform)

	return table.String()
}

// Get 获取版本信息：优先ldflags注入，兜底读取buildinfo
func Get() Info {
	base := Info{
		GitVersion:   gitVersion,
		GitCommit:    gitCommit,
		GitBranch:    gitBranch,
		GitTreeState: gitTreeState,
		BuildTime:    buildTime,
		GoVersion:    runtime.Version(),
		Compiler:     runtime.Compiler,
		Platform:     fmt.Sprintf("%s/%s", runtime.GOOS, runtime.GOARCH),
	}

	// 如果ldflags注入为空，尝试从buildinfo自动读取
	if base.GitVersion == "" || base.GitCommit == "" {
		buildInfo := GetFromDebugInfo("github.com/kalandramo/milady")
		// 缺字段才覆盖，保留ldflags优先
		if base.GitVersion == "" {
			base.GitVersion = buildInfo.GitVersion
		}
		if base.GitCommit == "" {
			base.GitCommit = buildInfo.GitCommit
		}
		if base.BuildTime == "" {
			base.BuildTime = buildInfo.BuildTime
		}
		if base.GitTreeState == "" {
			base.GitTreeState = buildInfo.GitTreeState
		}
		if base.GitBranch == "" {
			base.GitBranch = "main" // go install 时这个值永远固定是 main
		}
	}

	return base
}

func GetFromDebugInfo(modulePath string) Info {
	info := Info{
		GoVersion: runtime.Version(),
		Compiler:  runtime.Compiler,
		Platform:  fmt.Sprintf("%s/%s", runtime.GOOS, runtime.GOARCH),
	}

	// 尝试从构建信息中获取版本
	if buildInfo, ok := debug.ReadBuildInfo(); ok {
		mod := findModule(buildInfo, modulePath)
		if mod == nil {
			info.GitVersion = "unknown"
		} else {
			if mod.Replace != nil {
				mod = mod.Replace
			}
			info.GitVersion = mod.Version
		}

		info.GitCommit = "unknown"
		info.BuildTime = time.Now().Format(time.RFC3339)
		info.GitTreeState = "clean"
		// 从构建设置中获取更多信息
		for _, setting := range buildInfo.Settings {
			switch setting.Key {
			case "vcs.revision":
				info.GitCommit = setting.Value
			case "vcs.time":
				info.BuildTime = setting.Value
			case "vcs.modified":
				if setting.Value == "true" {
					info.GitTreeState = "dirty"
				}
			}
		}
	}

	return info
}

func findModule(info *debug.BuildInfo, modulePath string) *debug.Module {
	if info.Main.Path == modulePath {
		return &info.Main
	}
	for _, dep := range info.Deps {
		if dep.Path == modulePath {
			return dep
		}
	}
	return nil
}
