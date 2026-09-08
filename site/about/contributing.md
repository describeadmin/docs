# 贡献指南

::: info 本页待补充
本页是文档骨架的占位页，内容正在编写中。下方列出的是本页将覆盖的要点与素材来源。
:::

## 本页将覆盖
- 多仓拓扑：日常开发并列检出【目标仓 + docs】两个仓；跨 SPI 完整上下文用 `docs/scripts/clone-all.sh`
- 编码规范唯一母本是 [`docs/CLAUDE.md`](https://github.com/describeadmin/docs/blob/main/CLAUDE.md)，本页不重复，只指路
- 判断改动在哪一层（Platform / Business），Platform 层改动走 SemVer
- 新增插件必须同时登记到 `docs/registry.md` 和 `docs/repos.yml`
- 发布流程见 `docs/RELEASE.md`（维护者）

## 素材来源
- `docs/CLAUDE.md` 全文、`docs/registry.md`、`docs/RELEASE.md`
