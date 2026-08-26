# AI 自动化可视化测试：怎么执行一个场景

> 对应 `develop_plan.md` 第五章。本文件是**唯一的执行说明来源**——工作区根目录下的
> `.claude/skills/visual-test/SKILL.md` 只是一个指路的触发器，不重复本文件的内容
> （workspace 根目录不是 git 仓库，不受版本控制，改动一律改这里）。
>
> 读者是 AI Agent。人类开发者也能照做，但格式是为 Agent 优化的。

## 设计原则：不写解释器，直接用已有工具

结构化 Spec（下方格式）描述"做什么"，但**执行它不需要一个专门的运行时程序**：

| Spec 里的动作 | 用什么执行 | 为什么不写脚本 |
|---|---|---|
| `navigate` / `click` / `fill` | `mcp__chrome-devtools__*` 工具 | 这些工具本来就存在，且出错时你能自己读 `take_snapshot`/console/network 现场诊断——这正是"AI 自动化"相对传统 E2E 框架的价值所在，写死一个 Puppeteer 驱动会把这个价值让渡掉 |
| 截图证据 | `mcp__chrome-devtools__take_screenshot` | 同上 |
| `type: db` 断言 | `Bash` 起一条 `mysql ... -e "<query>"`，比对输出文本 | 这只是一次查询 + 字符串比较，你自己做比写一个 Node 脚本再调用它更直接、更少故障点 |
| 报告 | `Write` 直接写 Markdown | 同上 |

**结论：本项目在这一层不维护任何自定义代码**，只维护 Spec 格式的约定 + 这份执行说明。
如果发现自己想去写一个"辅助脚本"，先停下来对照 CLAUDE.md 4.7 的判据——大概率不该写。

## 执行前置条件

1. 确认目标环境已经在跑：`./scripts/dev.sh dev status`（联调用共享环境）或
   `./scripts/dev.sh test status`（隔离测试环境）。没起的话先 `dev.sh dev up` /
   `dev.sh test up`。拿到当前 worktree 的：
   - 前端地址：`http://localhost:<FRONTEND_PORT>`
   - DB 连接参数（host/port/schema/user/password）
2. 记下当前 worktree 的 slug（`dev.sh slug` 第一行），证据目录按 slug 隔离，
   避免多个 worktree 同时跑测试时互相覆盖证据文件。

## Spec 格式

场景文件放在 `docs/testing/scenarios/<name>.yaml`。字段定义：

```yaml
scenario: <一句话场景名，用于报告标题>
description: <可选，场景验证的是什么、为什么值得测>

preconditions:
  - login_as: <用户名，如 admin>   # 目前只支持这一种；固定走 sample-app 的初始账号

steps:                              # 按顺序执行
  - action: navigate
    target: <路径，相对前端根，如 /system/dept>
  - action: click
    selector: <CSS 选择器，一律用 [data-testid="..."]，不用其他任何选择器>
  - action: fill
    selector: <同上>
    value: <要填入的文本>

assertions:                         # 全部执行，不因前面失败就跳过——要看清全貌
  - type: ui
    selector: <[data-testid="..."]>
    expect: contains_text("<子串>")
  - type: db
    query: <单条 SELECT，只返回一行一列>
    expect: equals(<期望值，数字不加引号，字符串加引号>)

cleanup:                            # 可选。有副作用（新增/修改数据）的场景必须写，
  - query: <DELETE/UPDATE，把 steps 造成的数据改回原状>   # 保证场景可重复执行

evidence:
  - screenshot: after_each_step     # 目前只支持这一种策略，先都截
  - console_log: on_error
  - network_log: on_error
```

`selector` 只允许 `[data-testid="..."]`——这是 CLAUDE.md 4.4 的硬约定，页面上出现
交互元素没有 `data-testid` 视为该页面"未完成"，不要退而求其次用别的选择器，那等于在
帮它遮掩这个缺口。

`expect` 只有两种：
- `equals(x)`：db 断言的返回值等严格相等（字符串按字面比较，数字按数值比较）
- `contains_text(s)`：ui 断言，元素文本包含子串 `s`

## 执行步骤（照这个顺序做）

1. **建证据目录**：`docs/testing/results/<slug>/<scenario文件名>-<YYYYMMDD-HHMMSS>/`
   （直接用 `Bash` `mkdir -p` 即可，不需要脚本）。这个目录不进 git
   （见 `docs/.gitignore` 的 `testing/results/`）。

2. **读 Spec**：用 `Read` 直接读 YAML 文件——你能原生理解 YAML，不需要先转 JSON。

3. **走 preconditions**：`login_as: admin` 就是导航到登录页（一般是 `/auth/login`
   或直接访问受保护路径后被重定向过去，以实测为准），依次
   `fill [data-testid="login-username-input"]`、
   `fill [data-testid="login-password-input"]`、
   `click [data-testid="login-submit-btn"]`
   （这三个选择器已对照 `frontend/packages/effects/common-ui/src/ui/authentication/login.vue`
   核实，2026-08-26；密码用 sample-app 默认账号 `admin`/`admin123`，
   见 `application-local.yml` 注释）。页面改动后如果选择器变了，这里要跟着改，
   不要凭这份文档反推页面长什么样。

