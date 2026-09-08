# 切换到国产化数据库

::: info 本页待补充
本页是文档骨架的占位页，内容正在编写中。下方列出的是本页将覆盖的要点与素材来源。
:::

## 本页将覆盖
- 达梦 / 金仓 / OceanBase 的 MySQL 兼容通常是**子集**而非超集
- SQL 红线：不用窗口函数 / CTE / 函数索引 / `JSON_TABLE` / 多列 `ON UPDATE CURRENT_TIMESTAMP`
- `CHARACTER SET` 与 `COLLATE` 必须显式声明
- MyBatis-Plus 的 `DbType` 必须是配置项，不硬编码
- JDBC 驱动由业务方自己在 `pom.xml` 声明，框架不引

## 素材来源
- `docs/CLAUDE.md` §3（数据库约定，强制）
- `docs/develop_plan.md` 2.3.3 / 5.5
