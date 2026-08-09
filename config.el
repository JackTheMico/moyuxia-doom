;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!
(setq shell-file-name (executable-find "bash"))

;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets. It is optional.
(setq user-full-name "Jack Wenyoung"
      user-mail-address "dlwxxxdlw@gmail.com")

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
(setq doom-font (font-spec :family "Maple Mono NF CN" :size 23 :weight 'Medium)
      doom-variable-pitch-font (font-spec :family "LXGW WenKai Screen" :size 21)
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
(setq doom-theme 'doom-dracula)

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
;;   4. org-capture-templates 追加 "p"（PARA project）/"m"（PARA
;;      meeting）模板，Doom 默认模板（t/n → gtd/inbox.org）不受影响
(use-package! vulpea-para
  :after vulpea
  :config
  (vulpea-para-setup-defaults)
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
