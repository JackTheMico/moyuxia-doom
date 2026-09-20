# ADR 0001: Doom Emacs Markdown 写作增强与 Cloudflare Imgbed 图床集成

## 状态
已通过 (Accepted)

## 背景
用户在 Doom Emacs 环境下为基于 Astro 的中文个人博客（Firefly）撰写 Markdown 文章。存在以下主要痛点：
1. **中文排版与对齐**：Markdown 表格中混排中文字符与英数时，因字符像素宽度不对等导致表格线锯齿状错位；中文与英文/数字之间缺乏印刷规范间隙；
2. **专注度**：全屏或宽屏下默认靠左排版，阅读视线不适；
3. **图床上传脱节**：过去需跳出 Emacs 运行 Python 脚本或在网页上传图床，缺乏在 Buffer 内直接将截图或本地文件一键异步上传到 Cloudflare Worker 图床并回写 Markdown 链接的能力；
4. **模态键位冲突**：Meow 模态编辑下，`SPC m` 作为 Doom 默认 localleader 会被 Meow 的 Keypad Meta 前缀拦截。

## 决策

1. **排版包引入与视觉约束**：
   - 引入 `valign`：使用 Emacs 底层 `:align-to` 像素属性实现表格对齐，不改动物理文本。
   - 引入 `pangu-spacing`：仅开启视觉渲染 overlay 垫空（`pangu-spacing-real-insert-separtor nil`），不修改原文避免污染 Git diff。
   - 激活 `olivetti`（设为 88 列居中）与 `mixed-pitch`（正文变宽、代码与 Frontmatter 等宽）。
2. **图床双轨异步上传**：
   - 凭据管理：通过 Emacs 内置 `auth-source` 从 `~/.authinfo.gpg`（host: `jackwyimgbed.dlwxxxdlw.workers.dev`）安全读取 Worker Token，杜绝明文硬编码。
   - 异步通信：使用 `make-process` 异步调用 `curl`，UI 零冻结。
   - 提供两套命令：
     - `+firefly/imgbed-upload-clipboard`：提取 Wayland `wl-paste` 或 X11 `xclip` 剪贴板图片异步上传。
     - `+firefly/imgbed-upload-file`：弹窗选本地文件异步上传。
   - 插入协议：交互式提示输入 Alt text（回车留空），在触发点插入 `![alt](url)`，自动将 URL 写入剪贴板（方便用于 Frontmatter `image:` 封面），并刷新行内图片预览。
3. **本地 Page Bundle 存图备选**：
   - 提供 `+firefly/markdown-paste-clipboard-image`，将截图保存至当前文章目录（或 `images/` 子目录），插入相对路径。
4. **本地开发服务实时联动**：
   - 提供 `+firefly/open-post-in-browser`，根据当前文件路径计算 slug 并一键在浏览器定位到 `http://localhost:4321/posts/<slug>`。
5. **Meow 键位映射**：
   - NORMAL 态映射 `,` 触发 localleader；
   - 布局：
     - `, u c`：上传剪贴板图片至图床
     - `, u f`：选择文件上传至图床
     - `, P`：保存为本地相对图片
     - `, p`：浏览器打开 Astro 预览
     - `, '`：独立编辑代码块

## 影响
- Markdown 写作体验与排版达到现代化标准；
- 博客配图工作流从多步操作缩减至单次击键；
- 敏感凭据通过 GPG 加密隔离，保持 Git 仓库清洁安全。
