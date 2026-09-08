# 面向 AI 编程的设计

::: info 本页待补充
本页是文档骨架的占位页，内容正在编写中。下方列出的是本页将覆盖的要点与素材来源。
:::

## 本页将覆盖
- 约定显式、错误在解析期就明确指出（而非运行期才炸）
- 所有交互元素强制带 `data-testid`，命名 `<模块>-<对象>-<动作>`，供 AI 自动化测试稳定定位
- codegen 生成物、种子数据、脚手架都围绕稳定锚点
- `workspace` 仓交付给业务方的 CLAUDE.md + Claude Code skills

## 素材来源
- `docs/README.md` 目标 #3、`docs/CLAUDE.md` §4.4、§7
- `docs/repos.yml` 的 `workspace` 条目
