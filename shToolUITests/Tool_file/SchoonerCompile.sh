#!/bin/bash
echo -e '\033[;32;1m'
echo "Schooner Compiler"
echo "*********************start************************"
echo -e "\033[0m"
func_kill_process_if_exist(){
	process_name=$1
	process_id=`ps -ef | grep $process_name | grep -v grep` 
	if [[ ${#process_id} != 0 ]]; then
		echo "[杀进程] ${process_name}"
		killall $process_name
	fi
}

func_backup_dir_if_exist(){
	dir_path=$1

	if [[ ! -e $dir_path ]]; then
		echo "[备  份] 文件不存在，跳过：$dir_path"
		return 0
	fi

	base_name=`basename $dir_path`
	dir_name=`dirname $dir_path`
	bakup_dir="${dir_name}/${base_name}_Backup"
	date_str=`date "+%Y%m%d%H%M%S"`
	target_dir="${bakup_dir}/${base_name}"

	echo "[备  份] 目录：$dir_path"
	if [[ ! -e $bakup_dir ]]; then
		echo "[创  建] 备份目录：$bakup_dir"
		mkdir $bakup_dir
	fi
	echo "[移  动] 目录：$dir_path -> $target_dir"
	mv $dir_path $target_dir
	echo "[切  换] 目录：${bakup_dir}"
	cd ${bakup_dir}
	echo "[压  缩] 目录：${base_name} -> ${base_name}_${date_str}.zip"
	zip -q -r "${base_name}_${date_str}.zip" ${base_name}
	# echo "[删  除] 目录：${base_name}"
	# rm -rf ${base_name}
	echo "[移  动] 目录：$target_dir -> $dir_path"
	mv $target_dir $dir_path
}

func_dir_exist(){
	dir=$1
	if [[ -e $dir ]]; then
		return 0
	else
		return 1
	fi
}

func_remove_file_if_exist(){
	file_path=$1
	if [[ -d $file_path ]]; then
		if [[ -e $file_path ]]; then
			echo "[删  除] 目录：$file_path"
			rm -rf $file_path
		fi
	else
		if [[ -e $file_path ]]; then
			echo "[删  除] 文件：$file_path"
			rm -f $file_path
		fi
	fi
	
}

THIS_FILE=`basename "$0"`

# 当前路径
SHELL_FOLDER=$(cd "$(dirname "$0")";pwd)
# Atlas2代码路径
ATLAS2_FOLDER="${HOME}/Library/Atlas2"
LIB_ATLAS2_FOLDER=${ATLAS2_FOLDER}

# 备份Atlas2
func_backup_dir_if_exist ${ATLAS2_FOLDER}


#生成Schooner Coverage
PATH_COMPILER="${LIB_ATLAS2_FOLDER}/Modules/Schooner/Compiler/BuildSchoonerSequence.lua"
PATH_TO_MAIN_CSV="${LIB_ATLAS2_FOLDER}/Assets/InputTables/MainTable.csv"
PATH_TO_LIMIT_CSV="${LIB_ATLAS2_FOLDER}/Assets/InputTables/LimitsTable.csv"
PATH_TO_CONDITION_CSV="${LIB_ATLAS2_FOLDER}/Assets/InputTables/ConditionTable.csv"
PATH_TO_TEST_DEF_FOLDER="${LIB_ATLAS2_FOLDER}/Assets/TestDefinitions"
OUTPUT_FILE="${LIB_ATLAS2_FOLDER}/Modules/coverage/coverage.lua"
STATION_PLIST="${LIB_ATLAS2_FOLDER}/Config/station.plist"
func_remove_file_if_exist ${OUTPUT_FILE}
mkdir -p "${LIB_ATLAS2_FOLDER}/Modules/coverage"
echo "[编  译] AtlasLua ${PATH_COMPILER} -m ${PATH_TO_MAIN_CSV} -l ${PATH_TO_LIMIT_CSV} -c ${PATH_TO_CONDITION_CSV} -t ${PATH_TO_TEST_DEF_FOLDER} -o ${OUTPUT_FILE} -p ${STATION_PLIST}"
if [[ -f ${PATH_TO_CONDITION_CSV} ]]; then
	AtlasLua ${PATH_COMPILER} -m ${PATH_TO_MAIN_CSV} -l ${PATH_TO_LIMIT_CSV} -c ${PATH_TO_CONDITION_CSV} -t ${PATH_TO_TEST_DEF_FOLDER} -o ${OUTPUT_FILE} -p ${STATION_PLIST}
else
	AtlasLua ${PATH_COMPILER} -m ${PATH_TO_MAIN_CSV} -l ${PATH_TO_LIMIT_CSV} -t ${PATH_TO_TEST_DEF_FOLDER} -o ${OUTPUT_FILE} -p ${STATION_PLIST}
fi

# Schooner结束

# #加密Atlas2
# func_sign_atlas2 ${PLIST_FILE} ${LIB_ATLAS2_FOLDER}

echo -e '\033[;32;1m'
echo "*********************finish************************"
echo -e "\033[0m"
# sleep 10
# osascript -e 'tell application "Terminal" to close (every window whose name contains "'"$THIS_FILE"'")' &
# exit
