-- Created at: 12/12/2025
-- Author: Jingxin Zeng (cn33331@163.com)

-- 辅助函数：去除空格
on trim(str)
    repeat while str starts with space
        set str to text 2 thru end of str
    end repeat
    repeat while str ends with space
        set str to text 1 thru -2 of str
    end repeat
    return str
end trim

on genIPRange(baseStr, startNum, countNum, versionTag)
    local lst, ipStr
    set lst to {}
    repeat with i from 0 to countNum - 1
        set ipStr to (baseStr & (startNum + i) & "-" & versionTag) as string
        set end of lst to ipStr
    end repeat
    return lst
end genIPRange

-- 主逻辑
on run
    -- 不同项目不同的IP列表（后缀标识 mix7/mix8，决定账号密码与重启命令）
    set ipList1 to genIPRange("192.168.99.", 32, 4, "mix8")
    set ipList2 to genIPRange("169.254.1.", 32, 4, "mix8")
    set ipList3 to genIPRange("192.168.99.", 47, 1, "mix8")
    set ipList to ipList1 & ipList2 & ipList3

    -- 选择IP（原生列表选择器）
    tell application "System Events"
        activate
        set selectedIPs to choose from list ipList with prompt "选择IP（按住Command多选）：" with multiple selections allowed OK button name "确定" cancel button name "取消"
    end tell

    -- 输出结果（逗号分隔）
    if selectedIPs is false then return ""
    set AppleScript's text item delimiters to ","
    set output to selectedIPs as string
    set AppleScript's text item delimiters to ""
    return output
end run
