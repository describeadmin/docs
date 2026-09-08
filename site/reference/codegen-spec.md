# codegen YAML spec

::: info 本页待补充
本页是文档骨架的占位页，内容正在编写中。下方列出的是本页将覆盖的要点与素材来源。
:::

## 本页将覆盖
YAML spec 的字段逐项说明：

- 顶层：`layout`（flat / nested，优先级 `--layout` > spec `layout:` > `CODEGEN_LAYOUT` > 默认 nested）
- 模块名、表名、`apiPrefix` / `permPrefix`
- 字段定义：类型映射、是否查询条件、日期选择器 `value-format`
- 产物开关：`--out` / `--frontend-out`

## 素材来源
- codegen 仓 [`examples/project.yaml`](https://github.com/describeadmin/codegen/blob/main/examples/project.yaml)
- `docs/CLAUDE.md` §4.4、§4.5、§4.10
