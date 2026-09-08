# Report template

Use these structures for the generated Chinese Markdown reports and deletion summaries.

## Read-only analysis report

```markdown
# X盘磁盘(清理)分析报告
> 分析时间 / 范围(含排除项) / 重要声明：全程只读，未修改删除任何文件，建议仅供参考

## 一、总体使用情况
(总容量/已用/可用/占用率/磁盘类型/状态，状态告急时提示)
## 二、占用最大的目录/顶层总览表
| 目录 | 大小 | 文件数 | 主要构成 | 清理建议 |
## 三、分类分析与清理建议
- 临时文件（Temp/tmp）
- 浏览器缓存（仅 Cache 子目录）
- Windows 更新缓存 / $WINDOWS.~BT
- 回收站
- 休眠/系统文件（hiberfil/pagefile/swapfile）
- 下载/大型媒体/安装包
- *-updater 更新缓存
- 卸载残留/异常目录
- 开发工具缓存（.gradle/.m2/.hvigor/npm…）
- IM 数据（微信/QQ/飞书等——仅软件内清理）
- 大型软件（卸载建议）
每类给路径表 + ✅建议删除 / 🟡需确认 / ⚠️谨慎(数据) / 🚫勿动
## 四、各目录可清理空间汇总对比表
| 优先级 | 目录/项目 | 预计可释放 | 操作难度/风险 |
## 五、优先清理高价值目标列表
## 六、潜在风险提示（重要）
(系统文件勿删 / 聊天记录数据 / 浏览器 User Data / 运行中程序本体 / 备份建议 / cleanmgr 优先)

*报告声明：数据基于扫描时刻，软件安装/卸载后数值变化。*
```

## Deletion result summary

```markdown
## 清理执行结果
### 已成功删除
| 项目 | 大小 | 结果 |
### 失败项与手动命令
| 路径 | 原因 | 请手动执行 |
(`Remove-Item -LiteralPath '<路径>' -Recurse -Force` 或资源管理器删除；说明回收站包装对大目录的限制是环境问题不是权限问题)
### 提示
- 删除内容位于 <盘>:\$RECYCLE.BIN，清空该盘回收站后才真正释放空间
- 噪音错误说明（SAFE_DELETE_FAIL_CLOSED 不代表失败，以 Test-Path 复核为准）
```
