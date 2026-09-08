# describeadmin 官方文档站点

面向**使用者**的文档，用 [VitePress](https://vitepress.dev/) 编写。
维护者文档（设计方案、版本基线、编码规范母本、发布手册）在 `docs` 仓根目录，不在这里。

## 本地开发

```bash
cd site
npm install
npm run dev        # http://localhost:5173
```

## 构建

```bash
npm run build      # 产物在 site/.vitepress/dist，纯静态
npm run preview    # 本地预览构建产物
```

## 部署

- **公网**：推 `main` 且改动了 `site/**` 时，`.github/workflows/docs.yml` 自动构建并发布到 GitHub Pages。
- **内网（无公网出口）**：本地 `npm run build`，把 `site/.vitepress/dist` 整个目录塞进 nginx。
  子路径部署用 `npm run build -- --base /your-path/` 覆盖 `base`。

## 信息架构（Diátaxis 四分法）

| 目录 | 定位 | 写什么 |
|---|---|---|
| `guide/` | 教程 | 跟着做一定能成，学习导向 |
| `how-to/` | 操作指南 | 解决一个具体问题，任务导向 |
| `reference/` | 参考 | 查数据：配置项、SPI 签名、版本矩阵 |
| `explanation/` | 解释 | 为什么这么设计，链回 `develop_plan.md` |
| `about/` | 相关 | 当前限制、贡献指南、许可证 |

## 约定

- **版本号单一事实来源**是 `reference/compatibility.md`。其他页面出现版本号时链过去，不散落硬编码。
- **命令必须实测**后才写进正文；未实测的步骤明确标注，不混在实测步骤里。
- 编码规范不在本站重复，只链接到 `docs/CLAUDE.md`。
