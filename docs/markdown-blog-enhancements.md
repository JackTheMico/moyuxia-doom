# Doom Emacs Markdown 博客写作增强配置调研报告（面向 Astro / Firefly）

> **目标**：为基于 Astro 的中文博客（Firefly，位于 `~/codes/Firefly`）在 Doom Emacs 环境下构建高效、优雅、符合排版规范的 Markdown 写作体验。  
> **调查范围**：Doom Emacs 源码与模块、Firefly 项目配置与 Schema、Emacs 官方手册与 MELPA/ELPA 上游项目代码库。

---

## 一、Doom Emacs (`:lang markdown`) 模块能力

### 1.1 模块 Flags 与依赖生态

在 Doom Emacs 的 `:lang markdown`（源码位于 `~/.config/emacs/sources/doom+/modules/lang/markdown/`）中，支持以下 flags：

| Flag | 作用 | 依赖与说明 |
| :--- | :--- | :--- |
| `+lsp` | 为 `markdown-mode`、`gfm-mode` 与 `markdown-ts-mode` 挂载 LSP client 钩子（支持 Marksman, markdown-oxide, remark 等） | 需启用 `:tools (lsp +eglot)` 或 `:tools lsp` |
| `+grip` | 启用 `grip-mode`，将 `<localleader> p` 绑定为 Grip 实时预览 | 需系统已安装 Python 包 `grip`（`pip install grip`） |
| `+tree-sitter` | 在 Emacs 30 及以下版本引入 `markdown-ts-mode`，Emacs 31+ 则优先使用内置语法树模式 | 需 tree-sitter 语法库 |

