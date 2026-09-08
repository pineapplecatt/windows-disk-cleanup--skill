# windows-disk-cleanup

Windows（中文环境）磁盘/存储空间清理检测与执行 **WorkBuddy Skill**。

A WorkBuddy skill for analyzing and cleaning up Windows disk/storage space in a sandboxed (WorkBuddy) environment.

## 功能特性

- **只读空间分析（默认）**：扫描目标盘/目录，产出结构化中文 Markdown 报告（总体使用 → 顶层目录表 → 分类建议 → 可释放汇总 → 优先清理 → 风险提示），全程不修改任何文件。
- **确认后删除**：仅在用户逐项确认后执行受控删除（进入回收站、可恢复），分批操作并逐个复核。
- **内置本机环境经验**：PowerShell 无 stdout 需写文件再读、Bash 沙箱读限、被禁 API 清单、"安全删除"包装器的噪音错误与大目录删除限制、回收站按盘独立、后台中文乱码等，全部来自实际执行验证。

## 目录结构

```
windows-disk-cleanup/
├── SKILL.md                    # 技能入口：工作流 + 两种模式 + 触发边界
├── scripts/
│   └── measure_dirs.ps1        # 参数化递归扫描（纯 ASCII，支持后台增量输出）
├── references/
│   ├── environment.md          # 环境硬约束与命令模式（执行前必读）
│   ├── classification.md       # 可删项 vs 陷阱甄别清单
│   └── report-template.md      # 报告与删除结果模板
└── evals/
    └── evals.json              # 测试用例
```

## 安装 / 使用

1. 将 `windows-disk-cleanup/` 放入 WorkBuddy 用户技能目录：`~/.workbuddy/skills/`
2. 之后当用户提到"分析/清理磁盘空间""C盘/D盘满了""删除缓存/大文件/安装包残留"等请求时自动触发。
3. 分析默认只读；删除必须先确认清单再执行。

## 安全原则

- 报告默认只读；删除严格逐项确认、每批 ≤10、删除后 `Test-Path` 复核。
- 聊天记录（微信/QQ）、数据库、浏览器 `User Data`、运行中软件本体、`.workbuddy` 运行环境均只给"软件内清理"指引。
- "安全删除"包装打印的 `SAFE_DELETE_FAIL_CLOSED` 等为噪音错误，成功与否以 `Test-Path` 复核为准。

> Skill 开发于 WorkBuddy Windows 环境并基于真实磁盘清理任务实测沉淀；测试用例见 `evals/evals.json`。
