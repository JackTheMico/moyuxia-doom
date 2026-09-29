# ADR 0002: Firefly 博客新建文章命令与文件模板

## 状态

已通过 (Accepted)

## 背景

ADR 0001 解决了 Markdown 排版、图床与预览问题，但"从零开始写一篇新文章"仍需手工完成：在 `~/codes/Firefly/src/content/posts/` 下决定目录、命名字符串、然后凭记忆抄写 Frontmatter 字段。存在的具体痛点：

1. **Frontmatter 字段靠记忆**：posts 集合由 `src/content.config.ts` 的 Zod schema 校验，字段名拼错或漏写会导致 Astro 构建报错；
2. **无统一的"新文章"入口**：`src/content/posts/` 下同时存在 Page Bundle（`guide/index.md`）与单文件（`inputMD/tiger-code.md`）两种历史形态，缺少约定；
3. **URL 与目录耦合不透明**：`src/utils/url-utils.ts` 的 `getPostUrlBySlug` 直接用 `entry.id`（文件相对路径去扩展名）作 slug，因此子目录名会进入 URL（`posts/writing/foo.md` → `/posts/writing/foo/`），这一点在起手写文件时容易被忽略。

用户经逐项确认后选定：**单文件范式**、**每次交互选择子目录**、**只输入 slug**、**字段集对齐仓库现有文章**、**光标停在正文首行**、**键位 `, n p`**。

## 决策

1. **frontmatter 单一真源**：新增纯函数 `+firefly-post-frontmatter (slug)`，输出固定字段集
   `title`（slug 占位）/`published`（`%Y-%m-%d`）/`description: ""`/`image: ""`/`tags: []`/`category:`，
   以空行结尾。**不写 `draft`**（沿用仓库现有文章写法，交由 schema 默认值 `false` 处理）。
   命令路径与文件模板路径共用该函数，避免两处模板漂移。

2. **新建命令 `+firefly/new-post`**（`config.el`）：
   - 用 `completing-read` 列出 posts 集合下已有子目录（`directory-files` + ``\`[^.]`` 过滤），默认值 `writing`，自由输入新目录名；
   - `read-string` 读取 slug，trim 后**为空或含 `/`、`\`、空白字符即 `user-error`**；
   - 目标文件已落盘、或已有同路径 buffer 时 `user-error` 拒绝，不覆盖、不打开；
   - 目录不存在则 `make-directory` 递归创建；
   - 写入 frontmatter 后光标停在正文首行，并调用 `meow-insert-mode` 进入 INSERT 态。

3. **文件模板旁路**：用 Doom `set-file-template!` 注册
   `"/Firefly/src/content/posts/.+\\.md\\'"` + `:mode 'markdown-mode` + **函数型 `:trigger`**，
   使 `C-x C-f`、dired 等任意方式新建的**空** `.md` 也自动获得同一份 frontmatter。
   触发条件由 Doom 保证（`modules/editor/file-templates/config.el` 的 `+file-templates-check-h`：
   buffer 为空、`(not (file-exists-p buffer-file-name))`、未被修改），故现有文章不会被触碰；
   `posts/` 之外的 markdown 仍走上游 `markdown-mode/__` 规则。

4. **键位**：仅绑定 markdown/gfm localleader 下的 `, n p`（与 `, n d` 同处 `n` = new 前缀）。
   全局 leader 不占用，避免不写博客时白占一个键。

5. **不自动保存**：命令只把内容写入 buffer，是否落盘交由用户 `C-x C-s` 决定，与既有 `, n d` 动态创建行为保持一致。

### 已否决的备选方案

| 方案 | 否决理由 |
| --- | --- |
| Page Bundle（`<slug>/index.md`） | 用户选定单文件范式；本地相对路径图片需求已由图床工作流覆盖 |
| 文件名/标题用时间戳 | URL 不可读，后期改文件名会破坏已发布链接 |
| 用 yasnippet 模板文件作真源 | 现有 `snippets/markdown-mode/firefly-post` 的字段集（含 `draft`/`pinned`）与本次选定字段集不一致，且需处理交互式占位符 |
| slug 冲突时自动加 `-2`/`-3` | 会产生用户无印象的重复文章 |
| 冲突时直接打开已有文件 | 命令语义是"新建"，静默降级为"打开"易造成误判 |
| `, n b`（blog） | `, n p`（post）与既有 `, p` 预览键的语义区分已足够 |

## 影响

- **正面**：
  - 新建文章从"回忆字段 + 手写 YAML"降为一次击键 + 两个输入；
  - Frontmatter 字段集与仓库既有文章完全一致，消除 Astro 构建期 schema 报错；
  - 两条入口（命令与文件模板）共享同一函数，后续字段变更只需改一处。
- **注意与代价**：
  - `set-file-template!` 是**函数而非宏**，其 `:mode` 参数会被求值，必须写成 `:mode 'markdown-mode`；漏引号会触发 `void-variable: markdown-mode` 而中断整个 config 加载（本次实现中已实测踩到）。
  - 文件模板的注入依赖 `+file-templates-check-h` 的"文件不存在"条件，因此命令创建的 buffer **未保存前**再次以同 slug 调用会被 buffer 级检查拦下；一旦保存，则由文件级检查拦下。
  - 子目录名进入 URL 是 Firefly/Astro 的固有行为，故选择 `writing/` 会把 URL 变成 `/posts/writing/<slug>/`；如需干净 URL，应直接放在 `posts/` 根目录。
  - 命令不自动保存：新建后若未保存就退出 Emacs，模板内容会丢失（仅限刚创建的骨架，不影响已写内容）。

## 参考

- Doom 文件模板实现：`~/.config/emacs/sources/doom+/modules/editor/file-templates/{config,autoload}.el`
- Firefly 内容 schema：`~/codes/Firefly/src/content.config.ts`
- Firefly URL 生成：`~/codes/Firefly/src/utils/url-utils.ts`、`src/pages/posts/[...slug].astro`
