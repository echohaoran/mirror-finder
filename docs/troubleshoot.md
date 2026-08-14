# 故障排除

## 菜单显示后直接退出，随后输入 `1: command not found`

原因是用 `curl ... | bash` 运行时，Bash 的标准输入是下载的脚本文本而不是终端；脚本
读取菜单选项时会读到文件结尾并退出，之后输入的数字由 Shell 当作命令执行。

请使用：

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/echohaoran/mirror-finder/main/scripts/install.sh)"
```

脚本也会优先从 `/dev/tty` 读取交互输入，因此即使仍通过管道启动，在正常终端中也能读取
菜单选择。
