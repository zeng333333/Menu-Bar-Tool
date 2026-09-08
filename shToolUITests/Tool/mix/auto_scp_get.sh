#!/usr/bin/expect
# Created at: 12/12/2025
# Author: Jingxin Zeng (cn33331@163.com)

# 用法: auto_scp_get.sh <IP-version> <mix_path> <local_file>
# 示例: auto_scp_get.sh 192.168.99.32-mix8 /mix ~/Downloads/192.168.99.32_mix_code

set timeout 20

set IP_version   [ lindex $argv 0 ]
set mix_path     [ lindex $argv 1 ]
set local_file   [ lindex $argv 2 ]

# 解析IP和版本
set parts [split $IP_version "-"]
set IP      [lindex $parts 0]
set version [lindex $parts 1]

if {$version == "mix8"} {
    puts "mix8 mode"
    set user mixadmin
    set password mixadmin

    spawn scp -r $user@$IP:$mix_path $local_file
    expect {
    "*yes/no*?" {send "yes\n";exp_continue}
    "*mixadmin@*password*" {send "$password\n";exp_continue}
    }

    spawn sleep 0.5
    expect -re {[$%]}
} else {
    puts "mix7 mode"
    set user root
    set password 123456

    spawn scp -r $user@$IP:$mix_path $local_file
    expect {
    "*yes/no*?" {send "yes\n";exp_continue}
    "*root@*password*" {send "$password\n";exp_continue}
    }
    spawn sleep 0.5
    expect -re {[$%]}
}

exec open $local_file
send_user "\n完成✅ 获取MIX文件成功\n"
sleep 1
