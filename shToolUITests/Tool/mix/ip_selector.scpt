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

-- 主逻辑
on run
    -- 不同项目不同的IP列表
    set baseIP to "111.111.111."
    set startIP to 32
    set ipList to {}
    repeat with i from 0 to 7
        set end of ipList to baseIP & (startIP + i) as string
    end repeat

    -- set baseIP to "169.254.1."
    -- set startIP to 32
    -- set ipList to {}
    -- repeat with i from 1 to 24
    --     set end of ipList to baseIP & (startIP + i) as string
    -- end repeat

    -- 选择IP（原生列表选择器）
    tell application "System Events"
        activate
        set selectedIPs to choose from list ipList ¬
            with prompt "选择IP（按住Command多选）：" ¬
            with multiple selections allowed ¬
            OK button name "确定" ¬
            cancel button name "取消"
    end tell

    -- 输出结果（逗号分隔）
    if selectedIPs is false then return ""
    set AppleScript's text item delimiters to ","
    set output to selectedIPs as string
    set AppleScript's text item delimiters to ""
    return output
end run