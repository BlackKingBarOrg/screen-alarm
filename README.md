# screen-alarm

坐姿 / 站姿交替提醒：坐 40 分钟、站 15 分钟，时间到就用全屏遮罩盖住主屏幕（DP-1）。
在遮罩上选下一个姿势（开始坐 / 开始站）后才重新计时。

- 遮罩上默认选中"换一个姿势"，← → 切换，Enter 确认，也可以直接点按钮
  （遮罩出现后 1.5 秒内的按键和点击会被忽略，防止打字时误选）
- 遮罩显示期间键盘被独占，按键不会落到下面的窗口
- 颜色跟随当前 Omarchy 主题
- 每次启动（开机登录、重启服务）都从"坐"开始

## 顶栏

时钟右边显示当前姿势和剩余分钟：坐着 `󰽈 32m`，站着 `󰋦 12m`。遮罩弹出时变红，
显示 `󰋦 该站了` / `󰽈 该坐了`。服务没运行时自动隐藏。

点击会弹出浮窗，可以随时选"开始坐"或"开始站"，选了就从头计时（遮罩弹出时选也会关掉遮罩）。
浮窗里 ← → 选择，Enter 确认，Esc 或点外面取消。

`bar/` 是一个 Omarchy shell 插件（`ai.bkblab.screen-alarm`），只读取守护进程写在
`$XDG_RUNTIME_DIR/screen-alarm.json` 里的状态，自己不计时。修改 `bar/` 下的文件后要
`omarchy restart shell` 才会生效（shell 的文件监听不会跟进符号链接）。
从顶栏移除：删掉 `~/.config/omarchy/shell.json` 中 `ai.bkblab.screen-alarm` 那一项。

## 常用命令

```bash
systemctl --user status screen-alarm            # 状态
journalctl --user -u screen-alarm -f            # 日志
systemctl --user kill -s USR1 screen-alarm      # 立刻弹一次遮罩（预览）
systemctl --user restart screen-alarm           # 改完代码或参数后重启
systemctl --user disable --now screen-alarm     # 停用并取消自启
omarchy-shell ai.bkblab.screen-alarm toggle     # 打开/关闭顶栏浮窗，可以绑快捷键

# 直接开始坐 / 站（浮窗按钮做的就是这个），把 'stand' 换成 'sit' 就是开始坐
gdbus call --session --dest ai.bkblab.ScreenAlarm --object-path /ai/bkblab/ScreenAlarm \
  --method org.gtk.Actions.Activate start "[<'stand'>]" "{}"
```

## 修改时长或屏幕

编辑 `systemd/screen-alarm.service` 里的 `ExecStart` 参数（`--sit`、`--stand` 是分钟数，
`--monitor` 是屏幕名，用 `hyprctl monitors` 查看），然后：

```bash
systemctl --user daemon-reload && systemctl --user restart screen-alarm
```

## 安装

```bash
systemctl --user enable --now ~/Work/screen-alarm/systemd/screen-alarm.service
ln -sfn ~/Work/screen-alarm/bar ~/.config/omarchy/plugins/ai.bkblab.screen-alarm
omarchy-shell -q shell rescanPlugins
omarchy bar put ai.bkblab.screen-alarm --after omarchy.clock
```

服务和插件都以符号链接方式安装，项目目录不能移动；移动后需重新执行上面的安装命令。
`systemd/screen-alarm.service` 里的 `ExecStart` 写的是 `%h/Work/screen-alarm` 和 `--monitor DP-1`，
克隆到别处或者主屏不是 DP-1 时，先改这一行再安装。
依赖：`python-gobject`、`gtk4`、`gtk4-layer-shell`。
