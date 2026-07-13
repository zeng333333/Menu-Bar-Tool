import tkinter as tk
from tkinter import ttk
import subprocess
import os


def main():
    # 对应你原脚本IP规则
    base_ip = "111.111.111."
    start = 32
    ip_list = [f"{base_ip}{start+i}" for i in range(8)]

    root = tk.Tk()
    root.title("选择IP")
    root.geometry("250x230")
    # 窗口居中
    root.update()
    x = (root.winfo_screenwidth() - root.winfo_width()) // 2
    y = (root.winfo_screenheight() - root.winfo_height()) // 2
    root.geometry(f"+{x}+{y}")

    # 提示文字
    ttk.Label(root, text="选择IP（按住Command多选）", font=("", 12)).pack(pady=8)

    # 多选列表框
    listbox = tk.Listbox(root, selectmode=tk.MULTIPLE, width=40, height=8)
    for ip in ip_list:
        listbox.insert(tk.END, ip)
    listbox.pack(pady=5)

    # 存储结果
    result = []

    def confirm():
        nonlocal result
        sel = listbox.curselection()
        result = [listbox.get(i) for i in sel]
        root.destroy()

    def cancel():
        root.destroy()

    # 按钮行
    frame_btn = ttk.Frame(root)
    frame_btn.pack(pady=10)
    ttk.Button(frame_btn, text="确定", command=confirm).grid(row=0, column=0, padx=10)
    ttk.Button(frame_btn, text="取消", command=cancel).grid(row=0, column=1, padx=10)

    root.mainloop()

    # 输出逗号分隔IP到stdout，供shell捕获
    print(",".join(result))

if __name__ == "__main__":
    scpt_path = os.path.dirname(os.path.abspath(__file__))+"/ip_selector.scpt"
    result = subprocess.run(['osascript', scpt_path], capture_output=True, text=True)
    if result.stderr.find("error") != -1:
        main()
    else:
        print(result.stdout)