4. **逐条执行 steps**：
   - `navigate` → `mcp__chrome-devtools__navigate_page`
   - `click`/`fill` → **`mcp__chrome-devtools__click`/`fill` 不接受 CSS 选择器**，
     只接受 `take_snapshot` 返回的 `uid`。Spec 里的 `selector`（`[data-testid="..."]`）
     是给人看的机器可读锚点，标明"应该操作页面上的哪个元素"，不是能直接喂给工具的参数。
     实际执行顺序固定是：先 `take_snapshot`（弹窗/表单出现后要重新截一次，`uid` 每次快照
     都会变），对照对应 Vue 源码里 `data-testid` 所在元素的可见文本/角色（比如
     `dept-add-btn` 对应按钮文本"新增"、`dept-dept-name-input` 对应"部门名称"文本框），
     在快照输出里找到那一行，取它的 `uid` 去调 `click`/`fill`。工具报错找不到元素时，
     先怀疑页面还没渲染完（用 `wait_for`）或者快照已经过期（提交/弹窗后要重新
     `take_snapshot`），而不是怀疑 `data-testid` 写错——后者应该是读源码核实过的
   - 每步完成后 `take_screenshot`，`filePath` 参数直接传证据目录下的绝对路径
     （`step-<序号>-<简述>.png`），工具会直接落盘，不需要额外读回来再 `Write`

5. **执行 assertions**（全部执行，即使某条已经能预判失败——报告需要完整信息）：
   - `type: ui`：`take_snapshot` 里搜 `expect` 给的子串是否作为某个节点的文本出现，
     出现即 `contains_text` 通过（不需要先定位到 `selector` 对应元素——判断"这段文字
     出现在了页面上"比"这段文字出现在指定元素里"更省事，也够用；后者才需要先找到
     该元素的 `uid` 再取它的可访问名/子节点文本）
   - `type: db`：`Bash` 执行
     ```
     mysql -h<host> -P<port> -u<user> -p<password> --default-character-set=utf8mb4 \
       -N -B -e "<query>" <schema>
     ```
     （`-N -B` 去表头、用 tab 分隔，方便直接比对单值；密码走命令行参数在本地开发环境
     可接受，这不是生产凭据）。把返回值与 `expect` 比对。

6. **出错处理**：任意一步失败，不要中途放弃——继续把剩下能执行的 assertions 跑完，
   并额外采集 `list_console_messages` 与 `list_network_requests` 存进证据目录
   （`console.json`/`network.json`），这是排查"到底是前端问题还是后端问题"的关键材料。

7. **cleanup**：Spec 里有 `cleanup` 就执行，方式同 db 断言，用 `Bash` + `mysql`。
   忘记这步会导致场景第二次跑时断言逻辑对不上（比如 `contains_text` 命中的是上一次
   跑剩下的脏数据，而不是本次真正新建的）。

8. **写报告**：`Write` 一份 `report.md` 到证据目录，至少包含：
   - 场景名、执行时间、目标环境（dev/test + slug）
   - 每个 step 的执行结果（成功/失败 + 失败时的错误信息）
   - 每条 assertion 的实际值 vs 期望值、通过与否
   - 证据文件清单（相对路径）
   - 总体结论：全部通过 / 部分失败（列出具体哪几条）

9. **如实汇报**：不要因为"页面看起来正常"就判定通过——这正是 CLAUDE.md 3.6/develop_plan.md
   5.4 反复强调的"不能仅凭视觉判断下结论"。UI 断言和 DB 断言必须都通过才算通过；
   只有 UI 断言通过、DB 断言没查或没通过，如实报告为"部分通过"，不要合并成"通过"。

## 目录约定

```
docs/testing/
├── VISUAL_TESTING.md      本文件
└── scenarios/
    └── dept-create.yaml   首个场景，见下

docs/testing/results/       证据与报告输出（不进 git）
└── <slug>/
    └── <场景文件名>-<时间戳>/
        ├── step-1.png ...
        ├── console.json    仅出错时
        ├── network.json    仅出错时
        └── report.md
```

## 现状（2026-08-26）

`scenarios/dept-create.yaml` 已经真实跑通一次（针对当时手工起的联调环境，非
`dev.sh dev up` 拉起的环境），报告见
`testing/results/1366b1e4/dept-create-20260826-093540/report.md`。**已验证**：
steps（navigate/click/fill）+ 两条 assertions（ui/db）+ cleanup 全流程，
第 4 步"`click`/`fill` 只认 `uid` 不认 CSS 选择器"这条修正就是跑这一次时发现的。

**尚未验证**：
- `preconditions.login_as` 这条路径——当时浏览器已带登录态，跳过了真正走一遍登录表单
- `evidence` 里 `console_log`/`network_log: on_error` 这条分支——这次全部断言都通过，
  没有真实触发过"出错时多采集一份证据"的路径
- `./scripts/dev.sh dev up` 拉起的环境——这次用的是已经在跑的手工环境，dev.sh 本身
  能否正确把 sample-app/sample-frontend 拉起来仍是 [PROGRESS.md](../PROGRESS.md)
  记录的已知验证缺口

下次执行覆盖到以上任一点时，照这个格式继续往这里或场景文件注释里补记。
