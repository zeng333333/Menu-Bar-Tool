#!/usr/bin/expect
# Created at: 12/12/2025
# Author: Jingxin Zeng (cn33331@163.com)

# 用法: chmod.sh <IP-version>
# 示例: chmod.sh 192.168.99.32-mix8

set timeout 1
set IP_version   [ lindex $argv 0 ]

# 解析IP和版本
set parts [split $IP_version "-"]
set IP      [lindex $parts 0]
set version [lindex $parts 1]

if {$version == "mix8"} {
    puts "mix8 mode"
    set user mixadmin
    set password mixadmin
    set  DIR    /mix
    spawn ssh $user@$IP
    expect {
    "*yes/no*?" {send "yes\n";exp_continue}
    "*mixadmin@*password*" {send "$password\n";exp_continue}
    }
    send "sudo -s \n";
    expect {
    "*mixadmin@*password*" {send "$password\n";exp_continue}
    "*password for mixadmin*" {send "$password\n";exp_continue}
    }
    set timeout 100
    send "sudo chmod -R 777 $DIR\n";
    expect -re {[$#]}
    interact
} else {
    puts "mix7 mode"
    set user root
    set password 123456
    set  DIR    /mix
    spawn ssh $user@$IP
    expect {
    "*yes/no*?" {send "yes\n";exp_continue}
    "*root@*password*" {send "$password\n";exp_continue}
    }
    send "sudo -s \n";
    expect {
    "*root@*password*" {send "$password\n";exp_continue}
    "*root for root*" {send "$password\n";exp_continue}
    }
    set timeout 100
    send "chmod -R 777 $DIR\n";
    expect -re {[$#]}
    interact
}
