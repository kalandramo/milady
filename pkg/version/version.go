package version

import (
	"encoding/json"
	"fmt"
	"runtime"
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

// Get 获取版本信息
func Get() Info {
	return Info{
		GitVersion:   gitVersion,
		GitCommit:    gitCommit,
		GitTreeState: gitTreeState,
		BuildTime:    buildTime,
		BuildBy:      builtBy,
		GoVersion:    runtime.Version(),
		Compiler:     runtime.Compiler,
		Platform:     fmt.Sprintf("%s/%s", runtime.GOOS, runtime.GOARCH),
	}
}
