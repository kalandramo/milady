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
# BUILD
# ==================================================================================== #


## build/local: 本地构建应用，构建物输出目录 dist
.PHONY: build/local
build/local: 
	@goreleaser build --snapshot --clean

# ==================================================================================== #
# VERSION
# ==================================================================================== #

# 版本号规则说明
# 1. 版本号使用 Git tag，格式为 v1.0.0。
# 2. 如果当前提交没有 tag，找到最近的 tag，计算从该 tag 到当前提交的提交次数。例如，最近的 tag 为 v1.0.1，当前提交距离它有 10 次提交，则版本号为 v1.0.11（v1.0.1 + 10 次提交）。
# 3. 如果没有任何 tag，则默认版本号为 v0.0.0，后续提交次数作为版本号的次版本号。

BRANCH := $(shell git rev-parse --abbrev-ref HEAD)
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
# 最新 tag
NEW_TAG := v$(GIT_VERSION_MAJOR).$(GIT_VERSION_MINOR).$(FINAL_PATCH)

.PHONY: vinfo
## vinfo: 获取最新 tag
vinfo:
	@echo "当前分支最新 tag: $(NEW_TAG)"

.PHONY: git/tag
## git/tag: 自动为当前提交打 tag，tag 注释包含最近提交记录
git/tag:
	@COMMITS=$$(git log '$(RECENT_TAG)'..HEAD --oneline --no-merges 2>/dev/null || echo "No previous tag found"); \
	if [ -z "$$COMMITS" ]; then \
		git tag -a $(NEW_TAG) -m "Release $(NEW_TAG)"; \
	else \
		MSG=$$(printf "Release $(NEW_TAG)\n\nChanges:\n%s" "$$COMMITS"); \
		git tag -a $(NEW_TAG) -m "$$MSG"; \
	fi; \
	echo "已打 tag: $(NEW_TAG)"

## git/push: 发布产品到 Github 和 Gitee
git/push:
	@git push
	@git push gitee
	@git push --tags
	@git push gitee --tags
	@echo "push Successed"
