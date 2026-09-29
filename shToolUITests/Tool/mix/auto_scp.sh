#!/usr/bin/expect
# Created at: 09/08/2026
# Author: Jingxin Zeng (cn33331@163.com)

# 用法: auto_scp.sh <local_path> <mix_path> <IP-version> <RFlag>
# 示例: auto_scp.sh /Users/gdlocal/Downloads/mix/addon/test /mix 192.168.99.32-mix8 R

set timeout 1

set local_path   [ lindex $argv 0 ]  ;# 本地路径（文件/文件夹）
set mix_path     [ lindex $argv 1 ]  ;# 远程目标文件夹（实际从local_path解析）
set mix_path     "/mix"
set IP_version   [ lindex $argv 2 ]  ;# IP-version，如 192.168.99.32-mix8
set RFlag        [ lindex $argv 3 ]

# 解析IP和版本（如 "192.168.99.32-mix8" → IP="192.168.99.32", version="mix8"）
set parts [split $IP_version "-"]
set IP      [lindex $parts 0]
set version [lindex $parts 1]

# 判断路径类型：是文件还是文件夹
proc is_directory {path} {
    if {[file exists $path] && [file isdirectory $path]} {
        return 1
    }
    return 0
}

# 获取文件的相对路径（用于拼接远程路径）
proc get_relative_path {full_path base_dir} {
    set base_dir [file normalize $base_dir]
    set full_path [file normalize $full_path]
    set rel_path [string range $full_path [string length $base_dir]+1 end]
    return $rel_path
}

# 初始化用户和密码（按版本参数区分mix7/mix8）
if {$version == "mix8"} {
    set user "mixadmin"
    set password "mixadmin"
    puts "mix8 mode (user: $user, password: $password)"
} else {
    set user "root"
    set password "123456"
    puts "mix7 mode (user: $user, password: $password)"
}

# 步骤1：建立SSH连接并获取root权限
proc ssh_connect {ip user password} {
    spawn ssh $user@$ip
    expect {
        "*yes/no*?" {send "yes\n"; exp_continue}
        "*$user@*password*" {send "$password\n"; exp_continue}
    }
    send "sudo -s \n"
    expect {
        "*$user@*password*" {send "$password\n"; exp_continue}
        "*password for $user*" {send "$password\n"; exp_continue}
    }
    expect -re {[$#]}
    return $spawn_id
}

# 步骤2：上传单个文件（删除远程对应文件后scp）
# 注意：参数用 sid 而不是 spawn_id，避免 proc 内 spawn scp 覆盖该参数
proc sync_file {local_file user password ip sid} {
    set base_local [file normalize [file dirname $local_file]]
    set mix_path [string range $base_local [string first "/mix/" $base_local] end]
    set rel_path [get_relative_path $local_file $base_local]
    set remote_file "$mix_path/$rel_path"

    # 1. 删除远程单个文件
    send -i $sid "sudo rm -rf $remote_file\n"
    expect -i $sid -re {[$#]}

    # 2. 建目录+赋权
    send -i $sid "mkdir -p $mix_path\n"
    expect -i $sid -re {[$#]}
    send -i $sid "sudo chmod -R 777 $mix_path\n"
    expect -i $sid -re {[$#]}

    # 3. 上传本地文件到远程（-O 避免SFTP模式setstat报错）
    set timeout 100
    spawn scp -O -r $local_file $user@$ip:$mix_path
    expect {
        "*yes/no*?" {send "yes\n"; exp_continue}
        "*$user@*password*" {send "$password\n"; exp_continue}
        timeout {send_user "文件上传超时！\n"; exit 1}
    }
    send_user "已上传本地文件：$local_file -> $mix_path\n"
    set timeout 1
}

# 主逻辑执行（用独立变量 ssh_id 保存 ssh 会话句柄，
# 避免后续 spawn scp 覆盖全局 spawn_id 导致会话丢失）
set ssh_id [ssh_connect $IP $user $password]

# 判断传入的是文件还是文件夹
if {[is_directory $local_path]} {
    # 场景1：传入本地文件夹，单次scp -r上传整个文件夹（不再逐文件传输）
    set local_norm [file normalize $local_path]
    set mix_pos [string first "/mix/" $local_norm]
    if {$mix_pos == -1} {
        set mix_pos [string first "/mix" $local_norm]
    }
    if {$mix_pos == -1} {
        send_user "错误：路径 $local_path 未包含/mix！\n"
        exit 1
    }
    set mix_path [string range $local_norm $mix_pos end]
    set remote_parent [file dirname $mix_path]

    # 1. 建目录+赋权（不删除远程目录，保留原有其他文件，scp -r会覆盖同名文件）
    send -i $ssh_id "mkdir -p $mix_path\n"
    expect -i $ssh_id -re {[$#]}
    send -i $ssh_id "sudo chmod -R 777 $mix_path\n"
    expect -i $ssh_id -re {[$#]}

    # 3. 单次scp -r上传整个文件夹（-O 走传统SCP协议，避免SFTP模式对root属主目录setstat报Permission denied）
    set timeout 100
    spawn scp -O -r $local_path $user@$IP:$remote_parent
    expect {
        "*yes/no*?" {send "yes\n"; exp_continue}
        "*$user@*password*" {send "$password\n"; exp_continue}
        timeout {send_user "文件夹上传超时！\n"; exit 1}
    }
    send_user "已上传本地文件夹：$local_path -> $remote_parent\n"
    set timeout 1
} else {
    # 场景2：传入单个文件
    if {![file exists $local_path]} {
        send_user "本地文件 $local_path 不存在！\n"
        exit 1
    }
    sync_file $local_path $user $password $IP $ssh_id
}

# 重启服务（R/r/y/Y触发，按版本区分命令）
if {$RFlag eq "R" || $RFlag eq "r" || $RFlag eq "y" || $RFlag eq "Y"} {
    set timeout 100
    if {$version == "mix8"} {
        send -i $ssh_id "sync;rm -rf /var/tmp/mix/*;ps -ef | grep lynx | awk '{print \$2}' |xargs -i sudo kill -9 {};sudo bash /mix/etc/scripts/start.sh &> /var/tmp/mix/start.log\r"
        expect -i $ssh_id -re {[$#]}
        send -i $ssh_id "tail -f /var/tmp/mix/start.log\n"
    } else {
        send -i $ssh_id "killall python;sh /mix/lynx/script/start.sh &> /var/tmp/mix_start.log\r"
        expect -i $ssh_id -re {[$#]}
        send -i $ssh_id "tail -f /var/tmp/mix_start.log\n"
    }
    expect -i $ssh_id "start_lynx.py finished"
    send -i $ssh_id "\003"
}

send_user "\n------------- MIX文件同步完成✅ -------------\n"
# interact 默认作用于全局 spawn_id（已被 spawn scp 覆盖为已退出的 scp 进程），
# 先恢复为 ssh 会话句柄，让用户留在远程 root shell 中交互
set spawn_id $ssh_id
interact
