# 兼容性矩阵

::: info 本页待补充
本页是文档骨架的占位页，内容正在编写中。下方列出的是本页将覆盖的要点与素材来源。
:::

## 本页将覆盖
一张**版本对应关系**总表——这是全站关于版本号的唯一事实来源。

| 组件 | 当前版本 | 说明 |
|---|---|---|
| `framework`（含 `describeadmin-archetype`） | 见发布页 | archetype 与框架同仓、同号发布 |
| `frontend`（`@describeadmin/*`） | 见发布页 | |
| `codegen` | **可能与框架不同号** | 生成的薄代码对应特定框架版本的基类契约 |
| 各 `framework-*-starter` 插件 | **各自独立版本线** | 与框架版本无对应关系；看各插件 CHANGELOG 与其声明的最低框架版本 |

以及环境硬约束：JDK 17+、Spring Boot 3.5.16、Jackson 2.x、`mysql-connector-j` 8.2.0（有意钉住）、Node `^22.18 || ^24.12`、pnpm `>=11`。

## 素材来源
- `docs/repos.yml`、`docs/VERSION_BASELINE.md`、`docs/CLAUDE.md` §1
- 各仓 GitHub Releases / CHANGELOG
