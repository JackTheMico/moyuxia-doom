;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!
(setq shell-file-name (executable-find "bash"))

;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets. It is optional.
(setq user-full-name "Jack Wenyoung"
      user-mail-address "dlwxxxdlw@gmail.com")

;; mu4e 邮件架构说明：
;;   拉信统一走 systemd user 服务（gmi-sync 拉 Gmail、mbsync-163 拉 163；
;;   另有 10 分钟 timers 兜底，Emacs 不开时也会拉）。mu4e 按 U 时通过
;;   `systemctl start --wait` 同步等这两个服务跑完再重建索引——systemd
;;   对同名 unit 单实例串行，不会与 timers 里的 gmi 并发冲突。
;;   索引更新后，由 mu 1.10+ 内置通知（D-Bus）弹出新邮件桌面提醒。
;;   注意：通知在 mu4e 启动（M-x mu4e）后才生效，且围绕"favorite bookmark"
;;   （默认即 Unread messages）的新增未读数计算。
(after! mu4e
  (setq mu4e-get-mail-command
        ;; --wait：等拉信服务结束后 mu4e 才接着重建索引
        "systemctl --user start --wait gmi-sync.service mbsync-163.service"
        mu4e-update-interval 300      ; 每 5 分钟拉信 + 重建索引 + 检查新邮件
        mu4e-notification-support t)  ; mu 1.10+ 内置桌面通知
  ;; Doom 的 mu4e 模块默认启用了 mu4e-alert（原仓库 2019 年停更，mu 官方
  ;; 确认自 mu 1.6 起不可用，Doom 靠 defadvice 续命），它与内置通知并存会
  ;; 双重弹窗，这里摘掉它的通知钩子。
  (remove-hook 'mu4e-index-updated-hook #'mu4e-alert-notify-unread-mail-async)
  (mu4e-bookmark-define "maildir:/sent"     "Gmail Sent" ?s)
  (mu4e-bookmark-define "maildir:/163/Sent" "163 Sent"   ?S)
  (dolist (mode '(mu4e-main-mode mu4e-headers-mode mu4e-view-mode))
    (add-to-list 'meow-mode-state-list (cons mode 'emacs)))
  ;; Gmail SMTP — 需要 app password 存入 ~/.authinfo.gpg
  ;; machine smtp.gmail.com login dlwxxxdlw@gmail.com port 587 password <16位app密码>
  (setq smtpmail-smtp-server "smtp.gmail.com"
        smtpmail-smtp-service 587
        smtpmail-stream-type 'starttls
        smtpmail-smtp-user "dlwxxxdlw@gmail.com"
        message-send-mail-function #'smtpmail-send-it)
  ;; 发送后异步标记 parent flags，避免同步阻塞
  (advice-add 'mu4e--set-parent-flags :around
              (lambda (fn path)
                (run-at-time 0 nil fn path))))

;; Doom exposes five (optional) variables for controlling fonts in Doom:
;;
;; - `doom-font' -- the primary font to use
;; - `doom-variable-pitch-font' -- a non-monospace font (where applicable)
;; - `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;; - `doom-symbol-font' -- for symbols
;; - `doom-serif-font' -- for the `fixed-pitch-serif' face
;;
;; See 'C-h v doom-font' for documentation and more examples of what they
;; accept. For example:
;;
(setq doom-font (font-spec :family "Maple Mono NF CN" :size 25 :weight 'Medium)
      doom-variable-pitch-font (font-spec :family "LXGW WenKai Screen" :size 23)
      doom-big-font (font-spec :family "Maple Mono NF CN" :size 36)
      doom-symbol-font (font-spec :family "Maple Mono NF CN")
      doom-serif-font (font-spec :family "Noto Serif CJK SC")
      nerd-icons-font-family "JetBrainsMono Nerd Font Mono")

;; 中文回退：代码中的汉字也用霞鹜文楷（Maple 自带汉字，需覆盖 fontset）
(after! (doom-ui)
  (set-fontset-font t 'han (font-spec :family "LXGW WenKai Mono Screen"))
  (set-fontset-font t 'cjk-misc (font-spec :family "LXGW WenKai Mono Screen")))
;;
;; If you or Emacs can't find your font, use 'M-x describe-font' to look them
;; up, `M-x eval-region' to execute elisp code, and 'M-x doom/reload-font' to
;; refresh your font settings. If Emacs still can't find your font, it likely
;; wasn't installed correctly. Font issues are rarely Doom issues!

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
;; (setq doom-theme 'doom-dacula)
(add-to-list 'custom-theme-load-path "~/.config/emacs/themes/")
(load-theme 'noctalia t)

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type :relative)

;; org 目录结构（PARA：不再用目录分区，全部进 vulpea vault）
;;   ~/org/gtd/    — 任务文件：inbox.org / projects.org / tickler.org / calendar.org
;;   ~/org/roam/   — 知识库：index.org 及 quant / tcm / metaphysics / writing / tech 子目录
;; 两目录都注册进 vulpea-db-sync-directories（见 vulpea 配置块），角色用
;; :area: / :project: tag 标记；agenda 由 vulpea-para-agenda-mode 从数据库
;; 自建（只显示有 open work 的文件），不再依赖目录分区。
;; org-directory 必须在 org 加载前设置。org 是懒加载的，顶层 setq 时 org
;; 尚未加载，下面的 defcustom 同理安全；它们会覆盖 Doom 模块的默认值。
(setq org-directory "~/org/"
      ;; PARA agenda 每次刷新前的 fallback（agenda-mode 会覆盖它）
      org-agenda-files '("~/org/gtd/")
      ;; capture 的兜底文件（Doom "n" 笔记模板等使用）
      org-default-notes-file "~/org/gtd/inbox.org")
;; 快速打开 gtd 收集箱：gtd 已并入 vault，保留直达键 SPC n i（notes 前缀下 i = inbox）。
(defun my/org-open-inbox ()
  "打开 GTD 收集箱（org-default-notes-file）。"
  (interactive)
  (find-file org-default-notes-file))
(map! :leader :desc "Open inbox" "n i" #'my/org-open-inbox)
;; Doom 默认 capture 模板的目标改到 gtd 收集箱（默认是 {org-directory}/todo.org）：
;; "t"（Personal todo）和 "n"（Personal notes）都先进 inbox.org，
;; 符合 GTD "先收集、后分类" 流程。+org-capture-* 是 Doom org 模块的变量，
;; 模块先于本文件加载，此处 setq 生效于模块默认值之后。
(setq +org-capture-todo-file "gtd/inbox.org"
      +org-capture-notes-file "gtd/inbox.org")
;; org-refile 交给 vulpea-para（见下方 vulpea-para 配置块）：目标 = 整个
;; vault（gtd + roam），由 vulpea-para-refile-mode 从数据库直接回答，
;; 不访问文件；org-refile-use-outline-path 'title 按标题补全。
;; org 里 RET 的 dwim：
;;   normal/motion 状态 + 光标在链接上  → 打开链接（vulpea 笔记的 id: 链接跳转）
;;   normal/motion 状态 + 光标在 headline → 展开/折叠该节点
;;   insert 状态 / 其他位置              → 原 org-return（换行、插入新行）
;; 原理：meow normal state 没绑 RET，原本穿透到 org-return；而 org 默认
;; `org-return-follows-link' 为 nil，RET 在链接上不跟随（得用 C-c C-o）。
;; 这里手动接管链接跟随，且只在 normal/motion 下生效，避免 insert 编辑
;; 链接文本时按 RET 误触跳转。vulpea 笔记的 [[id:...][标题]] 由 org-id 解析，
;; org-open-at-point 即可跳转到对应 note。
(after! org
  (defun +org-ret-cycle-or-return ()
    "RET dwim in org-mode:
- open the link at point (vulpea note jump);
- on a heading, open the first link in that heading line, else cycle it;
- otherwise behave like `org-return'."
    (interactive)
    (cond
     ;; insert 状态：永远换行/插入，不跳转
     ((bound-and-true-p meow-insert-mode) (org-return))
     ;; 光标在链接上：打开链接（vulpea 笔记跳转）
     ((org-in-regexp org-link-any-re) (org-open-at-point))
     ;; headline：heading 行内有链接则直接打开（vulpea 笔记的
     ;; `* [[id:...][标题]]' 就是这种情况），否则展开/折叠。
     ;; 用 org-link-open-from-string 绕开 org-open-at-point 在
     ;; headline 上"列出 entry 内链接"的选择菜单，实现一键跳转。
     ((org-at-heading-p)
      (save-excursion
        (goto-char (line-beginning-position))
        (if (re-search-forward org-link-any-re (line-end-position) t)
            (org-link-open-from-string (match-string-no-properties 0))
          (org-cycle))))
     (t (org-return))))
  (map! :map org-mode-map "RET" #'+org-ret-cycle-or-return))

;; Tex Live 2026 移除了 ulem.sty（Arch 的任何 texlive 包都不再带它），而本版
;; org 的默认 latex 包列表仍硬编码 ("normalem" "ulem" t)，导出 PDF 时无条件
;; \usepackage[normalem]{ulem} 导致 "File 'ulem.sty' not found"。这里移除。
;; ponytail: 最小修复；代价是 org 的 +下划线+/+删除线+ 标记在 PDF 里不再加
;; 下划线（文本仍保留）。需要该功能时再补 \usepackage{soulutf8}。
(after! org
  (setq org-latex-default-packages-alist
        (cl-remove '("normalem" "ulem" t) org-latex-default-packages-alist
                   :test #'equal)
        ;; 默认用 xelatex 编译：中文文档必选（pdflatex 对中文/CJK 不支持）。
        ;; 也兼容纯英文导出，无副作用。
        org-latex-compiler "xelatex"))
;; ---- vulpea 知识库（替代 org-roam）----
;; vulpea 是纯 org + sqlite 的笔记索引层（v2 完全独立，不依赖 org-roam）；
;; vulpea-ui 提供 sidebar（stats / outline / backlinks / links 等 widget）；
;; vulpea-journal 提供日记（基于 vulpea-ui 的 widget）；
;; vulpea-graph 提供笔记关系图（基于 elij/graph-fa2）。
(use-package! vulpea
  :defer nil  ; 启动即加载：autosync 要第一时间开始索引
  :config
  ;; PARA：gtd 任务区 + roam 知识库全部进 vault（角色靠 tag 区分）
  (setq vulpea-db-sync-directories '("~/org/roam/" "~/org/gtd/"))
  ;; 首次运行：db 文件不存在则全量扫描建库
  (unless (file-exists-p vulpea-db-location)
    (vulpea-db-sync-full-scan))
  ;; 后台自动同步（保存 / 外部文件变更时增量更新）
  (vulpea-db-autosync-mode +1))

(use-package! vulpea-ui
  :after vulpea)

;; 进入 vault 内的 org 文件自动打开 vulpea-ui sidebar。
;; - 限定 ~/org/（gtd + roam 都在内），其他 org 文件不弹
;; - get-buffer-window 守卫：daemon 下 session 恢复 buffer 时无可见窗口，
;;   不会误开 sidebar（sidebar-open 依赖 selected-frame 的窗口）
;; - vulpea-ui-sidebar-open 是幂等的（已可见则跳过），org-mode-hook 重复
;;   触发无害
(defun my/vulpea-ui-maybe-open-sidebar ()
  "当前 buffer 是 vault 内 org 文件且有可见窗口时打开 vulpea-ui sidebar。"
  (when (and (get-buffer-window nil t)
             (string-prefix-p (expand-file-name "~/org/")
                              (or (buffer-file-name) "")))
    (vulpea-ui-sidebar-open)))
(add-hook 'org-mode-hook #'my/vulpea-ui-maybe-open-sidebar)

(use-package! vulpea-journal
  :after (vulpea vulpea-ui)
  :config
  ;; 注册 journal widget（sidebar 里的日历、"on this day" 等）
  (vulpea-journal-setup))

(use-package! vulpea-graph
  :commands vulpea-graph)

;; ---- vulpea-para：PARA 体系（agenda + refile + capture）----
;; setup-defaults 是官方一体化入口，做四件事：
;;   1. vulpea-para-agenda-mode：agenda 文件从数据库自建（只显示有
;;      open work 的文件），不再依赖目录分区
;;   2. org-agenda-custom-commands：新增 " " PARA agenda（refile /
;;      today / focus / stuck-projects / waiting / current-quarter）
;;   3. vulpea-para-refile-mode + org-refile-targets 换成官方 spec：
;;      目标 = 整个 vault（gtd + roam 全部笔记），数据库查询回答，
;;      不访问文件；'title 按标题补全；allow-creating-parent-nodes
;;   4. org-capture-templates 追加 "P"（PARA project）/"M"（PARA
;;      meeting）模板，执行后改键以避开 Doom 默认 "p" 键的冲突
(use-package! vulpea-para
  :after vulpea
  :config
  (vulpea-para-setup-defaults)
  ;; vulpea-para-setup-defaults 往 org-capture-templates 追加的 "p" 键
  ;; 与 Doom 默认的 "p" 父级分组（Templates for projects → pt/pn/pc）
  ;; 冲突，导致 org-capture 选 "p" 时匹配到 Doom 侧 → 触发
  ;; +org--capture-local-root → "Couldn't detect a project"。
  ;; 处理：把 vulpea-para 追加的 "p" 键名就地改为 "P"（大写），同时
  ;; 把 "m" 改为 "M" 保持一致性（大写出 PARA 专属模板）。
  (when-let ((entry (assoc "p" org-capture-templates)))
    (setf (car entry) "P"))
  (when-let ((entry (assoc "m" org-capture-templates)))
    (setf (car entry) "M"))
  ;; gtd 任务文件永远算 open work → 常驻 agenda。
  ;; PARA 的 open-work 判定认 TODO state / REFILE tag / active timestamp，
  ;; 而 gtd 的写法是 "[ ] 标题 + SCHEDULED:"，不满足；且文件级 note 必须
  ;; 带 :ID: 才被 vulpea 索引（vulpea-db--extract-file-node 返回 nil）。
  ;; 这里把 gtd 四个任务文件钉死在 agenda 上，等价旧的"目录扫描"语义。
  (setq vulpea-para-open-work-files
        '("inbox.org" "projects.org" "tickler.org" "calendar.org")))

;; ---- inbox 条目 → 新建 vulpea 原子笔记（一键提炼）----
;; 光标在 org 标题行调用：以条目标题（去 TODO/DONE、优先级、tags）为
;; 新笔记标题，经 vulpea-create 在 roam 目录新建笔记（自动生成 :id: 与
;; ${timestamp}_${slug}.org 文件名），子树剪切进新笔记后跳转过去。
(defun my/org-inbox-to-note ()
  "把当前 org 条目（整棵子树）移入新建的 vulpea 原子笔记。"
  (interactive)
  (require 'vulpea)
  (unless (org-at-heading-p)
    (user-error "光标不在 org 标题上"))
  (let* ((raw-title (org-get-heading t t t t))
         (title (if (string-empty-p raw-title) "Untitled" raw-title))
         (note (vulpea-create title))
         (path (vulpea-note-path note)))
    (org-cut-subtree)
    (with-current-buffer (find-file-noselect path)
      (goto-char (point-max))
      (unless (bolp) (insert "\n"))
      (org-paste-subtree 1)
      (save-buffer))
    (switch-to-buffer (find-file-noselect path))
    (message "已移动到 %s" path)))

;; ---- CRM 多选增强：TAB 连续复选 ----
;; completing-read-multiple（如 vulpea 打 tag）默认靠逗号分隔多选：
;; 输入 "tag1, tag2" 回车即可一次加多个。下面让 vertico 的 TAB
;; （vertico-insert）在 CRM 模式下选中候选后自动追加逗号，实现
;; "TAB → TAB → TAB → RET" 的连续复选；非 CRM 补全不受影响。
(defadvice! +my-vertico-insert-crm-a ()
  "`vertico-insert' 后若处于 CRM 模式，自动追加 `crm-separator'。"
  :after #'vertico-insert
  (when (eq minibuffer-completion-table #'crm--collection-fn)
    (insert ", ")))

;; vulpea 键位：SPC n j = journal（替代 org-journal，沿用 Doom 惯例）；
;; SPC n r = vulpea 笔记（沿用 org-roam 的 r 前缀肌肉记忆）。
;; 注意：meow Keypad 保留 m / g / 空格 三个键，故 graph 绑 G 而非 g；
;; j / r 前缀在去掉 +journal / +roam flag 后为空，带 desc 重建安全
;; （但 n 前缀仍有 Doom 绑定，必须用无 desc 的 :prefix "n"）。
(map! :leader
      (:prefix "n"
               (:prefix ("j" . "journal")
                :desc "Open journal"          "j" #'vulpea-journal
                :desc "Today"                 "t" #'vulpea-journal-today
                :desc "Previous"              "p" #'vulpea-journal-previous
                :desc "Next"                  "n" #'vulpea-journal-next)
               (:prefix ("r" . "vulpea")
                :desc "Find note"            "f" #'vulpea-find
                :desc "Find backlink"        "b" #'vulpea-find-backlink
                :desc "Insert link"          "i" #'vulpea-insert
                :desc "Sync database"        "s" #'vulpea-db-sync-full-scan
                :desc "Graph"                "G" #'vulpea-graph
                :desc "Sidebar toggle"       "R" #'vulpea-ui-sidebar-toggle
                :desc "Collection"           "c" #'vulpea-ui-collection
                :desc "New note from entry"  "n" #'my/org-inbox-to-note
                :desc "Add tag"              "t" #'vulpea-buffer-tags-add
                :desc "Remove tag"           "T" #'vulpea-buffer-tags-remove)
               ;; PARA 导航（vulpea-para）。n 前缀下 "a" 已被 org-agenda 占用
               ;; （+emacs-bindings），故 find-area 用大写 A；p / P 空闲。
               ;; meow Keypad 保留键 m / g / 空格 均不涉及，安全。
               :desc "Find area"             "A" #'vulpea-para-find-area
               :desc "Find project"          "p" #'vulpea-para-find-project
               :desc "New project"           "P" #'vulpea-para-capture-project))


;; ---- 长篇小说写作（org-novelist + olivetti + wc-mode）----
;; 小说项目独立于 vulpea/gtd，放 ~/novels/ 下，单独 git 仓库。
;; 所有写作助手（olivetti 居中、wc-mode 实时字数）只在此目录下的
;; org 文件里自动开启；gtd/roam/mu4e 的 org buffer 完全不受影响。

(defvar my/novels-dir (expand-file-name "~/org/novels/")
  "小说项目根目录。org-novelist 项目也放这里。")

(defun my/novel-buffer-p ()
  "当前 buffer 文件是否在 `my/novels-dir' 下。"
  (and buffer-file-name
       (file-in-directory-p buffer-file-name my/novels-dir)))

;; 1. 项目脚手架：角色 / 地点 / 道具索引
(use-package! org-novelist
  :defer t
  :config
  (setq org-novelist-author "Jack Wenyoung"))

;; 2. 轻量专注：olivetti 居中（只在小说文件自动开）
(use-package! olivetti
  :hook (org-mode . my/novel-maybe-olivetti)
  :config
  (defun my/novel-maybe-olivetti ()
    (when (my/novel-buffer-p)
      (olivetti-mode 1)))
  (setq-default olivetti-body-width 80))

;; 3. 实时字数（只在小说文件自动开）
;;    CJK 字数：Emacs 27+ 的 count-words 将汉字视为 word constituent，
;;    wc-mode 底层调用它，中文计数可用。日更目标通过
;;    M-x customize-group RET wc 设置。
(use-package! wc-mode
  :hook (org-mode . my/novel-maybe-wc)
  :config
  (defun my/novel-maybe-wc ()
    (when (my/novel-buffer-p)
      (wc-mode 1))))

;; 4. 章节字数统计（手动调用）
(use-package! org-wc
  :defer t)

;; 5. 导出为书稿 PDF（中文用 ctexbook，复用 xelatex + ctex 环境）
;;    org-latex-default-class / org-latex-classes 定义在 ox-latex.el，
;;    必须等 ox-latex 加载后再改（after! org 只等 org.el，启动时会 void-variable）。
(after! ox-latex
  ;; 默认文档类 ctexart：中文笔记直接导出；无中文时 ctex 自动降级。
  (setq org-latex-default-class "ctexart")
  (add-to-list 'org-latex-classes
               '("novel-book"
                 "\\documentclass[12pt]{ctexbook}
\\usepackage[margin=1in]{geometry}
\\usepackage{mathptmx}"
                 ("\\chapter{%s}" . "\\chapter*{%s}")
                 ("\\section{%s}" . "\\section*{%s}"))))

;; 6. 一键开写：打开 ~/novels/ 目录（dirvish），从那里进具体小说
(defun my/start-novel-writing ()
  "打开小说项目目录，开始写作。"
  (interactive)
  (find-file my/novels-dir)
  (message "开始写作，祝灵感涌现！"))

;; 7. 日更提交：在 ~/novels/ git 仓库里一键 commit
(defun my/novel-daily-commit (msg)
  "提交今日日更到 ~/novels/ 的 git 仓库。
默认提交信息带日期；C-u 前缀可自定义。"
  (interactive
   (list (read-string "提交信息: "
                      (format "日更完成 %s"
                              (format-time-string "%Y-%m-%d")))))
  (let ((default-directory my/novels-dir))
    (shell-command (format "git add . && git commit -m %S" msg))
    (message "日更已提交：%s" msg)))

;; 8. 键位：SPC n v = novel 子前缀
;;    org-novelist 的 autoload 命令是 org-novelist-new-story（带连字符），
;;    不是 orgn-new-story（那是包内部 defun 名，未 autoload）。
(map! :leader
      (:prefix ("n" . "notes")
               (:prefix ("v" . "novel")
                :desc "新建故事"      "n" #'org-novelist-new-story
                :desc "新建角色"      "c" #'org-novelist-new-character
                :desc "一键开写"      "w" #'my/start-novel-writing
                :desc "日更提交"      "s" #'my/novel-daily-commit
                :desc "章节字数统计"   "W" #'org-wc-display)))

;; jk 退出 insert 模式 (vim 风格)
(after! meow
  (setq meow-cursor-type-normal 'box
        meow-cursor-type-insert 'box
        meow-cursor-type-beacon 'box
        meow-cursor-type-default 'box)
  (defun +meow/insert-escape ()
    "在 INSERT 状态下输入 `jk' 时退出到 NORMAL 状态."
    (interactive)
    (if (and (eq last-command-event ?k)
             (eq (char-before) ?j))
        (progn
          (delete-backward-char 1)
          (meow-normal-mode))
      (self-insert-command 1)))
  (meow-define-keys 'insert
    '("j" . +meow/insert-escape)
    '("k" . +meow/insert-escape)))

;; ---- magit: meow 拦截 k 键（NORMAL 态 meow-prev 优先于 magit-mode-map 的
;; magit-delete-thing/discard）。magit 自带完整键位，直接进入 EMACS state
;; （无 meow 绑定，仅保留 M-SPC keypad 与 C-] 临时切换）。
;; 沿 derived-mode-parent 递归匹配，覆盖 status/log/diff/process 等全部派生 mode。
(after! meow
  (add-to-list 'meow-mode-state-list '(magit-mode . emacs)))

;; ---- org-mode: meow insert 自动切换 fcitx5 输入法 ----
;; 进入 insert mode → 激活中文输入（fcitx5-remote -o）
;; 退出 insert mode → 切回英文（fcitx5-remote -c）
;; 仅在 org-mode 生效；fcitx5 未运行时静默跳过。
(when (executable-find "fcitx5-remote")
  (defun +fcitx5/org-insert-activate ()
    "org-mode 进入 insert mode 时激活 fcitx5 中文输入。"
    (when (derived-mode-p 'org-mode)
      (call-process "fcitx5-remote" nil nil nil "-o")))

  (defun +fcitx5/org-insert-deactivate ()
    "org-mode 退出 insert mode 时切回英文输入。"
    (when (derived-mode-p 'org-mode)
      (call-process "fcitx5-remote" nil nil nil "-c")))

  (add-hook 'meow-insert-enter-hook #'+fcitx5/org-insert-activate)
  (add-hook 'meow-insert-exit-hook #'+fcitx5/org-insert-deactivate))

;; Whenever you reconfigure a package, make sure to wrap your config in an
;; `with-eval-after-load' block, otherwise Doom's defaults may override your
;; settings. E.g.
;;
;;   (with-eval-after-load 'PACKAGE
;;     (setq x y))
;;
;; The exceptions to this rule:
;;
;;   - Setting file/directory variables (like `org-directory')
;;   - Setting variables which explicitly tell you to set them before their
;;     package is loaded (see 'C-h v VARIABLE' to look them up).
;;   - Setting doom variables (which start with 'doom-' or '+').
;;
;; Here are some additional functions/macros that will help you configure Doom.
;;
;; - `load!' for loading external *.el files relative to this one
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;; Alternatively, use `C-h o' to look up a symbol (functions, variables, faces,
;; etc).
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.

;; buffer 操作：meow 的 SPC 映射到 doom-leader-map，因此 <leader> b 即 SPC b
;; （evil 版默认有 <leader> b，meow 走的 +emacs-bindings 没有，这里补上）
(map! :leader
      (:prefix-map ("b" . "buffer")
       :desc "Switch buffer"                 "b" #'consult-buffer
       :desc "Switch workspace buffer"       "B" #'persp-switch-to-buffer
       :desc "Clone buffer"                  "c" #'clone-indirect-buffer
       :desc "Clone buffer other window"     "C" #'clone-indirect-buffer-other-window
       :desc "Kill buffer"                   "d" #'kill-current-buffer
       :desc "ibuffer"                       "i" #'ibuffer
       :desc "Kill buffer"                   "k" #'kill-current-buffer
       :desc "Kill all buffers"              "K" #'doom/kill-all-buffers
       :desc "New empty buffer"              "N" #'+default/new-buffer
       :desc "Next buffer"                   "n" #'next-buffer
       :desc "Kill other buffers"            "O" #'doom/kill-other-buffers
       :desc "Previous buffer"               "p" #'previous-buffer
       :desc "Revert buffer"                 "r" #'revert-buffer
       :desc "Rename buffer"                 "R" #'rename-buffer
       :desc "Save buffer"                   "s" #'basic-save-buffer
       :desc "Save all buffers"              "S" #'save-some-buffers
       :desc "Save buffer as root"           "u" #'doom/sudo-save-buffer
       :desc "Pop up scratch buffer"         "x" #'doom/open-scratch-buffer
       :desc "Switch to scratch buffer"      "X" #'doom/switch-to-scratch-buffer
       :desc "Yank buffer"                   "y" #'+default/yank-buffer-contents
       :desc "Bury buffer"                   "z" #'bury-buffer
       :desc "Kill buried buffers"           "Z" #'doom/kill-buried-buffers))

;; window 操作：SPC w 重构为纯 window 前缀（对齐 lazyvim/spacemacs）
;; 原 SPC w 里的 workspace 操作移到 SPC TAB（与 Doom evil 版惯例一致）
(define-key doom-leader-map "w" nil) ; 清掉默认的 workspaces/windows 前缀
(map! :leader
      (:prefix-map ("w" . "window")
       :desc "Split below"                "-" #'split-window-below
       :desc "Split right"                "/" #'split-window-right
       :desc "Split below"                "s" #'split-window-below
       :desc "Split right"                "v" #'split-window-right
       :desc "Delete window"              "c" #'delete-window
       :desc "Delete window"              "d" #'delete-window
       :desc "Delete window"              "x" #'delete-window
       :desc "Delete other windows"       "o" #'delete-other-windows
       :desc "Delete other windows"       "1" #'delete-other-windows
       :desc "Balance windows"            "=" #'balance-windows
       :desc "Maximize buffer"            "m" #'doom/window-maximize-buffer
       :desc "Enlargen window"            "M" #'doom/window-enlargen
       :desc "Focus window left"          "h" #'windmove-left
       :desc "Focus window down"          "j" #'windmove-down
       :desc "Focus window up"            "k" #'windmove-up
       :desc "Focus window right"         "l" #'windmove-right
       :desc "Move window left"           "H" #'windmove-swap-states-left
       :desc "Move window down"           "J" #'windmove-swap-states-down
       :desc "Move window up"             "K" #'windmove-swap-states-up
       :desc "Move window right"          "L" #'windmove-swap-states-right
       :desc "Other window"               "w" #'other-window
       :desc "Focus other window"         "." #'other-window
       :desc "Undo window config"         "u" #'winner-undo
       :desc "Redo window config"         "U" #'winner-redo)
      ;; workspace 移到 SPC TAB（Doom evil 版布局）
      (:prefix-map ("TAB" . "workspace")
       :desc "Display workspace tabs"     "TAB" #'+workspace/display
       :desc "Switch workspace"           "."   #'+workspace/switch-to
       :desc "Switch to last workspace"   "`"   #'+workspace/other
       :desc "New workspace"              "n"   #'+workspace/new
       :desc "New named workspace"        "N"   #'+workspace/new-named
       :desc "Load workspace from file"   "l"   #'+workspace/load
       :desc "Save workspace to file"     "s"   #'+workspace/save
       :desc "Kill session"               "x"   #'+workspace/kill-session
       :desc "Kill this workspace"        "d"   #'+workspace/kill
       :desc "Delete saved workspace"     "D"   #'+workspace/delete
       :desc "Rename workspace"           "r"   #'+workspace/rename
       :desc "Restore last session"       "R"   #'+workspace/restore-last-session
       :desc "Next workspace"             "]"   #'+workspace/switch-right
       :desc "Previous workspace"         "["   #'+workspace/switch-left
       :desc "Switch to workspace 1"      "1"   #'+workspace/switch-to-0
       :desc "Switch to workspace 2"      "2"   #'+workspace/switch-to-1
       :desc "Switch to workspace 3"      "3"   #'+workspace/switch-to-2
       :desc "Switch to workspace 4"      "4"   #'+workspace/switch-to-3
       :desc "Switch to workspace 5"      "5"   #'+workspace/switch-to-4
       :desc "Switch to workspace 6"      "6"   #'+workspace/switch-to-5
       :desc "Switch to workspace 7"      "7"   #'+workspace/switch-to-6
       :desc "Switch to workspace 8"      "8"   #'+workspace/switch-to-7
       :desc "Switch to workspace 9"      "9"   #'+workspace/switch-to-8
       :desc "Switch to last workspace"   "0"   #'+workspace/switch-to-final))

;; ghostel 终端 (dakra/ghostel fuller example)
(map! :leader "RET" #'ghostel)
;; ghostel-project 加入 SPC p 前缀。
;; 注意1：ghostel 是懒加载，若放在 use-package! 的 :config 里，只有首次打开
;;   ghostel 后绑定才会出现；放顶层 + autoload 命令则始终可见。
;; 注意2：:prefix 必须用纯字符串 "p"（不带 desc）。带 desc 的
;;   (:prefix ("p" . "project")) 会按 map! 文档 WARNING 清空 p 前缀
;;   上 +emacs-bindings 已有的绑定（. s x X F 等）。
;; 注意3：不能用小写 "m" —— meow Keypad 把 ?m 保留作 meta 修饰前缀
;;   （meow-keypad-meta-prefix），SPC 菜单里的 m 会被拦截且不显示。
;;   故 ghostel-project 用 "t"（terminal），list-buffers 用 "M"。
(map! :leader
      (:prefix "p"
       :desc "Ghostel project"          "t" #'ghostel-project
       :desc "Ghostel project buffers"  "M" #'ghostel-project-list-buffers))
(use-package! ghostel
  :config
  ;; 默认 shell 用 fish（登录 shell，匹配真实终端的体验）。
  ;; ghostel-shell 独立于顶层的 shell-file-name（后者仍用 bash，影响 shell-command）。
  (setopt ghostel-shell (list (executable-find "fish") "--login"))
  ;; semi-char 模式下 C-s/C-k/M-p/M-n 默认被发给终端；加入
  ;; ghostel-keymap-exceptions 让它们 pass through 给 Emacs。
  ;; setopt 走 custom :set → 触发 ghostel--rebuild-semi-char-keymap 重建 keymap，
  ;; 所以下面的键绑定必须放在重建之后（即这里）。
  ;; ghostel 是终端模拟器，按键靠 local keymap（remap self-insert → 发终端）。
  ;; 但 meow 的 state keymaps（normal/motion/beacon/insert）通过
  ;; emulation-mode-map-alists 参与按键查找，优先级高于所有 minor/local keymap；
  ;; 且 meow-global-mode 开启时 (setq-default meow-normal-mode t)，导致 ghostel
  ;; 里 j/k 被 meow 拦截（NORMAL 态是移动、INSERT 态被 +meow/insert-escape
  ;; 抢走），打不出 j/k。注意 meow-mode 本身不含 j/k 绑定，真正拦截的是
  ;; state keymaps，所以只关 meow-mode 无效。
  ;; 修复：ghostel buffer 中把 meow 的 state modes 全部 buffer-local 置 nil，
  ;; 使 emulation-mode-map-alists 对应条目失效。
  ;; 注意 ghostel-mode-hook 先于 after-change-major-mode-hook 运行，
  ;; 在 hook 里直接关 state mode 会被之后的 meow-global-mode-enable-in-buffer
  ;; 重新打开；故用 run-at-time 0 延迟到调用栈展开后执行。
  (defun +ghostel-suppress-meow-state ()
    (when (derived-mode-p 'ghostel-mode)
      (dolist (mode '(meow-normal-mode meow-motion-mode meow-beacon-mode
                      meow-insert-mode meow-keypad-mode))
        (when (boundp mode)
          (set (make-local-variable mode) nil)))))
  (add-hook! 'ghostel-mode-hook
    (lambda ()
      (let ((buf (current-buffer)))
        (run-at-time 0 nil
                     (lambda ()
                       (when (buffer-live-p buf)
                         (with-current-buffer buf
                           (+ghostel-suppress-meow-state))))))))
  (setopt ghostel-keymap-exceptions
          (cl-union '("C-s" "C-k" "M-p" "M-n")
                    ghostel-keymap-exceptions :test #'equal))
  (map! :map ghostel-semi-char-mode-map
        "C-s" #'consult-line
        ;; C-k: 关闭当前 ghostel 终端（ghostel 没有专用 close 命令，kill-buffer 即关闭）
        "C-k" #'kill-current-buffer
        "M-p" (lambda () (interactive) (ghostel-send-key "p" "ctrl"))
        "M-n" (lambda () (interactive) (ghostel-send-key "n" "ctrl")))
  ;; ghostel 里允许 eval 的 Emacs 命令（C-c 前缀）
  (add-to-list 'ghostel-eval-cmds '("magit-status-setup-buffer" magit-status-setup-buffer))
  ;; M-x project-switch-project 的项目切换菜单加入 Ghostel 条目
  ;; （project-switch-commands 是内置 project.el 的变量，需等其加载）
  (with-eval-after-load 'project
    (add-to-list 'project-switch-commands '(ghostel-project "Ghostel") t)
    (add-to-list 'project-switch-commands '(ghostel-project-list-buffers "Ghostel buffers") t)))

;;; dirvish 文件管理器（dired 增强，键位参考 yazi）
;; meow 对 dired 等特殊 mode 默认用 MOTION state；其 keymap 只占用了
;; [escape] 和 SPC 两个键，其余单键都会落到 dirvish-mode-map，
;; 因此下面的绑定在 dirvish 里全部生效（唯一例外：SPC 是 meow keypad，
;; 所以标记用 dired 默认的 m，空格无法用作 yazi 的选中）。
(use-package! dirvish
  :custom
  ;; defcustom，必须走 custom 路径（:custom / setopt）才会触发 transient
  ;; 菜单重建；setq 无效
  (dirvish-quick-access-entries
   '(("h" "~/"                          "Home")
     ("d" "~/Downloads/"                "Downloads")
     ("o" "~/org/"                      "Org")
     ("c" "~/.config/"                  "Config")
     ("t" "~/.local/share/Trash/files/" "Trash")
     ("e" "/sudo:root@localhost:/etc"   "System")
     ("w" "~/codes/" "Work"))
   )
  :config
  (setq dirvish-mode-line-format
        '(:left (sort symlink) :right (omit yank index)))
  (setq dirvish-attributes
        '(vc-state subtree-state nerd-icons collapse git-msg file-time file-size)
        dirvish-side-attributes
        '(vc-state nerd-icons collapse file-size)
        dirvish-large-directory-threshold 20000)
  :bind
  (:map dirvish-mode-map
        ;; --- yazi 风格导航 ---
        ("j"   . dired-next-line)       ; 下移（dired 默认 j 是 goto-file）
        ("k"   . dired-previous-line)   ; 上移（默认 k 是 kill-lines）
        ("h"   . dired-up-directory)    ; 上级目录
        ("l"   . dired-find-file)       ; 进入 / 打开（默认 l 是 redisplay）
        ("G"   . end-of-buffer)         ; 跳到底部
        ;; --- yazi 风格文件操作 ---
        ("y"   . dirvish-yank-menu)     ; 粘贴/移动菜单（标记源后到目标目录按 y/p）
        ("p"   . dirvish-yank-menu)     ; yazi 的 p = paste
        ("x"   . dired-do-rename)       ; 剪切 = 移动（默认 x 是执行删除）
        ("d"   . dired-do-delete)       ; 删除（走系统回收站，见下）
        ("a"   . dired-create-directory) ; 新建目录
        ("r"   . dired-do-rename)       ; 重命名 / 移动
        ;; --- 过滤与显示 ---
        ("/"   . dirvish-narrow)        ; 过滤列表（yazi 的 /）
        ("N"   . dirvish-narrow)
        ("."   . dired-omit-mode)       ; 切换隐藏文件
        ;; --- dirvish 增强（官方 sample config） ---
        (";"   . dired-up-directory)
        ("?"   . dirvish-dispatch)      ; [??] 快捷键速查表
        ("o"   . dirvish-quick-access)  ; [o] 快速访问（上面的 entries）
        ("s"   . dirvish-quicksort)     ; [s] 排序
        ("v"   . dirvish-vc-menu)       ; [v] git 操作
        ("f"   . dirvish-file-info-menu) ; [f] 文件信息
        ("*"   . dirvish-mark-menu)
        ("^"   . dirvish-history-last)  ; 最近访问
        ("TAB" . dirvish-subtree-toggle) ; 展开/折叠子树
        ("M-f" . dirvish-history-go-forward)
        ("M-b" . dirvish-history-go-backward)
        ("M-e" . dirvish-emerge-menu)))

;; ---- dirvish 入口收拢到 SPC d（d = directory）----
;; Doom 默认把 dirvish 入口散在 SPC f 下（f /、f p、f P），这里统一
;; 收到 SPC d；原 SPC f 的三个 dirvish 专属键解除（f - dired-jump、
;; f d dired 是通用键，保留原位）。SPC d 在 meow 下原本空闲。
(map! :leader
      (:prefix ("d" . "directory")
       :desc "Dirvish"                   "d" #'dirvish
       :desc "Jump to current dir"       "j" #'dired-jump
       :desc "Project sidebar"           "s" #'dirvish-side
       :desc "Sidebar and follow"        "S" #'+dired/dirvish-side-and-follow))
;; 解除 Doom 默认在 SPC f 下的 dirvish 入口（无 desc，纯 unset）
(map! :leader "f /" nil "f p" nil "f P" nil)

;; 删除走系统回收站（配合 quick-access 里的 Trash 入口）
(setq delete-by-moving-to-trash t)

;; 隐藏文件：dired-omit-mode 默认隐藏所有 dotfile（dired-x 内置）
(use-package! dired-x
  :config
  (setq dired-omit-files
        (concat dired-omit-files "\\|^\\..*$")))


;; ---- tmux 式会话持久化：daemon + session 自动恢复 ----
;; 分三层理解：
;; 1. daemon 常驻：Doom 在图形帧会自动 server-start（lisp/doom.el:537），
;;    `emacs --daemon` 启动后，emacsclient 连上/断开，buffers/windows/
;;    workspaces 全都在 daemon 里存活着 —— 这就是 tmux 的 detach。
;; 2. 重启电脑后恢复：persp-mode（:ui workspaces 的后端）在 Emacs 优雅
;;    退出时把全部 workspaces + 各自 buffer 列表 + window 布局
;;    （persp-window-conf）存到 {state}/workspaces/autosave；
;;    下次启动时 doom-load-session（SPC TAB R 即它，免确认版）一键还原。
;; 3. 坑：Doom 把 +workspaces-delete-associated-workspace-h 挂在
;;    server-done-hook —— emacsclient 关 frame（detach）时会连带 kill
;;    该 frame 关联的 workspace，导致 tabs 丢失。对"detach 保 tab"
;;    的需求必须移除它。
(after! persp-mode
  ;; detach（emacsclient 关 frame）不删除关联的 workspace
  (remove-hook 'delete-frame-functions #'+workspaces-delete-associated-workspace-h)
  (remove-hook 'server-done-hook #'+workspaces-delete-associated-workspace-h))

;; 启动后自动恢复上次 session（persp-mode 已在 doom-init-ui 阶段启动；
;; 此 hook 在 daemon 启动完成时执行）
(add-hook 'doom-after-init-hook #'doom-load-session)

;; minibuffer 历史 / kill-ring 等也跨会话保留（Emacs 内置 savehist）
(setq savehist-additional-variables '(kill-ring mark-ring register-alist))
(savehist-mode 1)

;; ---- 拼写检查：enchant 后端 + en_US 字典 ----
;; 系统 locale 是 zh_CN.UTF-8，flyspell 默认找 zh_CN 字典 → 报
;; "No dictionary available for 'zh_CN.UTF-8'"。中文没有拼写字典，
;; 固定用 en_US（需系统装有 hunspell + hunspell-en_us，见下）。
(setq ispell-dictionary "en_US")

;; 中文无法拼写检查：跳过含汉字的词，只查英文（避免中文被划红线）
(defun my/flyspell-skip-cjk ()
  "当前词含汉字则跳过拼写检查（返回 nil），否则检查。"
  (let ((word (thing-at-point 'word t)))
    (or (null word)
        (not (string-match-p "[一-鿿]" word)))))

(add-hook 'flyspell-mode-hook
          (lambda ()
            (setq-local flyspell-generic-check-word-predicate
                        #'my/flyspell-skip-cjk)))

;; ---- 自动保存：super-save（切 buffer / 失焦 / 空闲 5s 写原文件）----
;; 新版 super-save 用 hook 驱动（window-buffer-change / focus-change），
;; 对 daemon + emacsclient 场景友好：切 frame、切 buffer、焦点离开
;; Emacs（比如切到 qutebrowser）都会保存当前 buffer。
(use-package! super-save
  :config
  (super-save-mode +1)
  (setq super-save-auto-save-when-idle t  ; 空闲 5 秒也保存（org 打字停顿即落盘）
        super-save-idle-duration 5
        ;; tramp 远程文件不自动保存，避免频繁网络写盘卡顿
        super-save-remote-files nil))

;; ---- daemon 自动检查：配置更新了没重启，主动提醒 ----
;; 背景：`doom sync` 只装包/生成 autoloads（etc/@/init.d/*-loaddefs*），
;; 运行中的 daemon 不会自动加载。曾因此 emacs-everywhere 报 void-function。
;; 这里记录本进程启动时刻，定期比对用户配置与 sync 产物 mtime，发现
;; 更新就提示重启 —— 免去"改了配置忘了重启"的坑。
(defvar my/daemon-start-time (current-time)
  "本进程启动时间（用于检测配置是否在启动后被更新）。")

(defvar my/doom-stale-notified nil
  "是否已提示过配置过期（避免每 5 分钟刷一次消息）。")

(defun my/doom-config-files ()
  "返回需监控的配置文件：用户配置 + doom sync 生成的 autoloads。"
  (append
   (list (expand-file-name "init.el" doom-user-dir)
         (expand-file-name "packages.el" doom-user-dir)
         (expand-file-name "config.el" doom-user-dir))
   (directory-files-recursively doom-data-dir ".*-loaddefs.*\\.el$")))

(defun my/doom-check-stale-config ()
  "若发现比本进程启动更晚的配置/autoloads，提示重启 Emacs 使其生效。"
  (when-let* ((newer (seq-filter
                      (lambda (f)
                        (and (file-exists-p f)
                             (not (time-less-p
                                   (file-attribute-modification-time (file-attributes f))
                                   my/daemon-start-time))))
                      (my/doom-config-files))))
    (unless my/doom-stale-notified
      (setq my/doom-stale-notified t)
      (message (concat "[Doom] 检测到配置文件在启动后更新（"
                       (mapconcat #'file-name-nondirectory newer ", ")
                       "），改动尚未生效。请%s："
                       "`emacsclient --eval \"(kill-emacs)\"` 后重新 `emacs --daemon &`，"
                       "或在 Emacs 内 M-x doom/restart。")
               (if (daemonp) "重启 daemon" "重启 Emacs")))))

;; 启动后稍作等待再查一次；之后每 5 分钟复查（emacsclient 连上时 idle timer 会触发）
(run-with-idle-timer 10 nil #'my/doom-check-stale-config)
(run-with-timer 300 300 #'my/doom-check-stale-config)

;; ---------------------------------------------------------------------------
;; yasnippet 修复：python-ts-mode 等 treesit 模式的 snippets 无法触发
;;
;; 背景：python 的 snippets 全部注册在 `python-mode' 表下，而 Emacs 30 的
;; python-ts-mode 通过 `derived-mode-add-parents' 继承 python-mode。yasnippet
;; 用 JIT 懒加载（`yas--scheduled-jit-loads'）——表只在模式激活时加载。
;; 若 buffer 的 `yas-minor-mode' 在 JIT 调度完成前已开启（如 daemon 启动
;; 早期恢复的 buffer），之后切到 python-ts-mode 不会重新触发 JIT 消费，
;; 导致 `python-mode' 表永不加载 → snippets 无法展开（TAB 落到缩进）。
;;
;; 修复：每次 major-mode 设置/切换时都消费 JIT。`yas--load-pending-jits'
;; 幂等（已加载的表自动跳过），对任何时序都安全。
;; ---------------------------------------------------------------------------
(after! yasnippet
  (add-hook 'after-change-major-mode-hook #'yas--load-pending-jits))

;; ---- Forge (GitHub Issues / PR / Notifications) ----
(after! forge
  (setq forge-owned-accounts '(("JackTheMico"))))

;; Forge 专属 buffer 与 Meow 兼容：进入 EMACS state 避免 Meow 拦截单键操作（c, e, k, d, m, q 等）
(after! meow
  (dolist (mode '(forge-topic-mode
                  forge-topics-mode
                  forge-notifications-mode
                  forge-repositories-mode))
    (add-to-list 'meow-mode-state-list (cons mode 'emacs))))

;; 便捷 Leader 键（SPC v 为 Doom +emacs-bindings 下的版本控制前缀）
(map! :leader
      (:prefix "v"
       :desc "List notifications" "N" #'forge-list-notifications
       :desc "List issues"        "I" #'forge-list-issues
       :desc "List pull requests" "P" #'forge-list-pullreqs
       :desc "Forge dispatch"     "@" #'forge-dispatch
       :desc "Forge dispatch"     "'" #'forge-dispatch))

;; ============================================================================
;; Markdown 博客排版与沉浸专注增强（valign + pangu-spacing + olivetti + mixed-pitch）
;; ============================================================================
(after! markdown-mode
  (setq markdown-fontify-whole-heading-line t
        markdown-fontify-code-blocks-natively t
        markdown-max-image-size '(800 . 600)
        markdown-display-remote-images t)

  (add-hook! '(markdown-mode-hook gfm-mode-hook)
    #'olivetti-mode
    #'mixed-pitch-mode
    #'valign-mode
    #'pangu-spacing-mode))

(after! pangu-spacing
  ;; 仅在渲染层添加视觉垫空（overlay），绝不向文件写入实体空格，避免污染 Git diff 与 Frontmatter
  (setq pangu-spacing-real-insert-separtor nil))

(after! olivetti
  (setq-default olivetti-body-width 88
                olivetti-minimum-body-width 60))

;; ============================================================================
;; CloudFlare-ImgBed 图床异步上传与 Firefly 博客写作工作流
;; 依赖：系统已装 curl；Wayland 用 wl-paste，X11 用 xclip
;; Token 从 ~/.authinfo.gpg 读取（machine = my/imgbed-auth-host），明文不落配置。
;; ============================================================================
(defcustom my/imgbed-host "https://jackwyimgbed.dlwxxxdlw.workers.dev"
  "CloudFlare-ImgBed 主机根地址。")

(defcustom my/imgbed-endpoint "https://jackwyimgbed.dlwxxxdlw.workers.dev/upload"
  "CloudFlare-ImgBed 上传端点。本仓库为 /upload（Cloudflare Pages/Worker 路由）。")

(defcustom my/imgbed-auth-host "jackwyimgbed.dlwxxxdlw.workers.dev"
  "auth-source 主机名，对应 ~/.authinfo.gpg 中 `machine' 字段。
Token 在每次上传时惰性读取，避免 Emacs 启动阶段触发 gpg 解密而卡住。")

(defcustom my/imgbed-token nil
  "API Token 覆盖值。nil（默认）= 上传时从 ~/.authinfo.gpg 读取。")

(defcustom my/imgbed-authcode nil
  "用户端 authCode（若不用 API Token，则在后台 Security 配置后填这里，或用 ?authCode= 头）。")

(defun my/imgbed--token ()
  "返回可用的 API Token：优先 `my/imgbed-token'，否则从 auth-source 读取。
对应 ~/.authinfo.gpg 中 machine = `my/imgbed-auth-host' 的 password 字段。"
  (or my/imgbed-token
      (ignore-errors
        (require 'auth-source nil t)
        (let* ((entries (auth-source-search :host my/imgbed-auth-host :max 1))
               (secret (plist-get (car entries) :secret)))
          (if (functionp secret) (funcall secret) secret)))))

(defun my/imgbed--extract-url (json-str)
  "从 CloudFlare-ImgBed 响应 JSON 数组中提取第一项的 src（或 publicUrl）。
若 src 为相对路径（如 /file/...），自动补全图床域名。"
  (condition-case nil
      (let* ((data (with-temp-buffer
                     (insert json-str)
                     (goto-char (point-min))
                     (json-parse-buffer :object-type 'alist :array-type 'list)))
             (first (car data))
             (src (or (alist-get 'src first) (alist-get 'publicUrl first))))
        (when (and src (stringp src) (not (string-empty-p src)))
          (if (string-prefix-p "http" src)
              src
            (concat (string-remove-suffix "/" my/imgbed-host) src))))
    (error nil)))

(defun my/imgbed-upload-async (file &optional delete-after custom-alt)
  "异步上传 FILE 到图床；完成后在调用处的 marker 插入链接。
DELETE-AFTER 非 nil 时，上传结束（无论成败）删除临时文件。
CUSTOM-ALT 优先作为 Markdown alt 描述；若未提供则提示输入。"
  (let* ((buf (current-buffer))
         (marker (copy-marker (point)))
         (mode (if (derived-mode-p 'org-mode) 'org 'md))
         (default-name (file-name-sans-extension (file-name-nondirectory file)))
         (alt (or custom-alt
                  (read-string (format "图片描述 (Alt Text，默认 %s): " default-name)
                               nil nil default-name)))
         (url (concat my/imgbed-endpoint "?returnFormat=full"))
         (token (my/imgbed--token))
         (args (list "-s" "-F" (concat "file=@" (expand-file-name file)))))
    (when token
      (setq args (append args (list "-H" (concat "Authorization: Bearer " token)))))
    (when my/imgbed-authcode
      (setq args (append args (list "-H" (concat "authCode: " my/imgbed-authcode)))))
    (setq args (append args (list url)))
    (message "正在上传图片至图床: %s ..." (file-name-nondirectory file))
    (make-process
     :name "imgbed-upload"
     :buffer (generate-new-buffer " *imgbed-upload*")
     :command (cons "curl" args)
     :sentinel
     (lambda (proc _event)
       (unless (process-live-p proc)
         (let* ((status (process-exit-status proc))
                (out (with-current-buffer (process-buffer proc)
                       (buffer-string)))
                (final-url (my/imgbed--extract-url out)))
           (kill-buffer (process-buffer proc))
           (when delete-after (ignore-errors (delete-file file)))
           (if (or (/= 0 status) (null final-url) (string-empty-p (string-trim final-url)))
               (message "图床上传失败（curl exit %d）：%s" status (string-trim out))
             ;; 复制到系统剪贴板（便于粘贴至 Frontmatter 的 image: 封面）
             (kill-new final-url)
             (if (buffer-live-p buf)
                 (with-current-buffer buf
                   (save-excursion
                     (goto-char (marker-position marker))
                     (insert (if (eq mode 'org)
                                 (format "[[%s][%s]]\n" final-url alt)
                               (format "![%s](%s)\n" alt final-url))))
                   (set-marker marker nil)
                   (when (and (eq mode 'md) (display-images-p) (fboundp 'markdown-display-inline-images))
                     (ignore-errors (markdown-display-inline-images)))
                   (message "图床上传成功并已复制 URL: %s" final-url))
               (message "原 buffer 已关闭，上传成功 URL: %s" final-url)))))))))

(defun +firefly/imgbed-upload-file (file)
  "选本地图片文件异步上传至图床，并在 point 插入 Markdown 链接。"
  (interactive "f图片文件: ")
  (my/imgbed-upload-async (expand-file-name file)))

(defun +firefly/imgbed-upload-clipboard ()
  "抓取系统剪贴板图片落临时文件并异步上传至图床，在 point 插入 Markdown 链接。"
  (interactive)
  (let ((tmp (make-temp-file "imgbed-" nil ".png")))
    (cond
     ((getenv "WAYLAND_DISPLAY")
      (call-process "wl-paste" nil nil nil "-t" "image/png" "-o" tmp))
     ((executable-find "wl-paste")
      (call-process "wl-paste" nil nil nil "-t" "image/png" "-o" tmp))
     ((executable-find "xclip")
      (call-process "xclip" nil nil nil "-selection" "clipboard" "-t" "image/png" "-o" tmp))
     (t (user-error "未检测到剪贴板工具（wl-paste 或 xclip）")))
    (if (and (file-exists-p tmp) (> (file-attribute-size (file-attributes tmp)) 0))
        (my/imgbed-upload-async tmp t)
      (when (file-exists-p tmp) (delete-file tmp))
      (user-error "剪贴板中未检测到图片（或未成功保存）"))))

;; 保持向后兼容别名
(defalias 'my/imgbed-insert #'+firefly/imgbed-upload-file)
(defalias 'my/imgbed-paste-clipboard #'+firefly/imgbed-upload-clipboard)

;; 本地 Page Bundle 截图快速粘贴（离线保存为相对路径）
(defun +firefly/markdown-paste-clipboard-image ()
  "从系统剪贴板粘贴图片，保存到当前博客 Page Bundle 目录并插入相对路径 Markdown 语法。"
  (interactive)
  (unless buffer-file-name
    (user-error "当前 Buffer 未关联到具体文件，无法确定图片保存路径"))
  (let* ((post-dir (file-name-directory buffer-file-name))
         (is-bundle (string-equal (file-name-nondirectory buffer-file-name) "index.md"))
         (img-dir (if is-bundle
                      post-dir
                    (expand-file-name "images" post-dir)))
         (time-str (format-time-string "%Y%m%d-%H%M%S"))
         (filename (format "img-%s.png" time-str))
         (filepath (expand-file-name filename img-dir))
         (rel-path (file-relative-name filepath post-dir)))
    (unless (file-directory-p img-dir)
      (make-directory img-dir t))
    (cond
     ((getenv "WAYLAND_DISPLAY")
      (call-process "wl-paste" nil nil nil "--type" "image/png" "--output" filepath))
     ((executable-find "wl-paste")
      (call-process "wl-paste" nil nil nil "--type" "image/png" "--output" filepath))
     ((executable-find "xclip")
      (call-process "xclip" nil nil nil "-selection" "clipboard" "-target" "image/png" "-out" filepath))
     (t (user-error "未检测到 wl-paste 或 xclip，请先安装剪贴板工具")))
    (if (and (file-exists-p filepath) (> (file-attribute-size (file-attributes filepath)) 0))
        (let ((alt (read-string (format "图片描述 (Alt Text，默认 %s): " filename) nil nil filename)))
          (insert (format "![%s](%s)\n" (if (string-empty-p alt) filename alt) rel-path))
          (message "图片已保存至: %s" rel-path)
          (when (and (display-images-p) (fboundp 'markdown-display-inline-images))
            (ignore-errors (markdown-display-inline-images))))
      (when (file-exists-p filepath) (delete-file filepath))
      (user-error "剪贴板中未检测到图片或图片保存失败"))))

;; Astro 本地 Dev Server 实时预览联动
(defun +firefly/open-post-in-browser ()
  "在默认浏览器中打开当前 Firefly 博客文章的本地实时预览页面 (http://localhost:4321)。"
  (interactive)
  (let* ((filename (buffer-file-name))
         (post-slug (when (and filename (string-match "src/content/posts/\\([^/.]+\\)" filename))
                      (match-string 1 filename))))
    (if post-slug
        (progn
          (message "正在打开本地预览: http://localhost:4321/posts/%s" post-slug)
          (browse-url (format "http://localhost:4321/posts/%s" post-slug)))
      (message "未能从当前路径识别文章 slug，打开博客主页: http://localhost:4321")
      (browse-url "http://localhost:4321"))))

;; Astro 博客项目根目录与动态创建
(defcustom +firefly-blog-dir (expand-file-name "~/codes/Firefly")
  "Firefly Astro 博客项目根目录路径。")

(defun +firefly/new-dynamic ()
  "在 Firefly 博客的 dynamic 目录下新建时间戳命名的动态文件，并自动填充 Frontmatter。
打开后光标停留在正文首行，并自动进入 Meow INSERT 态。"
  (interactive)
  (let* ((dynamic-dir (expand-file-name "src/content/dynamic" +firefly-blog-dir))
         (time (current-time))
         (filename (format-time-string "%Y-%m-%d-%H%M%S.md" time))
         (published (format-time-string "%Y-%m-%d %H:%M:%S" time))
         (filepath (expand-file-name filename dynamic-dir)))
    (unless (file-directory-p dynamic-dir)
      (make-directory dynamic-dir t))
    (find-file filepath)
    (when (= (buffer-size) 0)
      (insert (format "---\npublished: %s\n---\n\n" published))
      (goto-char (point-max))
      (when (fboundp 'meow-insert-mode)
        (meow-insert-mode 1))
      (message "已创建动态: %s" filename))))

;; ----------------------------------------------------------------------------
;; 新建博客文章（单文件范式）：frontmatter 单一真源，命令与文件模板共用
;; ----------------------------------------------------------------------------

(defcustom +firefly-posts-default-subdir "writing"
  "新建文章时的默认子目录（相对于 posts 集合根目录）。
该目录不存在时由 `+firefly/new-post' 自动创建。")

(defun +firefly--posts-dir ()
  "返回 Firefly 博客 posts 集合根目录。"
  (expand-file-name "src/content/posts" +firefly-blog-dir))

(defun +firefly-post-frontmatter (slug)
  "为 SLUG 生成 Firefly posts 集合的 frontmatter 字符串。
字段集对齐仓库现有文章：不写 draft，交由 `src/content.config.ts' 的 Zod 默认值处理。"
  (format "---\ntitle: %s\npublished: %s\ndescription: \"\"\nimage: \"\"\ntags: []\ncategory:\n---\n\n"
          slug
          (format-time-string "%Y-%m-%d")))

(defun +firefly--post-slug-read ()
  "读取并校验文章 slug；非法时 `user-error'。"
  (let ((slug (string-trim (read-string "文章 slug: "))))
    (when (or (string-empty-p slug)
              (string-match-p "[/\\\\[:space:]]" slug))
      (user-error "slug 非法（不可为空，且不可含 / \\ 或空白字符）: %S" slug))
    slug))

(defun +firefly--post-subdir-read ()
  "交互选择文章子目录，返回目录名（相对于 posts 集合根目录）。"
  (let* ((posts-dir (+firefly--posts-dir))
         (candidates (when (file-directory-p posts-dir)
                       (seq-filter #'file-directory-p
                                   (directory-files posts-dir t "\\`[^.]")))))
    (completing-read "文章目录: "
                     (mapcar #'file-name-nondirectory candidates)
                     nil nil +firefly-posts-default-subdir)))

(defun +firefly--post-insert-frontmatter (&optional slug)
  "在当前空 buffer 写入 frontmatter，并把光标停在正文首行。
SLUG 省略时取当前文件 basename（文件模板路径用）。非空 buffer 不做任何事，
返回非 nil 表示确实写入了内容。"
  (when (= (buffer-size) 0)
    (insert (+firefly-post-frontmatter
             (or slug
                 (file-name-base (or (buffer-file-name) "")))))
    (goto-char (point-max))
    t))

(defun +firefly/new-post ()
  "在 Firefly 博客 posts 集合下新建单文件文章。
交互选择子目录与 slug，写入标准 frontmatter 后光标停在正文首行，并自动进入
Meow INSERT 态。目标文件已存在时报错拒绝，不覆盖、不打开。"
  (interactive)
  (let* ((posts-dir (+firefly--posts-dir))
         (subdir (+firefly--post-subdir-read))
         (dir (expand-file-name (if (string-empty-p subdir)
                                    +firefly-posts-default-subdir
                                  subdir)
                                posts-dir))
         (slug (+firefly--post-slug-read))
         (filepath (expand-file-name (concat slug ".md") dir)))
    ;; 文件已落盘，或已有未保存的同路径 buffer（上一次调用留下的）时拒绝
    (when (or (file-exists-p filepath)
              (find-buffer-visiting filepath))
      (user-error "文章已存在，未创建: %s" filepath))
    (unless (file-directory-p dir)
      (make-directory dir t))
    (find-file filepath)
    (when (+firefly--post-insert-frontmatter slug)
      (when (fboundp 'meow-insert-mode)
        (meow-insert-mode 1))
      (message "已创建文章: %s"
               (file-relative-name filepath +firefly-blog-dir)))))

;; 文件模板：在 posts 集合下用任意方式新建空 .md 时注入同一份 frontmatter。
;; 触发条件由 Doom 保证（buffer 为空、文件不存在、未被修改），现有文章不受影响。
(set-file-template! "/Firefly/src/content/posts/.+\\.md\\'"
  :mode 'markdown-mode
  :trigger (lambda ()
             (when (and buffer-file-name
                        (not (file-exists-p buffer-file-name)))
               (insert (+firefly-post-frontmatter
                        (file-name-base buffer-file-name)))
               (goto-char (point-max))
               (when (fboundp 'meow-insert-mode)
                 (meow-insert-mode 1)))))

;; ============================================================================
;; Meow 键位绑定：NORMAL 态单键 Localleader (,) 与 Markdown 博客专属前缀
;; ============================================================================
(after! meow
  ;; NORMAL 态单键 , 触发 Localleader (C-c c)
  (meow-define-keys 'normal '("," . "C-c c")))


(map! :map (markdown-mode-map gfm-mode-map)
      :localleader
      :desc "Astro 本地实时预览"   "p" #'+firefly/open-post-in-browser
      :desc "粘贴本地 Page Bundle 图片" "P" #'+firefly/markdown-paste-clipboard-image
      (:prefix ("u" . "upload-imgbed")
       :desc "上传剪贴板图片至图床" "c" #'+firefly/imgbed-upload-clipboard
       :desc "选择本地图片上传至图床" "f" #'+firefly/imgbed-upload-file)
      (:prefix ("n" . "new")
       :desc "新建 Firefly 动态" "d" #'+firefly/new-dynamic
       :desc "新建博客文章" "p" #'+firefly/new-post))

;; 全局 SPC i 图床快捷入口保留
(map! :leader
      (:prefix ("i" . "imgbed")
       :desc "Upload image file & insert URL" "u" #'+firefly/imgbed-upload-file
       :desc "Paste clipboard image & insert URL" "p" #'+firefly/imgbed-upload-clipboard)
      (:prefix "n"
       :desc "新建 Firefly 动态" "d" #'+firefly/new-dynamic))



