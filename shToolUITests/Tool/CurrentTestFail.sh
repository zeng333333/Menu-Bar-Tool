#!/bin/bash
# Created at: 12/12/2025
# Author: Jingxin Zeng (cn33331@163.com)

# ===================== 配置参数 =====================
TOTAL_DURATION=9999999999999999999999999999999999999
INTERVAL=10
TARGET_PATH="${HOME}/Library/Logs/Atlas/active/group*/system/records.csv"
PATTERN=",FAIL,"
LOG_FILE="${HOME}/Desktop/fail_monitor.log"

# ===================== 工具函数 =====================
# 输出到终端+日志（支持换行对齐）
log_and_echo() {
    echo "$1"
    echo "$1" >> "${LOG_FILE}"
}

# 从CSV中提取SN（固定搜索前10行找PrimaryIdentity行，再取其第二列）
extract_sn_from_csv() {
    local csv_file="$1"
    if [[ ! -f "$csv_file" ]]; then
        echo "(文件不存在)"
        return
    fi
    # 固定搜索前10行找PrimaryIdentity
    primary_line=$(sed -n "1,10p" "$csv_file" | grep -n "^PrimaryIdentity," | head -1 | cut -d':' -f1)
    if [[ -n "$primary_line" ]]; then
        local primary_csv_line=$(sed -n "1,10p" "$csv_file" | sed -n "${primary_line}p" 2>/dev/null)
        local sn=$(echo "$primary_csv_line" | cut -d',' -f2 | sed -e 's/^[[:space:]]*$/(无SN)/' -e 's/^PrimaryIdentity$/(无SN)/')
        echo "$sn"
    else
        echo "(前10行未找到PrimaryIdentity行)"
    fi
}

# 提取文件路径中的group名称（兼容macOS bash 3.x）
extract_group() {
    local file_path="$1"
    echo "$file_path" | grep -oE "group[^/]*"
}

# ===================== 核心逻辑 =====================
START_TIME=$(date +%s)
END_TIME=$((START_TIME + TOTAL_DURATION))

# 初始化日志
log_and_echo "===== 监控启动 ====="
log_and_echo "启动时间：$(date +'%Y-%m-%d %H:%M:%S')"
log_and_echo "监控路径：${TARGET_PATH}"
log_and_echo "结束时间：$(date -r ${END_TIME} +'%Y-%m-%d %H:%M:%S')"
log_and_echo "==============================================="
log_and_echo ""

# 循环执行监控
while [[ $(date +%s) -lt ${END_TIME} ]]; do
    CURRENT_TIME=$(date +'%Y-%m-%d %H:%M:%S')

    # 初始化临时文件存储聚合数据（替代关联数组，兼容bash 3.x）
    AGG_TMP=$(mktemp)
    matched=0

    # 遍历所有CSV文件（兼容通配符）
    for csv_file in $(ls -1 ${TARGET_PATH} 2>/dev/null); do
        [[ ! -f "$csv_file" ]] && continue
        
        # 提取当前文件的Group名和SN
        group_name=$(extract_group "$csv_file")
        [[ -z "$group_name" ]] && group_name="未知Group"
        sn=$(extract_sn_from_csv "$csv_file")
        
        # 读取当前文件中所有FAIL记录
        fail_lines=$(grep -n "${PATTERN}" "$csv_file" 2>/dev/null)
        [[ -z "$fail_lines" ]] && continue
        matched=1

        # 解析每行FAIL记录，拼接行号+内容（用****分隔）
        line_info=""
        while read -r line; do
            [[ -z "$line" ]] && continue
            # 拆分行号和内容（bash 3.x兼容写法）
            line_num=$(echo "$line" | awk -F':' '{print $1}')
            content=$(echo "$line" | cut -d':' -f2- | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
            content=${content:-"(无具体内容)"}
            # 拼接行信息（每行前加空格对齐，替代分号）
            line_info+="    - ${line_num}: ${content}****"
        done <<< "$fail_lines"
        # 将当前Group的信息写入临时文件（格式：Group名|SN|文件路径|fail内容）
        echo "${group_name}|${sn}|${csv_file}|${line_info}" >> "${AGG_TMP}"
    done

    clear

    # 按Group聚合并输出结果
    if [[ $matched -eq 1 ]]; then
        log_and_echo "----- [${CURRENT_TIME}] 执行搜索 -----"
        # 去重获取所有Group名（bash 3.x兼容）
        groups=$(cut -d'|' -f1 "$AGG_TMP" | sort | uniq)
        for group in $groups; do
            # 提取当前Group的所有记录
            group_records=$(grep "^${group}|" "$AGG_TMP")
            # 取第一个记录的SN（同Group的SN一致）
            sn=$(echo "$group_records" | head -1 | cut -d'|' -f2)
            # 拼接当前Group的所有文件路径
            file_paths=$(echo "$group_records" | cut -d'|' -f3 | sort | uniq | tr '\n' ' ')
            # 拼接当前Group的所有fail
            all_line_info="$(echo "$group_records" | cut -d'|' -f4)"
            
            # 格式化输出聚合结果
            log_and_echo "✅ 匹配到FAIL记录（${group}）："
            log_and_echo "   → SN号：${sn}"
            log_and_echo "   → 文件路径：${file_paths}"
            log_and_echo "   → 行号+内容："
            IFS='****' read -r -a tab <<< "$all_line_info"
            for line in "${tab[@]}";do
                info="$(echo $line| tr '\n' ' ')"
                info1=$(echo "$info" | cut -d' ' -f1)
                # log_and_echo "$info1"
                if [[ $info1 ]]; then
                    log_and_echo "$info"
                fi
            done
            log_and_echo "----------------------------------------"
        done
    else
        echo "----- [${CURRENT_TIME}] 执行搜索 -----"
        echo "❌ 本次未匹配到 FAIL 记录"
        echo "----------------------------------------"
    fi

    # 删除临时文件
    rm -f "${AGG_TMP}"
    
    log_and_echo ""
    
    # 等待间隔
    NEXT_EXEC_TIME=$(( $(date +%s) + ${INTERVAL} ))
    if [[ ${NEXT_EXEC_TIME} -lt ${END_TIME} ]]; then
        sleep ${INTERVAL}
    else
        break
    fi
done

# 结束统计
log_and_echo "===== 监控结束 ====="
log_and_echo "实际运行时长：$(( $(date +%s) - START_TIME )) 秒"