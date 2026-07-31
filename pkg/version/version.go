package version

import (
	"encoding/json"
	"fmt"
	"runtime"
	"runtime/debug"
	"time"

	"github.com/gosuri/uitable"
)

// 编译时通过 -ldflags 注入变量，初始默认值
var (
	gitVersion   = ""
	gitCommit    = ""
	gitTreeState = ""
	buildTime    = ""
	builtBy      = ""
)

// Info 结构化版本信息
type Info struct {
	GitVersion   string
	GitCommit    string
	GitTreeState string
	BuildTime    string
	BuildBy      string
	GoVersion    string
	Compiler     string
	Platform     string
}

// String 返回人性化的版本信息字符串.
func (i Info) String() string {
	// 固定东八区，不需要系统时区文件
	cst := time.FixedZone("CST", 8*3600)
	displayBuildTime := i.BuildTime
	if t, err := time.Parse(time.RFC3339, i.BuildTime); err == nil {
		displayBuildTime = t.In(cst).Format(time.RFC3339)
	}

	return fmt.Sprintf(
		`GitVersion:   %s
GitCommit:    %s
GitTreeState: %s
BuildTime:    %s
BuildBy:      %s
GoVersion:    %s
Compiler:     %s
Platform:     %s`,

		i.GitVersion,
		i.GitCommit,
		i.GitTreeState,
		displayBuildTime,
		i.BuildBy,
		i.GoVersion,
		i.Compiler,
		i.Platform,
	)
}

// ToJSON 以 JSON 格式返回版本信息.
func (i Info) ToJSON() string {
	s, _ := json.Marshal(i)
	return string(s)
}

// Text 将版本信息编码为 UTF-8 格式的文本，并返回.
func (i Info) Text() string {
	table := uitable.New()
	table.RightAlign(0)
	table.MaxColWidth = 80
	table.Separator = " "
	table.AddRow("gitVersion:", i.GitVersion)
	table.AddRow("gitCommit:", i.GitCommit)
	table.AddRow("gitTreeState:", i.GitTreeState)
	table.AddRow("buildTime:", i.BuildTime)
	table.AddRow("goVersion:", i.GoVersion)
	table.AddRow("compiler:", i.Compiler)
	table.AddRow("platform:", i.Platform)

	return table.String()
}

// Get 获取版本信息：优先ldflags注入，兜底读取buildinfo
func Get() Info {
	base := Info{
		GitVersion:   gitVersion,
		GitCommit:    gitCommit,
		GitTreeState: gitTreeState,
		BuildTime:    buildTime,
		BuildBy:      builtBy,
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
