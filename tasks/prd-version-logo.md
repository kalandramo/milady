# PRD: Version 命令 ASCII Art Logo 展示

## 1. Introduction

当前 `milady version` 命令仅输出纯文本格式的版本信息。参考 goreleaser 的 CLI 体验，在版本信息上方添加一个 ASCII Art 风格的 "MILADY" Logo，提升 CLI 的视觉辨识度和品牌感。

## 2. Goals

- 在 `milady version` 输出顶部展示 ASCII Art 风格的 "MILADY" Logo
- Logo 为纯文本形式，无颜色，与 goreleaser 风格一致
- 保持原有版本信息完整输出，仅在其上方追加 Logo
- 确保 Logo 在不同终端宽度下不会错位（固定宽度字体下 80 列内）

## 3. User Stories

### US-001: 在 version 输出中展示 MILADY ASCII Art Logo
**Description:** 作为用户，我希望在运行 `milady version` 时看到 MILADY 的 ASCII Art Logo，以便增强品牌识别。

**Acceptance Criteria:**
- [ ] 运行 `milady version` 后，首行输出 MILADY 的 ASCII Art Logo
- [ ] Logo 下方空一行，再输出原有的版本信息（与当前行为一致）
- [ ] Logo 为纯文本黑白形式，不使用 ANSI 颜色
- [ ] Logo 整体宽度不超过 80 字符（标准终端宽度）
- [ ] 在 40 列宽度的终端中不会严重错位（可选截断或保持）
- [ ] 编译通过，无 lint 错误

### US-002: 支持通过 flag 隐藏 Logo
**Description:** 作为自动化脚本使用者，我希望可以通过 flag 隐藏 Logo 仅输出版本信息，以便脚本解析不受干扰。

**Acceptance Criteria:**
- [ ] 新增 `--short` 或 `-s` flag 时，不输出 Logo，仅输出原有版本信息
- [ ] 新增 `--json` 或 `-j` flag 时，不输出 Logo，仅输出 JSON 格式版本信息
- [ ] 默认行为（无 flag）为展示 Logo
- [ ] Typecheck/lint 通过

## 4. Functional Requirements

- FR-1: 系统必须在 `version` 命令输出顶部展示 MILADY ASCII Art Logo
- FR-2: Logo 设计必须使用等宽字体友好的字符，拼出 "MILADY" 字样
- FR-3: Logo 与版本信息之间空一行分隔
- FR-4: 当用户传入 `--short` flag 时，跳过 Logo 输出，仅输出原有版本信息
- FR-5: 当用户传入 `--json` flag 时，跳过 Logo 输出，仅输出 JSON 格式版本信息
- FR-6: ASCII Art Logo 内容定义在独立文件中（如 `pkg/version/logo.go` 或 `assets/logo.txt`），便于后续修改

## 5. Non-Goals (Out of Scope)

- 不支持 ANSI 颜色高亮（后续可加）
- 不支持根据终端宽度自适应 Logo 大小
- 不支持图片/Emoji 形式的 Logo
- 不支持其他子命令展示 Logo（仅 version 命令）

## 6. Design Considerations

- ASCII Art 风格参考 goreleaser 的 Logo，简洁大方
- 建议使用工具（如 [patorjk ASCII Art Generator](http://patorjk.com/software/taag/#p=testall&f=Big%20Money%20ne)）生成基础字形，然后手动微调
- Logo 字体推荐：Block、Slant、Banner 等风格
- 颜色：纯文本，无颜色

## 7. Technical Considerations

- 在 `pkg/version` 包中新增 `Logo()` 函数，返回 ASCII Art 字符串
- 修改 `cmd/milady/internal/cmd/version.go`，在输出版本信息前打印 Logo
- 通过 cobra 的 `cmd.Flags()` 添加 `--short` flag
- Logo 字符串建议存放在独立文件 `pkg/version/logo.go` 中，作为 `const` 定义
- 需确保 Logo 在 `go run` 和 `go build` 两种模式下均正常展示

## 8. Success Metrics

- 运行 `milady version` 后，Logo 清晰可读，无字符错位
- 添加 `--short` flag 后，输出与添加前行为一致（仅版本信息）
- 不影响现有 CI/CD 中通过 `milady version --json` 获取版本信息的流程

## 9. Open Questions

- Logo 的具体 ASCII Art 设计稿由实现者确定（可参考 goreleaser 风格）
- 是否需要支持 `--logo` flag 显式开启/关闭 Logo？（当前方案以 `--short` 作为隐藏方式）
