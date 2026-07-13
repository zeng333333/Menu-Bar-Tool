#!/usr/bin/expect
# Created at: 12/12/2025
# Author: Jingxin Zeng (cn33331@163.com)

set timeout 20


set IP   [ lindex $argv 0 ]
set mix_path   [ lindex $argv 1 ]
set local_file   [ lindex $argv 2 ]
set index [string first "111" $IP]

if {$index == 0} {
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
    "*mixadmin@*password*" {send "$password\n";exp_continue}
    }
    spawn sleep 0.5
    expect -re {[$%]}
}

puts [exec open $local_file]
send_user "\n完成✅ 获取MIX文件成功\n"
sleep 1
