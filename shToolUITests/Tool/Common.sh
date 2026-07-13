#!/bin/bash
# Created at: 12/12/2025
# Author: Jingxin Zeng (cn33331@163.com)

# 定义颜色代码
RED=$(tput setaf 1)     # 红色（前景色编号1）
GREEN=$(tput setaf 2)   # 绿色（编号2）
YELLOW=$(tput setaf 3)  # 黄色（编号3）
BLUE=$(tput setaf 4)    # 蓝色（编号4）
MAGENTA=$(tput setaf 5) # 品红（编号5）
CYAN=$(tput setaf 6)    # 青色（编号6）
RESET=$(tput sgr0)      # 重置所有文本属性（颜色/加粗等）

# 常用功能函数
show_menu() {
  clear
  echo "${CYAN}▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂"
  echo "                            ${MAGENTA}Mac 常见方法${CYAN}"
  echo "▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂${RESET}"
  echo "${YELLOW}1 查看当前文件夹结构"
  echo "ssh 查看ssh密钥"
  echo "3 系统信息监测"
  echo "0 退出脚本${RESET}"
  echo "${CYAN}▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂${RESET}"
}

# 微信双开功能
wechat_dual() {
  echo "${GREEN}▶ 正在启动第二个微信实例..."
  nohup /Applications/WeChat.app/Contents/MacOS/WeChat > /dev/null 2>&1 &
  sleep 2
  echo "✅ 第二个微信已启动，请在新窗口登录${RESET}"
  read -n 1 -s -r -p "按任意键返回菜单..."
}

# 系统监测功能
system_monitor() {
  echo "${CYAN}▂▂▂▂▂▂▂ 实时系统监测 ▂▂▂▂▂▂▂"
  echo "CPU使用率: $(top -l 1 | grep -E "^CPU" | awk '{print $3 + $5}')%"
  echo "内存使用: $(vm_stat | perl -ne '/page size of (\d+)/ and $size=$1; /Pages free:\s+(\d+)/ and printf "%.1f GB\n", $1 * $size / 1024 / 1024 / 1024')"
  echo "磁盘空间: $(df -h / | awk 'NR==2{print $4}') 剩余"
  echo "网络状态: $(ping -c 1 8.8.8.8 > /dev/null && echo "✅ 在线" || echo "❌ 离线")"
  read -n 1 -s -r -p "按任意键返回菜单..."
}



file_tree(){
  # find . -print | sed -e 's;[^/]*/;|____;g;s;____|; |;g'
  echo "find . -print | sed -e 's;[^/]*/;|____;g;s;____|; |;g'"
  echo "✅ 当前目录结构已展示"
  read -n 1 -s -r -p "按任意键返回菜单..."
}

ssh_cat(){
  cat ~/.ssh/id_rsa.pub
  echo "✅ 当前目录结构已展示"
  read -n 1 -s -r -p "按任意键返回菜单..."
}



test(){
  find . -type d -name "script"
  echo "查找文件名有某某的文件✅ "
  read -n 1 -s -r -p "按任意键返回菜单..."
}

# 主程序循环
while true; do
  show_menu
  read -p "请输入功能编号: " choice
  
  case $choice in
    1) file_tree;;
    ssh) ssh_cat;;
    3) system_monitor ;;
    0) echo "${RED}退出系统中...${RESET}"; exit 0 ;;
    *) echo "${RED}无效输入，请重新选择${RESET}"; sleep 1 ;;
  esac
done