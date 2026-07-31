# Makefile 使用文档
# https://www.gnu.org/software/make/manual/html_node/index.html

# include .envrc
SHELL = /bin/bash

# ==================================================================================== #
# HELPERS
# ==================================================================================== #

## help: print this help message
help:
	@echo 'Usage:'
	@sed -n 's/^##//p' ${MAKEFILE_LIST} | column -t -s ':' |  sed -e 's/^/ /'


# ==================================================================================== #
# COMMON INFO
# ==================================================================================== #

# Makefile所在目录（绝对路径）
COMMON_SELF_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
# Project root directory
PROJ_ROOT_DIR := $(strip $(abspath $(shell cd $(COMMON_SELF_DIR)/ && pwd -P)))
# Directory for build artifacts and temporary files
OUTPUT_DIR := $(PROJ_ROOT_DIR)/_output
ROOT_PACKAGE=$(shell awk 'NR==1 {print $$2}' go.mod)

.PHONY: cinfo
## cinfo: 公共变量 debug
cinfo:
	@echo "当前Makefile所在目录: $(COMMON_SELF_DIR)"
	@echo "项目根目录: $(PROJ_ROOT_DIR)"
	@echo "编译产物输出目录: $(OUTPUT_DIR)"
	@echo "Go模块根包名: $(ROOT_PACKAGE)"

.PHONY: confirm
confirm:
	@echo -n 'Are you sure? [y/n] ' && read ans && [ $${ans:-N} = y ]

.PHONY: title
title:
	@echo -e "\033[34m$(content)\033[0m"

