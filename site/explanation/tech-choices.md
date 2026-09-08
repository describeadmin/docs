# 为什么钉在上一代技术栈

::: info 本页待补充
本页是文档骨架的占位页，内容正在编写中。下方列出的是本页将覆盖的要点与素材来源。
:::

## 本页将覆盖
多处「有意选择上一代技术」，不是过时待升级：

| 选择 | 为什么不升 |
|---|---|
| Spring Boot 3.5.16（不上 4.x） | 见 `develop_plan.md` 2.2.1 |
| Jackson 2.x（不用 `tools.jackson.*`） | 生态与稳定性 |
| `mysql-connector-j` 8.2.0 | 8.3.0 起官方不再支持 MySQL 5.7 |
| 不用 `maven-toolchains-plugin` | 没配 `toolchains.xml` 的人直接构建失败，比它要防的坑更劝退 |

## 素材来源
- `docs/develop_plan.md` 2.2、`docs/VERSION_BASELINE.md`、`docs/CLAUDE.md` §1
