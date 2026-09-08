# 部署到无公网出口的内网

::: info 本页待补充
本页是文档骨架的占位页，内容正在编写中。下方列出的是本页将覆盖的要点与素材来源。
:::

## 本页将覆盖
- 这是项目三大目标之一，本页是完整清单
- 后端：私服镜像 Maven Central 制品、`mysql-connector-j` 8.2.0 固定、离线构建
- 前端：私有 npm registry 或 `pnpm deploy` 离线包
- 文档站：`vitepress build` 出纯静态产物，`--base` 指定内网子路径，塞进 nginx
- codegen jar 随包分发到内网
- 数据库为国产化库时的额外注意事项（交叉引用下一篇）

## 素材来源
- `docs/README.md` 三个设计目标、`docs/develop_plan.md` 相关章节
- `docs/CLAUDE.md` §1（版本与环境）、§3.4（JDBC 驱动）
