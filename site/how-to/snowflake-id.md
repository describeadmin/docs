# 切换到雪花 ID

::: info 本页待补充
本页是文档骨架的占位页，内容正在编写中。下方列出的是本页将覆盖的要点与素材来源。
:::

## 本页将覆盖
- 改 `mybatis-plus.global-config.db-config.id-type`，**不要**在实体上硬编码 `@TableId(type=...)`
- 切过去之后：`Long` → 字符串的 JSON 序列化默认已开，前端不会精度丢失
- 要保持数字形态的 `Long` 字段用 `@JsonFormat(shape = NUMBER)` 排除
- `PageResult` 的 `total` / `current` 等是唯一的框架内置例外

## 素材来源
- `docs/CLAUDE.md` §3.3、§4.8（JSON 序列化约定）
