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

# test:
# 	@echo ">>>${RECENT_TAG}"

# ==================================================================================== #
# BUILD
# ==================================================================================== #


## build/local: 本地构建应用，构建物输出目录 dist
.PHONY: build/local
build/local: 
	@goreleaser build --snapshot --clean


# ==================================================================================== #
# PRODUCTION
# ==================================================================================== #

PRODUCTION_HOST = remoteHost

## release/push: 发布产品到服务器，仅上传文件
# 中小项目可以引入 CI/CD，也可以通过命令快速发布到测试服务器上。
release/push:
	@scp build/linux_amd64/bin $(PRODUCTION_HOST):/home/app/$(MODULE_NAME)
	@echo "push Successed"
