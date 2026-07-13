#!/usr/bin/expect
# Created at: 12/12/2025
# Author: Jingxin Zeng (cn33331@163.com)

# /System/Volumes/Data/vault/ZJX_BF/shTool.app/Contents/Resources/Tool/mix/auto_scp.sh /Users/gdlocal/Downloads/mix /mix 192.168.99.36

set timeout 1

set local_path   [ lindex $argv 0 ]  ;# 本地路径（文件/文件夹）
set mix_path     [ lindex $argv 1 ]  ;# 远程目标文件夹
set mix_path     "/mix"
set IP           [ lindex $argv 2 ]
set index        [string first "111" $IP]
set RFlag        [ lindex $argv 3 ]

# 判断路径类型：是文件还是文件夹
proc is_directory {path} {
    if {[file exists $path] && [file isdirectory $path]} {
        return 1
    }
    return 0
}

# 获取路径下的所有文件（递归）
proc get_all_files {dir} {
    set file_list {}
    foreach entry [glob -nocomplain -directory $dir *] {
        if {[file isfile $entry]} {
            lappend file_list $entry
        } elseif {[file isdirectory $entry]} {
            lappend file_list {*}[get_all_files $entry]
        }
    }
    return $file_list
}

# 获取文件的相对路径（用于拼接远程路径）
proc get_relative_path {full_path base_dir} {
    set base_dir [file normalize $base_dir]
    set full_path [file normalize $full_path]
    set rel_path [string range $full_path [string length $base_dir]+1 end]
    return $rel_path
}

# 初始化用户和密码（恢复mix7/mix8不同密码配置）
if {$index == 0} {
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
        # timeout {send_user "SSH连接超时！\n"; exit 1}
    }
    send "sudo -s \n"
    expect {
        "*$user@*password*" {send "$password\n"; exp_continue}
        "*password for $user*" {send "$password\n"; exp_continue}
        # timeout {send_user "获取root权限超时！\n"; exit 1}
    }
    expect -re {[$#]}
    return $spawn_id
}

# 步骤2：删除远程对应文件 + 上传本地文件
proc sync_file {local_file remote_dir user password ip spawn_id} {
    # 获取文件名（如test.py）或相对路径（如subdir/test2.py）
    set base_local [file normalize [file dirname $local_file]]
    # send_user "base_local文件：$base_local\n"
    set mix_path [string range $base_local [string first "/mix/" $base_local] end]
    # send_user "mix_path文件：$mix_path\n"
    set rel_path [get_relative_path $local_file $base_local]
    # send_user "rel_path文件：$rel_path\n"
    set remote_file "$mix_path/$rel_path"

    # 1. 删除远程单个文件（不删文件夹）
    send -i $spawn_id "sudo rm -rf $remote_file\n"
    expect -i $spawn_id -re {[$#]}
    # send_user "已删除远程文件：$remote_file\n"

    # 1.1 
    send -i $spawn_id "mkdir -p $mix_path\n"
    expect -i $spawn_id -re {[$#]}
    # send_user "mkdir：$mix_path\n"

    # 2. 赋予远程文件夹写入权限
    send -i $spawn_id "sudo chmod -R 777 $mix_path\n"
    expect -i $spawn_id -re {[$#]}
    # send_user "已赋予权限：$mix_path\n"

    # 3. 上传本地文件到远程
    set timeout 100
    spawn scp -r $local_file $user@$ip:$mix_path
    expect {
        "*yes/no*?" {send "yes\n"; exp_continue}
        "*$user@*password*" {send "$password\n"; exp_continue}
        timeout {send_user "文件上传超时！\n"; exit 1}
    }
    send_user "已上传本地文件：$local_file -> $mix_path\n"
    set timeout 1
}

# 主逻辑执行
set spawn_id [ssh_connect $IP $user $password]

# 判断传入的是文件还是文件夹
if {[is_directory $local_path]} {
    # 场景1：传入本地文件夹（如/mix/addon/test/），遍历所有文件
    set local_files [get_all_files $local_path]
    if {[llength $local_files] == 0} {
        send_user "本地文件夹 $local_path 为空，无需同步！\n"
        exit 0
    }
    # 遍历每个本地文件，逐个替换远程对应文件
    foreach local_file $local_files {
        sync_file $local_file $mix_path $user $password $IP $spawn_id
    }
} else {
    # 场景2：传入单个文件（如/mix/addon/test/test.py）
    if {![file exists $local_path]} {
        send_user "本地文件 $local_path 不存在！\n"
        exit 1
    }
    sync_file $local_path $mix_path $user $password $IP $spawn_id
}

# 重启服务（如果传入R参数）
if {$RFlag == "R"} {
    set timeout 100
    send -i $spawn_id "sync;rm -rf /var/tmp/mix/*;ps -ef | grep lynx | awk '{print \$2}' |xargs -i sudo kill -9 {};sudo bash /mix/etc/scripts/start.sh &> /var/tmp/mix/start.log\r"
    expect -i $spawn_id -re {[$#]}
    send -i $spawn_id "tail -f /var/tmp/mix/start.log\n"
    expect -i $spawn_id "start_lynx.py finished"
    send -i $spawn_id "\003"
}

# 重启服务
if {$RFlag == "r"} {
    set timeout 100
    send -i $spawn_id "sync;rm -rf /var/tmp/mix/*;ps -ef | grep lynx | awk '{print \$2}' |xargs -i sudo kill -9 {};sudo bash /mix/etc/scripts/start.sh &> /var/tmp/mix/start.log\r"
    expect -i $spawn_id -re {[$#]}
    send -i $spawn_id "tail -f /var/tmp/mix/start.log\n"
    expect -i $spawn_id "start_lynx.py finished"
    send -i $spawn_id "\003"
}

if {$RFlag == "y"} {
    set timeout 100
    send -i $spawn_id "sync;rm -rf /var/tmp/mix/*;ps -ef | grep lynx | awk '{print \$2}' |xargs -i sudo kill -9 {};sudo bash /mix/etc/scripts/start.sh &> /var/tmp/mix/start.log\r"
    expect -i $spawn_id -re {[$#]}
    send -i $spawn_id "tail -f /var/tmp/mix/start.log\n"
    expect -i $spawn_id "start_lynx.py finished"
    send -i $spawn_id "\003"
}


if {$RFlag == "Y"} {
    set timeout 100
    send -i $spawn_id "sync;rm -rf /var/tmp/mix/*;ps -ef | grep lynx | awk '{print \$2}' |xargs -i sudo kill -9 {};sudo bash /mix/etc/scripts/start.sh &> /var/tmp/mix/start.log\r"
    expect -i $spawn_id -re {[$#]}
    send -i $spawn_id "tail -f /var/tmp/mix/start.log\n"
    expect -i $spawn_id "start_lynx.py finished"
    send -i $spawn_id "\003"
}

send_user "\n------------- MIX文件同步完成✅ -------------\n"
interact