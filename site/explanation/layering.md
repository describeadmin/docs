# 分层模型（Platform 层 vs Business 层）

::: info 本页待补充
本页是文档骨架的占位页，内容正在编写中。下方列出的是本页将覆盖的要点与素材来源。
:::

## 本页将覆盖
- **Platform 层**（`framework` / `framework-*-starter` / `codegen`）：框架团队维护，版本化发布，改动考虑向后兼容
- **Business 层**：业务方维护，只通过 Maven / npm 依赖引用 Platform 层
- starter 内部包结构：`autoconfigure/` `api/`（兼容性承诺）`core/` `util/`（不在承诺范围）
- 多仓拓扑：改一个 SPI 通常要同步改 `framework` + 对应 `ext` + `frontend`

## 素材来源
- `docs/CLAUDE.md` §0、§2、`docs/develop_plan.md` 3.1
