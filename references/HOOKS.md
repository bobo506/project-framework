# Project Framework Hook Specification

本文档定义项目管理 hook 的通用规范。规则是 agent 无关的；具体执行方式由 Codex、Claude Code、Git hook 或人工脚本适配。

## 分层

- Skill 规则层：`SKILL.md` 说明什么时候需要检查、什么时候需要暂停。
- Hook 规范层：本文档说明各检查嵌入在哪个环节、是否阻断、失败后怎么办。
- 脚本执行层：`scripts/` 中的脚本执行可机械判断的检查。

## Hook 列表

### HOOK-001 切片用量门禁

- 触发环节：每个开发切片结束后、准备开启下一个切片前。
- 阻断类型：阻断型。
- Codex 执行：
  - `usage-gate guard --provider codex --json`
  - 或 `powershell -ExecutionPolicy Bypass -File scripts/slice-usage-gate.ps1 -Agent codex`
- Claude Code 执行：
  - 通过 statusline 将用量写入 `~/.claude/usage.json`
  - 运行 `powershell -ExecutionPolicy Bypass -File scripts/slice-usage-gate.ps1 -Agent claude`
- 通过条件：
  - Codex 返回有效用量且 `decision` 为 `continue`
  - Claude Code 的 5 小时窗口低于 85%，且 7 天窗口低于 80%
- 失败处理：
  - 达到阈值或门禁要求暂停时，不开启新切片。
  - 先完成验证、汇总进度、提交，并输出 `继续项目`。
  - 用量不可得时进入 `SKILL.md` 中"无法获取 token 用量时"的规则。

### HOOK-002 切片收尾检查

- 触发环节：每个切片结束时。
- 阻断类型：提醒型；当本轮有实际变更时应升级为阻断型。
- 检查内容：
  - 是否有代码或文档改动。
  - 若有改动，是否需要更新进度。
  - 若需要更新进度，进入 HOOK-003。
- 失败处理：
  - 先更新进度，再继续提交或开启下一切片。

### HOOK-003 进度更新质量检查

- 触发环节：更新 `PROGRESS.md` / `PROGRESS_HISTORY.md` 时，以及切片收尾需要确认进度质量时。
- 阻断类型：阻断型。
- 执行：
  - `powershell -ExecutionPolicy Bypass -File scripts/check-progress.ps1 -Strict -RequireHistory`
- 检查内容：
  - 能找到进度文件。
  - 当前进度包含当前状态、下一步、验证、变更文件等核心信息。
  - 历史进度文件存在。
  - `PROGRESS.md` 保持当前快照，完整历史进入 `PROGRESS_HISTORY.md`。
- 失败处理：
  - 补齐进度记录后重新检查。

### HOOK-004 提交前检查

- 触发环节：`git commit` 前、`git push` 前。
- 阻断类型：阻断型。
- 执行：
  - `powershell -ExecutionPolicy Bypass -File scripts/check-git-ready.ps1`
- 检查内容：
  - Git 工作区无冲突标记。
  - `git diff --check` 通过。
  - 若项目存在进度文件，则检查基本进度结构。
  - 提交和 GitHub 可读描述应使用中文。
- 失败处理：
  - 修复格式、冲突标记或进度记录后再提交。

### HOOK-005 上下文交接/清除门禁

- 触发环节：准备清上下文、开启新窗口、或发现上下文接近上限时。
- 阻断类型：阻断型。
- 检查内容：
  - 是否已执行汇总进度。
  - 是否已完成必要验证。
  - 若本轮有改动，是否已提交。
- 失败处理：
  - 先汇总、落盘、验证、提交，再清上下文。

### HOOK-006 人工验收门禁

- 触发环节：完成可独立体验的里程碑版本时。
- 阻断类型：提醒型；默认阻止继续扩展新功能。
- 检查内容：
  - 是否完成必要验证。
  - 是否提交可回溯版本。
  - 是否提供中文验收说明、启动方式、入口、已知限制。
- 失败处理：
  - 补齐验收材料，等待项目管理者人工确认。

### HOOK-007 Skill 自身维护检查

- 触发环节：修改本 skill 后、提交前。
- 阻断类型：阻断型。
- 执行：
  - `powershell -ExecutionPolicy Bypass -File scripts/check-skill.ps1`
- 检查内容：
  - `SKILL.md` 存在合法 frontmatter。
  - Markdown 代码围栏成对。
  - 无 Git 冲突标记。
  - `git diff --check` 通过。
- 失败处理：
  - 修复 `SKILL.md` 或格式问题后再提交。

## 适配原则

- Codex 当前未假设存在统一原生 hook 配置；由 `SKILL.md` 在对应环节要求调用脚本或命令。
- Claude Code 可用 hooks/statusline 触发等价检查；用量数据由 statusline 持久化到本地 JSON。
- Git 相关检查优先接入 Git hooks，也可由 agent 在提交前手动运行脚本。
- 其他 agent 只要能执行 shell 命令，就应复用 `scripts/` 中的检查脚本。