**默认加载的包列表**（`packages.el`）：
- `markdown-mode`（[jrblevin/markdown-mode](https://github.com/jrblevin/markdown-mode)）
- `edit-indirect`（[Fanael/edit-indirect](https://github.com/Fanael/edit-indirect)）
- `markdown-toc`（[ardumont/markdown-toc](https://github.com/ardumont/markdown-toc)）
- `grip-mode`（当启用 `+grip`）
- `markdown-ts-mode`（当启用 `+tree-sitter`）
- `evil-markdown`（仅在 `:editor evil` 时加载；当前环境使用 `meow`，不会加载）

### 1.2 内置核心命令与 Localleader 键位映射

Doom Emacs 在 `config.el` 中通过 `+markdown-common-config` 为 `markdown-mode` 统一定义了 `<localleader>` 键位体系：

- **代码块独立编辑**：
  - `<localleader> '` 绑定至 `markdown-edit-code-block`。
  - **工作机制**：光标停留在 fenced code block（如 ` ```ts `）内时调用，借助 `edit-indirect` 打开一个派生的独立间接缓冲区（indirect buffer），根据语言标签自动切入对应的 Major Mode（如 `typescript-ts-mode`、`python-mode`）。
  - **提交流程**：在间接缓冲区中，按 `C-c C-c` 提交更改并退出，按 `C-c C-k` 丢弃修改返回。
  - **Doom 优化**：Doom 对 `markdown-fontify-code-block-natively` 增加了 `:around` advice（`+markdown-optimize-src-buffer-modes-a`），延迟了重量级 mode-hook 执行，显著提高高亮与打开速度。
- **插入命令前缀 (`<localleader> i`)**：
  - `i T`：`markdown-toc-generate-toc`（生成/更新目录）
  - `i i`：`markdown-insert-image`（插入图片语法）
  - `i l`：`markdown-insert-link`（插入超链接）
  - `i C`：`markdown-insert-gfm-code-block`（插入 GFM 代码块）
  - `i t`：`markdown-insert-table`（插入 Markdown 表格）
  - `i 1` ~ `i 6`：`markdown-insert-header-atx-1` ~ `6`（插入对应级别标题）
  - `i b` / `i c` / `i e` / `i s`：粗体、行内代码、斜体、删除线
- **视图与切换前缀 (`<localleader> t`)**：
  - `t i`：`markdown-toggle-inline-images`（行内图片显示/隐藏）
  - `t f`：`markdown-toggle-fontify-code-blocks-natively`（代码块语法高亮开关）
  - `t e`：`markdown-toggle-math`（LaTeX 公式行内渲染开关）
  - `t l`：`markdown-toggle-url-hiding`（隐藏/显示链接实际 URL）
  - `t m`：`markdown-toggle-markup-hiding`（隐藏/显示标记符号）
- **编译与外部打开**：
  - `<localleader> o`：`markdown-open`（通过 `xdg-open` 打开编译出的 HTML）
  - `<localleader> p`：`markdown-preview`（调用 marked / pandoc / discount 管道生成预览）

---

## 二、专注写作与中文排版优化

### 2.1 居中专注模式：`olivetti` vs `:ui zen` (`writeroom-mode`)

1. **`:ui zen`（用户已在 `init.el` 启用）**：
   - 基于 `writeroom-mode`（[joostkremers/writeroom-mode](https://github.com/joostkremers/writeroom-mode)）与 `visual-fill-column`。
   - 快捷键：`SPC t z`（`+zen/toggle`）、`SPC t Z`（`+zen/toggle-fullscreen`）。
   - **特点**：侵入性较强，默认会关闭 modeline、放大字体（`+zen-text-scale`）、自动开启 `mixed-pitch-mode`。对于全屏沉浸式创作效果极佳，但对日常快速小修小补稍显厚重。
2. **`olivetti`（轻量独立，用户 `packages.el` 已声明）**：
   - 源码仓库：[rnkn/olivetti](https://github.com/rnkn/olivetti)
   - **特点**：仅通过动态调整窗口两侧 margins 实现文本居中，不破坏窗口分屏、不隐藏 modeline、不强行修改字号。
   - **推荐配置**：
     ```elisp
     (use-package! olivetti
       :hook ((markdown-mode . olivetti-mode)
              (gfm-mode . olivetti-mode))
       :config
       (setq olivetti-body-width 88          ; 设定阅读舒适的列宽
             olivetti-minimum-body-width 60))
     ```

### 2.2 变宽与等宽混排：`mixed-pitch`

- 源码仓库：[jabranham/mixed-pitch](https://github.com/jabranham/mixed-pitch)（已随 `:ui zen` 编译在本地缓存中）
- **原理**：正文段落使用无衬线或衬线可变宽字体（`variable-pitch` face），而代码块、行内代码、Markdown 语法标记、表格、Frontmatter 元数据强制保持等宽字体（`fixed-pitch` face）。
- **中文写作要点**：配合 Doom 的 `doom-variable-pitch-font`，将西文与中文字体设为可变宽，形成书籍印刷般的版式美感：
  ```elisp
  (use-package! mixed-pitch
    :hook ((markdown-mode . mixed-pitch-mode)
           (gfm-mode . mixed-pitch-mode)))
  ```

### 2.3 中英文与全半角混排表格对齐：`valign`

- 源码仓库：[casouri/valign](https://github.com/casouri/valign)（GNU ELPA）
- **痛点**：中文字符、Emoji 以及 variable-pitch 字体的物理像素宽度不是英文字符的严格 2 倍，导致原生的纯文本 Markdown 表格（使用竖线 `|`）在 GUI Emacs 中发生锯齿状错位。
- **解决方案**：`valign-mode` 在不改动磁盘原文件字符的前提下，利用 Emacs 的 `:align-to` 像素级 text property 对表格竖线进行对齐。
- **配置方式**：
  在 `packages.el` 中添加：
  ```elisp
  (package! valign)
  ```
  在 `config.el` 中配置：
  ```elisp
  (use-package! valign
    :hook ((markdown-mode . valign-mode)
           (gfm-mode . valign-mode))
    :config
    (setq valign-max-table-size 5000))
  ```

### 2.4 盘古之白（中英间隔空隙）：`pangu-spacing`

- 源码仓库：[coldnew/pangu-spacing](https://github.com/coldnew/pangu-spacing)（MELPA）
- **核心模式选择**：
  - **虚拟间隔（强烈推荐）**：使用 text-property / overlay 在屏幕渲染时给中英字符之间垫空，**不修改文件本身**。优势是不会产生多余的 git commit diff，也不会意外破坏 YAML frontmatter 语法。
  - **实体空格**：保存时自动插入真实空格（`pangu-spacing-real-insert-separtor t`）。
- **配置方式**：
  在 `packages.el` 中添加：
  ```elisp
  (package! pangu-spacing)
  ```
  在 `config.el` 中配置：
  ```elisp
  (use-package! pangu-spacing
    :hook ((markdown-mode . pangu-spacing-mode)
           (gfm-mode . pangu-spacing-mode))
    :config
    ;; 默认仅视觉渲染空格，避免污染 Astro Markdown 原文
    (setq pangu-spacing-real-insert-separtor nil))
  ```

---

## 三、Astro Firefly 博客 Frontmatter 与 Snippets

### 3.1 Firefly 博客 Frontmatter 规范

核验来源：`~/codes/Firefly/src/content.config.ts`、`~/codes/Firefly/_frontmatter.json` 与 `src/content/posts/guide/index.md`。

Firefly 采用 Astro Content Collections（Zod 校验），文章存放在 `src/content/posts/`。文章组织支持两种范式：
1. **单文件结构**：`src/content/posts/my-post.md`。
2. **Page Bundle 结构（推荐）**：`src/content/posts/my-post/index.md`，配合同级目录 `cover.webp`、`image-1.png`，在 Markdown 内可使用相对路径 `./cover.webp` 引用。

**Frontmatter 字段规格表**：

| 字段 | 类型 | 必填 | 默认值 | 语义与约束 |
| :--- | :--- | :---: | :--- | :--- |
| `title` | `string` | **是** | - | 文章标题 |
| `published` | `Date` | **是** | - | 发布时间（如 `2026-09-19` 或 `2026-09-19T19:30:00+08:00`） |
| `description` | `string` | 否 | `""` | 简介摘要，展示在博客列表卡片 |
| `image` | `string` | 否 | `""` | 封面图（以 `./` 开头为相对路径，`/` 开头对应 `public/`，或 `http(s)://`） |
| `tags` | `string[]` | 否 | `[]` | 标签列表，如 `[Emacs, Astro, 博客]` |
| `category` | `string` | 否 | `""` | 博客分类 |
| `draft` | `boolean` | 否 | `false` | 草稿标记；为 `true` 时生产构建不展示 |
| `pinned` | `boolean` | 否 | `false` | 是否在首页置顶 |
| `updated` | `Date` | 否 | - | 更新时间 |
| `lang` | `string` | 否 | `""` | 语言代码（如 `zh-CN`） |
| `comment` | `boolean` | 否 | `true` | 是否启用该文章评论系统 |

### 3.2 YASnippet 模板定义（动态求值）

在 `~/.config/doom/snippets/markdown-mode/firefly-post`（新建文件）：

```yasnippet
# -*- mode: snippet -*-
# name: Firefly Astro Post
# key: post
# condition: (derived-mode-p 'markdown-mode 'gfm-mode)
# --
---
title: ${1:文章标题}
published: `(format-time-string "%Y-%m-%d")`
description: "${2:简短文章描述}"
image: "${3:./cover.webp}"
tags: [${4:标签}]
category: ${5:技术}
draft: ${6:$$(yas-choose-value '("false" "true"))}
pinned: ${7:$$(yas-choose-value '("false" "true"))}
---

$0
```

### 3.3 Doom `file-templates` 自动展开集成

在 `config.el` 中声明文件模板挂载：当在 `src/content/posts/` 路径下新建 `.md` 文件时，自动注入并展开模板：

```elisp
(after! doom-file-templates
  (set-file-template! "/Firefly/src/content/posts/.+\\.md$"
                      :trigger "post"
                      :mode 'markdown-mode))
```

---

## 四、图片处理：剪贴板粘贴与行内预览

### 4.1 方案对比

| 方案 | 机制与兼容性 | 优缺点 |
| :--- | :--- | :--- |
| **Emacs 29+ 原生 `yank-media`** | Emacs 29.1+ 内置标准，通过 `yank-media-handler` 注册 MIME 类型处理 | 官方通用标准，但针对具体静态站项目（如按 Page Bundle 保存至文章同级目录）需额外实现保存路径路由逻辑 |
| **`org-download`** | 原本针对 Org-mode 开发，可通过适配器支持 markdown | 包袱较重，且容易插入 Org 样式的额外注释 |
| **定制 Elisp + `wl-paste` / `xclip`** | 针对当前 Linux 环境（已验证同时存在 `wl-paste` 与 `xclip`），智能识别 Page Bundle 目录并存图 | **针对 Firefly 的最佳方案**：零第三方 Lisp 依赖，自动在当前文章目录存为 `img-*.png`，自动插入相对链接并刷新行内渲染 |

### 4.2 推荐的剪贴板图片粘贴函数

针对 Firefly 的 Page Bundle（`index.md` 存放于文章专属子目录）设计：

```elisp
(defun +firefly/markdown-paste-clipboard-image ()
  "从剪贴板粘贴图片，保存到当前博客目录并插入相对路径 Markdown 语法。"
  (interactive)
  (unless buffer-file-name
    (user-error "当前 Buffer 未关联到具体文件，无法确定保存路径"))
  (let* ((post-dir (file-name-directory buffer-file-name))
         ;; 若为 index.md (Page bundle)，图片可直接置于同级或 images/ 子目录
         (img-dir (if (string-equal (file-name-nondirectory buffer-file-name) "index.md")
                      post-dir
                    (expand-file-name "images" post-dir)))
         (time-str (format-time-string "%Y%m%d-%H%M%S"))
         (filename (format "img-%s.png" time-str))
         (filepath (expand-file-name filename img-dir))
         (rel-path (file-relative-name filepath post-dir)))
    (unless (file-directory-p img-dir)
      (make-directory img-dir t))
    ;; 适配 Linux Wayland 与 X11
    (cond
     ((executable-find "wl-paste")
      (call-process "wl-paste" nil nil nil "--type" "image/png" "--output" filepath))
     ((executable-find "xclip")
      (call-process "xclip" nil nil nil "-selection" "clipboard" "-target" "image/png" "-out" filepath))
     (t (user-error "未检测到 wl-paste 或 xclip，请先安装剪贴板工具")))
    (if (and (file-exists-p filepath) (> (file-attribute-size (file-attributes filepath)) 0))
        (progn
          (insert (format "![%s](%s)\n" filename rel-path))
          (message "图片已保存至: %s" rel-path)
          (when (fboundp 'markdown-display-inline-images)
            (markdown-display-inline-images)))
      (user-error "剪贴板中未检测到图片或图片保存失败"))))
```

### 4.3 行内预览控制

- `markdown-display-inline-images`：在 Buffer 内直接渲染图片。
- 为防止高分辨率截图撑爆 Emacs 视口，建议限制最大渲染尺寸：
  ```elisp
  (after! markdown-mode
    (setq markdown-max-image-size '(800 . 600)
          markdown-display-remote-images t))
  ```

---

## 五、实时预览选型：`grip-mode` vs Astro Dev Server

### 5.1 方案对比

| 维度 | `grip-mode` (`+grip`) | Astro 本地开发服务器 (`pnpm dev`) |
| :--- | :--- | :--- |
| **渲染内核** | GitHub Markdown REST API | Astro + Vite + 博客自定义主题 / Tailwind / Shiki |
| **组件支持** | 仅标准 GFM HTML，无法渲染 Astro/Svelte 组件 | 完整支持 Astro 全生态、动态交互与样式 |
| **Frontmatter** | 被视为普通文本或忽略，无法展示封面卡片、Tags 样式 | 完美呈现文章完整页面版式 |
| **网络与速率** | 依赖外网 GitHub API，匿名限制 60 次/小时 | 本地回环（`localhost:4321`），零网络依赖，无请求限制 |
| **响应速度** | 保存后发起 HTTP 往返请求，有明显延迟 | **Vite HMR**：保存即毫秒级局部热重载 |

### 5.2 最佳实践

- 对于 Firefly 博客，**Astro 本地 Dev Server + HMR 是还原度最高的方案**。
- **与 Emacs 的联动机制**：
  1. 用户配置中已配置 `super-save`（切换 Buffer、失焦、闲置时自动写回磁盘），无需频繁手动按保存。
  2. 启动 `pnpm dev` 后，本地监听 `http://localhost:4321`。
  3. 通过一键命令直接在浏览器跳转到当前文章页：
  ```elisp
  (defun +firefly/open-post-in-browser ()
    "在浏览器中打开当前 Firefly 博客文章的本地实时预览页面。"
    (interactive)
    (let* ((filename (buffer-file-name))
           (post-slug (when (and filename (string-match "src/content/posts/\\([^/]+\\)" filename))
                        (match-string 1 filename))))
      (if post-slug
          (browse-url (format "http://localhost:4321/posts/%s" post-slug))
        (browse-url "http://localhost:4321"))))
  ```

---

## 六、Meow 模态编辑下的键位适配

### 6.1 冲突根源与现状

1. **`SPC m` 被 Meow Keypad 抢占**：
   - 用户配置 `config.el`（第 554-555 行）已记录：Meow Keypad 把 `?m` 保留作 Meta 修饰前缀（`meow-keypad-meta-prefix`），导致原生 Doom 的 `SPC m` localleader 前缀被拦截。
2. **Doom Meow 私有模块现状**：
   - 用户的 `modules/editor/meow/config.el` 中将 localleader 映射到了 `SPC l`（通过转译为 `C-c c`）。
   - 在 NORMAL 状态下，按 `SPC l` 能够调出 Markdown 专用的 localleader 菜单。

### 6.2 模态编辑优化（单键 Localleader）

在 Meow NORMAL 态下，可将逗号 `,` 映射为直接触发 localleader：

```elisp
(after! meow
  ;; 将 NORMAL 态的 , 绑定为 Localleader 前缀
  (meow-normal-define-key
   '("," . (cmd! (meow--execute-kbd-macro "C-c c"))))

  ;; 为 markdown-mode 挂载专属的快捷操作
  (map! :map markdown-mode-map
        :localleader
        "p" #'+firefly/open-post-in-browser
        "P" #'+firefly/markdown-paste-clipboard-image))
```

**写作常用手感对照**：
- `, '`：直接进入间接代码块编辑（`markdown-edit-code-block`）
- `, P`：从剪贴板粘贴截图并自动插入相对链接
- `, p`：在浏览器中打开当前文章的 Astro 本地实时预览
- `, t i`：切换显示行内图片
- `, i t`：插入表格（自动被 `valign` 像素级对齐）
- `M-SPC`：在 INSERT 态临时调用 Keypad Leader 菜单

---

## 七、综合配置建议（供逐步采纳）

### 1. `packages.el`
```elisp
;; Markdown 排版增强
(package! valign)
(package! pangu-spacing)
;; 注：olivetti 已经在 packages.el 中；mixed-pitch 已随 :ui zen 引入
```

### 2. `config.el`
```elisp
;;; Markdown & Firefly 博客写作增强
(after! markdown-mode
  ;; 基础排版与显示优化
  (setq markdown-fontify-whole-heading-line t
        markdown-fontify-code-blocks-natively t
        markdown-max-image-size '(800 . 600)
        markdown-display-remote-images t)

  ;; 自动开启居中、混排、表格像素对齐与盘古间隔
  (add-hook! '(markdown-mode-hook gfm-mode-hook)
    #'olivetti-mode
    #'mixed-pitch-mode
    #'valign-mode
    #'pangu-spacing-mode)

  ;; 绑定本地预览与图片粘贴
  (map! :map markdown-mode-map
        :localleader
        "p" #'+firefly/open-post-in-browser
        "P" #'+firefly/markdown-paste-clipboard-image))

(after! pangu-spacing
  (setq pangu-spacing-real-insert-separtor nil))

(after! olivetti
  (setq olivetti-body-width 88
        olivetti-minimum-body-width 60))

;; Meow NORMAL 态单键 Localleader 映射
(after! meow
  (meow-normal-define-key
   '("," . (cmd! (meow--execute-kbd-macro "C-c c")))))
```

---

## 八、参考来源（Primary Sources）

1. **Doom Emacs 官方模块与源码**：
   - `:lang markdown`: `/home/jackwy/.config/emacs/sources/doom+/modules/lang/markdown/{README.org, config.el, packages.el, autoload.el}`
   - `:ui zen`: `/home/jackwy/.config/emacs/sources/doom+/modules/ui/zen/{README.org, config.el}`
   - `:editor meow`: `/home/jackwy/.config/doom/modules/editor/meow/config.el`
2. **Firefly 博客代码库**：
   - Content Collections 模式定义: `/home/jackwy/codes/Firefly/src/content.config.ts`
   - Frontmatter 架构模式: `/home/jackwy/codes/Firefly/_frontmatter.json`
   - 官方使用手册: `/home/jackwy/codes/Firefly/src/content/posts/guide/index.md`
3. **上游官方代码库与手册**：
   - `valign`: [casouri/valign (GitHub)](https://github.com/casouri/valign)
   - `pangu-spacing`: [coldnew/pangu-spacing (GitHub)](https://github.com/coldnew/pangu-spacing)
   - `olivetti`: [rnkn/olivetti (GitHub)](https://github.com/rnkn/olivetti)
   - `mixed-pitch`: [jabranham/mixed-pitch (GitHub)](https://github.com/jabranham/mixed-pitch)
   - `markdown-mode`: [jrblevin/markdown-mode (GitHub)](https://github.com/jrblevin/markdown-mode)
   - Emacs Manual: [Yanking Media (GNU Emacs)](https://www.gnu.org/software/emacs/manual/html_node/emacs/Yanking-Media.html)
