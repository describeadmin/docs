# 框架约定（权限点 / Result / 分页）

::: info 本页待补充
本页是文档骨架的占位页，内容正在编写中。下方列出的是本页将覆盖的要点与素材来源。
:::

## 本页将覆盖
- **权限点**：`<模块>:<对象>:<动作>`，动作只有 `list` / `add` / `edit` / `remove`。推导与授权数据必须对得上（模块名含下划线 / 自定义 apiPrefix 时连 ADMIN 都 403 的陷阱）。权限快照在登录时确定。
- **`Result<T>`**：`code` / `msg` / `data` 结构，Controller 一律返回它，异常交给全局处理器。
- **分页返回**：`PageResult` 的 `total` / `current` / `size` / `pages` 是数字形态（`@JsonFormat(shape = NUMBER)`），其余 `Long` 默认转字符串。
- **审计字段**：创建人 / 创建时间 / 更新人 / 更新时间 / 逻辑删除由 `BaseEntity` 承担。

## 素材来源
- `docs/CLAUDE.md` §3.3、§4.1、§4.3、§4.5、§4.8
