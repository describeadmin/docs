# 当前限制与路线图

::: info 本页待补充
本页是文档骨架的占位页，内容正在编写中。下方列出的是本页将覆盖的要点与素材来源。
:::

::: info 为什么单列一页
「文档说能用」和「真的做完了」是两回事。本页诚实记录当前版本**还给不了**什么，
避免你按着教程做到一半才发现方向不对。
:::

## 后端已经是「一条命令生成空工程」

archetype 生成的工程 import 一个 BOM + 四个 starter，开箱可登录，带用户 / 角色 /
菜单 / 部门管理。

## 前端仍是「以样例仓库为起点」

| 缺什么 | 后果 | 当前替代做法 |
|---|---|---|
| 前端脚手架 `npm create @describeadmin/app` | 没有生成应用外壳的命令 | 以 `frontend/apps/admin` 为起点复制 |
| `@describeadmin/system-ui` | 系统管理四个页面还在应用外壳里，你会永久拥有这些代码，框架后续对它们的修复到不了你那里 | 暂时接受；关注 CHANGELOG 手工跟进 |

克隆整个 `frontend` 会同时得到 `packages/`（框架）和 `apps/admin`（应用外壳），
你真正需要拥有的只有 `apps/admin`。把 `packages/` / `internal/` 删掉、把
`apps/admin/package.json` 的 `workspace:*` 依赖改成版本号从 npm 拉包——**这一步官方尚未实测**。

## 两边不对称是当前的真实状态

后端「一条命令生成」、前端「以样例为起点」——不是本文的简化写法。

## 素材来源
- `docs/QUICKSTART.md` §0 与「本文的验证状态」一节
- `docs/PROGRESS.md`（维护者进度）