.PHONY: rename
## rename: clone 后的模板，需要更新 module 名
# 例如: make rename name=github.com/name/project
rename:
	@rm -rf .git ./docs/* ./changelog
	@if [ -z "$(name)" ]; then \
		echo "错误: 请提供 name 参数，例如: make rename name=github.com/name/project"; \
		exit 1; \
	fi
	@rm -rf domain/* pkg/*
	@echo "正在替换模块名为: $(name)"
	@find . -type f -name "*.go" -exec sed -i.bak 's|github\.com/kalandramo/milady/internal|$(name)/internal|g' {} \;
	@sed -i.bak 's|github\.com/kalandramo/milady|$(name)|g' go.mod
	@find . -name "*.bak" -delete
	@go mod tidy
	@git init
	@make title content="\n模块名替换完成"

# ==================================================================================== #
# DEVELOPMENT
# ==================================================================================== #

## init: 安装开发环境
init:
	@make title content="install dependencies..."
	go install github.com/google/wire/cmd/wire@latest
	go install github.com/divan/expvarmon@latest
	go install github.com/kalandramo/milady@latest
	go install github.com/rakyll/hey@latest
	go install mvdan.cc/gofumpt@latest
	@make title content="Successed!"

## wire: 生成依赖注入代码
wire:
	go mod tidy
	go get github.com/google/wire/cmd/wire@latest
	go generate ./...
	go mod tidy

## expva/http: 监听网络请求指标
expva/http:
	expvarmon --ports=":9999" -i 1s -vars="version,request,requests,responses,goroutines,errors,panics,mem:memstats.Alloc"

## expva/db: 监听数据库连接指标
expva/db:
	expvarmon --ports=":9999" -i 5s -vars="databse.MaxOpenConnections,databse.OpenConnections,database.InUse,databse.Idle"

# 发起 100 次请求，每次并发 50
# hey -n 100 -c 50 http://localhost:9999/healthcheck


# ==================================================================================== #
# QUALITY CONTROL
# ==================================================================================== #

## audit: 检查代码依赖/格式化/测试
.PHONY: audit
audit:
	@make title content='Formatting code...'
	gofumpt -l -w .
	@make title content='Vetting code...'
	go vet ./...
	@make title content='Running tests...'
	go test -race -vet=off ./...

## vendor: 整理并下载依赖
.PHONY: vendor
vendor:
	@make title content='Tidying and verifying module dependencies...'
	go mod tidy && go mod verify
	@make title content='Vendoring dependencies...'
	go mod vendor

# ==================================================================================== #
# VERSION
# ==================================================================================== #

# 版本号规则说明
# 1. 版本号使用 Git tag，格式为 v1.0.0。
# 2. 如果当前提交没有 tag，找到最近的 tag，计算从该 tag 到当前提交的提交次数。例如，最近的 tag 为 v1.0.1，当前提交距离它有 10 次提交，则版本号为 v1.0.11（v1.0.1 + 10 次提交）。
# 3. 如果没有任何 tag，则默认版本号为 v0.0.0，后续提交次数作为版本号的次版本号。

# 指定应用程序所使用的版本包。程序编译时将通过 -ldflags -X 参数把对应值注入该包内的变量。
VERSION_PACKAGE=$(ROOT_PACKAGE)/pkg/version
# 检查当前目录是否为 Git 仓库
IS_GIT_REPO := $(shell git rev-parse --is-inside-work-tree 2>/dev/null)
ifeq ($(IS_GIT_REPO),)
    # 非 Git 仓库，使用兜底值
    GIT_TREE_STATE := "not_a_git_repo"
    VERSION := "v0.0.0"
    GIT_COMMIT := "unknown"
else
    # 定义 VERSION 语义化版本（尚未设置时生效）
    ifeq ($(origin VERSION), undefined)
        # 如果想仅支持注释标签，可以去掉 --tags，否则会包含轻量标签
        RECENT_TAG := $(shell git describe --tags --abbrev=0  2>&1 | grep -v -e "fatal" -e "Try" || echo "v0.0.0")

		ifeq ($(RECENT_TAG),v0.0.0)
			COMMITS := $(shell git rev-list --count HEAD)
		else
			COMMITS := $(shell git log --first-parent --format='%ae' $(RECENT_TAG)..$(BRANCH) | wc -l)
			COMMITS := $(shell echo $(COMMITS) | sed 's/ //g')
		endif

        # 从版本字符串中提取主版本号、次版本号和修订号
        GIT_VERSION_MAJOR := $(shell echo $(RECENT_TAG) | cut -d. -f1 | sed 's/v//')
        GIT_VERSION_MINOR := $(shell echo $(RECENT_TAG) | cut -d. -f2)
        GIT_VERSION_PATCH := $(shell echo $(RECENT_TAG) | cut -d. -f3)

        # windows 系统 git bash 没有 bc
        # FINAL_PATCH := $(shell echo $(GIT_VERSION_PATCH) + $(COMMITS) | bc)
        FINAL_PATCH := $(shell echo '$(GIT_VERSION_PATCH) $(COMMITS)' | awk '{print $$1 + $$2}')
        VERSION := v$(GIT_VERSION_MAJOR).$(GIT_VERSION_MINOR).$(FINAL_PATCH)
    endif

    # git 分支
	GIT_BRANCH := $(shell git rev-parse --abbrev-ref HEAD)

    # 检查代码仓库是否处于未提交变更状态（默认视为存在变更）
    GIT_TREE_STATE := "dirty"
    ifeq (, $(shell git status --porcelain 2>/dev/null))
        GIT_TREE_STATE := "clean"
    endif

    # 获取最新提交哈希值与提交时间
	GIT_COMMIT := $(shell git log -n1 --pretty=format:"%h-%cd" --date=format:%y%m%d-%H%M%S)
endif

GO_LDFLAGS += \
    -X $(VERSION_PACKAGE).gitVersion=$(VERSION) \
    -X $(VERSION_PACKAGE).gitCommit=$(GIT_COMMIT) \
    -X $(VERSION_PACKAGE).gitBranch=$(GIT_BRANCH) \
    -X $(VERSION_PACKAGE).gitTreeState=$(GIT_TREE_STATE) \
    -X $(VERSION_PACKAGE).buildTime=$(shell date +'%Y-%m-%dT%H:%M:%S%z')

GO_BUILD_FLAGS += -ldflags "$(GO_LDFLAGS)"

# test:
# 	@echo ">>>${RECENT_TAG}"

## vinfo: 查看构建版本相关信息
.PHONY: vinfo
vinfo:
	@echo "Go模块根包名: $(ROOT_PACKAGE)"
	@echo "版本号: $(VERSION)"
	@echo "Git 分支: $(GIT_BRANCH)"
	@echo "Git 提交哈希值与提交时间: $(GIT_COMMIT)"
	@echo "Go 编译参数: $(GO_BUILD_FLAGS)"

# ==================================================================================== #
# BUILD
# ==================================================================================== #

COMMANDS ?= $(filter-out %.md, $(wildcard $(PROJ_ROOT_DIR)/cmd/*))
BINS ?= $(foreach cmd,${COMMANDS},$(notdir $(cmd)))

# 编译的操作系统可以是 linux/windows/darwin
PLATFORMS ?= darwin_amd64 darwin_arm64 windows_amd64 windows_arm64 linux_amd64 linux_arm64

# 设置一个指定的操作系统架构
ifeq ($(origin PLATFORM), undefined)
    ifeq ($(origin GOOS), undefined)
        GOOS := $(shell go env GOOS)
    endif
    ifeq ($(origin GOARCH), undefined)
        GOARCH := $(shell go env GOARCH)
    endif
    PLATFORM := $(GOOS)_$(GOARCH)
    # 构建镜像时，使用 linux 作为默认的 OS
    IMAGE_PLAT := linux_$(GOARCH)
else
    GOOS := $(word 1, $(subst _, ,$(PLATFORM)))
    GOARCH := $(word 2, $(subst _, ,$(PLATFORM)))
    IMAGE_PLAT := $(PLATFORM)
endif

# cgo 默认跟随环境变量，如果明确不用 cgo，可以设置为 0
CGO_ENABLED = $(shell go env CGO_ENABLED)

IMAGE_NAME := $(MODULE_NAME):latest

## build: 构建应用
.PHONY: build
build: $(addprefix build., $(addprefix $(PLATFORM)., $(BINS))) ## Build all binaries for the selected platform.

build.%: ## 编译 Go 源码.
	$(eval COMMAND := $(word 2,$(subst ., ,$*)))
	$(eval PLATFORM := $(word 1,$(subst ., ,$*)))
	$(eval OS := $(word 1,$(subst _, ,$(PLATFORM))))
	$(eval ARCH := $(word 2,$(subst _, ,$(PLATFORM))))
	@echo "===========> Building binary $(COMMAND) $(VERSION) for $(OS) $(ARCH)"
	@mkdir -p $(OUTPUT_DIR)/platforms/$(OS)/$(ARCH)
	@CGO_ENABLED=$(CGO_ENABLED) GOOS=$(OS) GOARCH=$(ARCH) go build -trimpath \
		$(GO_BUILD_FLAGS) \
		-o $(OUTPUT_DIR)/platforms/$(OS)/$(ARCH)/$(COMMAND)$(GO_OUT_EXT) \
		$(ROOT_PACKAGE)/cmd/$(COMMAND)
	@echo '>>> OK'

## build/clean: 清理构建缓存目录
.PHONY: build/clean
build/clean:
	@rm -rf $(OUTPUT_DIR)/*

docker/build:
	@docker build --force-rm=true --platform linux/amd64 -t $(IMAGE_NAME) .

docker/save:
	@docker save -o $(MODULE_NAME)_$(VERSION).tar $(IMAGE_NAME)

docker/push:
	@docker push $(IMAGE_NAME)

docker/publish: build/clean
	$(eval GOARCH := amd64)
	$(eval GOOS := linux)
	$(eval dir := $(BUILD_DIR_ROOT)/$(GOOS)_$(GOARCH))
	@make build/local GOOS=$(GOOS) GOARCH=$(GOARCH)
	@upx $(dir)/bin

	$(eval GOARCH := arm64)
	$(eval GOOS := linux)
	$(eval dir := $(BUILD_DIR_ROOT)/$(GOOS)_$(GOARCH))
	@make build/local GOOS=$(GOOS) GOARCH=$(GOARCH)
	@upx $(dir)/bin

	@docker build --force-rm=true --platform linux/amd64,linux/arm64 -t $(IMAGE_NAME) --push .


# ==================================================================================== #
# PRODUCTION
# ==================================================================================== #

PRODUCTION_HOST = remoteHost

## release/push: 发布产品到服务器，仅上传文件
# 中小项目可以引入 CI/CD，也可以通过命令快速发布到测试服务器上。
release/push:
	@scp build/linux_amd64/bin $(PRODUCTION_HOST):/home/app/$(MODULE_NAME)
	@echo "push Successed"
