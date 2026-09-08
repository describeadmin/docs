import { defineConfig } from 'vitepress'

// describeadmin 官方文档
// 信息架构按 Diátaxis 四分法：教程 / 操作指南 / 参考 / 解释。
// 站点为纯静态产物（vitepress build → .vitepress/dist），可直接部署到内网 nginx，
// 契合「无公网出口」这一设计目标。
export default defineConfig({
  lang: 'zh-CN',
  title: 'describeadmin',
  description: '面向政务 / 企业管理后台的平台 / SDK — 官方文档',
  lastUpdated: true,
  cleanUrls: true,
  // 公网部署到 GitHub Pages 时的子路径；内网部署可用 --base 覆盖或改回 '/'
  base: '/',

  head: [
    ['meta', { name: 'theme-color', content: '#3c8772' }],
  ],

  themeConfig: {
    outline: { label: '本页目录', level: [2, 3] },
    docFooter: { prev: '上一篇', next: '下一篇' },
    lastUpdatedText: '最后更新',
    returnToTopLabel: '回到顶部',
    sidebarMenuLabel: '菜单',
    darkModeSwitchLabel: '主题',
    lightModeSwitchTitle: '切换到浅色模式',
    darkModeSwitchTitle: '切换到深色模式',

    nav: [
      { text: '教程', link: '/guide/getting-started' },
      { text: '操作指南', link: '/how-to/' },
      { text: '参考', link: '/reference/configuration' },
      { text: '解释', link: '/explanation/platform-not-template' },
      {
        text: '相关',
        items: [
          { text: '当前限制与路线图', link: '/about/limitations' },
          { text: '贡献指南', link: '/about/contributing' },
          { text: 'GitHub 组织', link: 'https://github.com/describeadmin' },
        ],
      },
    ],

    search: {
      provider: 'local',
      options: {
        translations: {
          button: { buttonText: '搜索文档', buttonAriaLabel: '搜索文档' },
          modal: {
            noResultsText: '无法找到相关结果',
            resetButtonTitle: '清除查询条件',
            footer: { selectText: '选择', navigateText: '切换', closeText: '关闭' },
          },
        },
      },
    },

    sidebar: {
      '/guide/': [
        {
          text: '教程',
          items: [
            { text: '从零跑起一个管理后台', link: '/guide/getting-started' },
            { text: '加第一个业务模块', link: '/guide/first-module' },
          ],
        },
      ],
      '/how-to/': [
        {
          text: '操作指南',
          items: [
            { text: '概览', link: '/how-to/' },
            { text: '手写一个业务模块（不用 codegen）', link: '/how-to/add-module-manually' },
            { text: '升级框架版本', link: '/how-to/upgrade' },
          ],
        },
        {
          text: '接入插件',
          items: [
            { text: '接入 Redis（缓存 / 令牌）', link: '/how-to/cache-redis' },
            { text: '接入 S3 对象存储', link: '/how-to/storage-s3' },
            { text: 'Excel 导入导出', link: '/how-to/excel' },
            { text: '字段加密', link: '/how-to/crypto' },
            { text: '邮箱登录', link: '/how-to/auth-email' },
          ],
        },
        {
          text: '扩展框架',
          items: [
            { text: '自定义登录方式（AuthProvider）', link: '/how-to/custom-auth-provider' },
            { text: '自定义消息通道（NotifyChannel）', link: '/how-to/custom-notify-channel' },
          ],
        },
        {
          text: '部署与运维',
          items: [
            { text: '部署到无公网出口的内网', link: '/how-to/offline-deployment' },
            { text: '切换到国产化数据库', link: '/how-to/domestic-database' },
            { text: '切换到雪花 ID', link: '/how-to/snowflake-id' },
          ],
        },
      ],
      '/reference/': [
        {
          text: '参考',
          items: [
            { text: '配置项清单（describeadmin.*）', link: '/reference/configuration' },
            { text: 'Starter 目录', link: '/reference/starters' },
            { text: 'SPI 接口', link: '/reference/spi' },
            { text: 'codegen YAML spec', link: '/reference/codegen-spec' },
            { text: '框架约定（权限点 / Result / 分页）', link: '/reference/conventions' },
            { text: '兼容性矩阵', link: '/reference/compatibility' },
            { text: '前端包目录（@describeadmin/*）', link: '/reference/frontend-packages' },
          ],
        },
      ],
      '/explanation/': [
        {
          text: '解释',
          items: [
            { text: '平台 / SDK，不是模板', link: '/explanation/platform-not-template' },
            { text: '分层模型（Platform 层 vs Business 层）', link: '/explanation/layering' },
            { text: '为什么钉在上一代技术栈', link: '/explanation/tech-choices' },
            { text: '面向 AI 编程的设计', link: '/explanation/ai-oriented-design' },
          ],
        },
      ],
      '/about/': [
        {
          text: '相关',
          items: [
            { text: '当前限制与路线图', link: '/about/limitations' },
            { text: '贡献指南', link: '/about/contributing' },
            { text: '许可证', link: '/about/license' },
          ],
        },
      ],
    },

    socialLinks: [
      { icon: 'github', link: 'https://github.com/describeadmin' },
    ],

    editLink: {
      pattern: 'https://github.com/describeadmin/docs/edit/main/site/:path',
      text: '在 GitHub 上编辑此页',
    },

    footer: {
      message: '后端 Apache-2.0 / 前端 MIT',
      copyright: 'describeadmin',
    },
  },
})
