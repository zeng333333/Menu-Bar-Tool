#!/bin/bash
# ==============================================================================
# 脚本名称: get_file_paths.sh
# 功能描述: 提供可视化UI获取文件路径，支持多文件路径输入（空格分隔），返回标准化的路径数组
# 创建时间: 2025-12-22
# 作者: 
# 版本: v1.0
# 依赖环境: macOS (依赖osascript实现UI交互)
# ==============================================================================

# ------------------------------------------------------------------------------
# 函数名称: get_selected_file_paths
# 函数介绍: 弹出macOS原生对话框，让用户输入/拖拽文件路径，支持多路径（空格分隔）
# 创建时间: 2025-12-22
# 参数说明: 无入参
# 返回值说明: 
#   - 成功: 返回0，全局变量 FILE_ARRAY 存储标准化的文件路径数组（元素为单个文件绝对路径）
#   - 失败: 返回1，用户取消输入/未输入有效路径（弹窗提示错误）
# 注意事项: 
#   1. 多路径需用空格分隔，路径含空格时拖拽输入会自动加引号，手动输入需自行加引号
#   2. 返回的路径会自动清理首尾空格，中间多空格合并为单个分隔符
# ------------------------------------------------------------------------------
function get_selected_file_paths() {
    # 初始化全局数组（避免残留值）
    unset FILE_ARRAY
    local raw_file_paths  # 局部变量：存储用户原始输入
    
    # ========== 步骤1: 弹出UI对话框获取用户输入 ==========
    raw_file_paths=$(osascript -e '
        try
            set userInput to text returned of (display dialog ¬
                "请输入/拖拽文件路径：
                提示：多文件路径用【空格】分隔，含空格的路径请保留引号" ¬
                with title "获取文件路径信息" ¬
                default answer "" ¬
                buttons {"取消", "确认"} ¬
                default button "确认")
            return userInput
        on error  # 用户点击"取消"时触发
            return ""
        end try
    ')
    
    # ========== 步骤2: 标准化路径（清理空格） ==========
    local normalized_paths
    normalized_paths=$(echo "$raw_file_paths" | xargs)  # 清理首尾空格+合并中间多空格
    
    # ========== 步骤3: 空值校验 ==========
    if [ -z "$normalized_paths" ]; then
        osascript -e 'display alert "错误" message "未输入有效文件路径！
        请重新输入或拖拽文件后确认。" as critical'
        return 1  # 失败返回码
    fi
    
    # ========== 步骤4: 转换为路径数组（全局变量） ==========
    IFS=' ' read -r -a FILE_ARRAY <<< "$normalized_paths"
    
    # ========== 步骤5: 输出统计信息（可选，便于调试） ==========
    echo -e "\n===== 文件路径选择结果 ====="
    echo "共选择 ${#FILE_ARRAY[@]} 个文件/文件夹："
    for i in "${!FILE_ARRAY[@]}"; do
        echo "[$((i+1))] ${FILE_ARRAY[$i]}"
    done
    echo "============================\n"
    
    return 0  # 成功返回码
}

# ==============================================================================
# 主程序入口（示例调用）
# ==============================================================================
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # 调用函数获取文件路径
    if get_selected_file_paths; then
        # 函数执行成功：可在此处添加后续业务逻辑
        echo "✅ 路径获取成功，可开始处理文件..."
        dir_name=`dirname "$0"`
        echo $dir_name
        cmd="sh ${dir_name}/Common.sh"
        osascript -e "tell app \"Terminal\" to do script \"${cmd}\""
        # 示例：遍历路径做后续操作
        for path in "${FILE_ARRAY[@]}"; do
            echo "待处理路径：$path"
            # 此处可添加压缩/复制/删除等业务逻辑
        done
    else
        # 函数执行失败：退出脚本
        echo "❌ 路径获取失败，脚本退出"
        exit 1
    fi
fi