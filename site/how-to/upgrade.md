# 升级框架版本

::: info 本页待补充
本页是文档骨架的占位页，内容正在编写中。下方列出的是本页将覆盖的要点与素材来源。
:::

## 本页将覆盖

| 层 | 动作 |
|---|---|
| 后端框架 | 改 `<describeadmin.version>` 一行 |
| 前端包 | `pnpm up "@describeadmin/*"` |
| 生成的业务代码 | 不动——通用逻辑在框架基类里 |
| 应用外壳 | 不会自动升级，由 CHANGELOG 提示手工跟进 |

- 为什么「外壳尽可能薄」是升级机制成立的前提
- CHANGELOG 的 Breaking / Feature / Fix 三分法怎么读
- 插件版本与框架版本**没有对应关系**，单独看各插件的 CHANGELOG

## 素材来源
- `docs/QUICKSTART.md` §7、`docs/CLAUDE.md` §5、§4.6
- [参考 · 兼容性矩阵](/reference/compatibility)
