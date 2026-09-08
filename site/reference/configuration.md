# 配置项清单（describeadmin.*）

::: info 本页待补充
本页是文档骨架的占位页，内容正在编写中。下方列出的是本页将覆盖的要点与素材来源。
:::

## 本页将覆盖
按前缀分组列出每个配置项的**默认值、类型、作用**，例如：

| 前缀 | 说明 |
|---|---|
| `describeadmin.web.trace.*` | traceId 生成与透传 |
| `describeadmin.web.json.*` | JSON 序列化（`Long` 转字符串、时间格式，见 §4.8） |
| `describeadmin.security.*` | 令牌、`permission-enabled` 开关 |
| `describeadmin.system.*` | `dev-seed`、口令策略、登录锁定 |
| `mybatis-plus.global-config.db-config.id-type` | 自增 / 雪花 |
| `spring.sql.init.encoding` | **必须显式 `UTF-8`** |

## 素材来源
- 各 starter 的 `@ConfigurationProperties` 类（`autoconfigure/` 包）
- `docs/CLAUDE.md` §2、§3.6、§4.5、§4.8
