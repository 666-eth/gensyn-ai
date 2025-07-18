#!/bin/bash

LOG_FILE="./00000chognqi.txt"
TMP_LOG="./.tmp_rl_log.txt"

# 确保日志文件存在并赋予权限
if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE"
    chmod 666 "$LOG_FILE"
fi

while true; do
    echo "$(date): 🔄 Starting the script" | tee -a "$LOG_FILE"

    ###############################
    # 清理 next-server 进程
    NEXT_SERVER_PIDS=$(ps aux | grep '[n]ext-server' | awk '{print $2}')
    if [ -z "$NEXT_SERVER_PIDS" ]; then
        echo "$(date): No next-server process found." | tee -a "$LOG_FILE"
    else
        for PID in $NEXT_SERVER_PIDS; do
            echo "$(date): Found next-server with PID $PID. Attempting to kill..." | tee -a "$LOG_FILE"
            sudo kill -9 "$PID"
            sleep 1
            if ps -p "$PID" > /dev/null 2>&1; then
                echo "$(date): ❌ Failed to kill PID $PID" | tee -a "$LOG_FILE"
            else
                echo "$(date): ✅ Successfully killed PID $PID" | tee -a "$LOG_FILE"
            fi
        done
    fi

    ###############################
    # 清理监听端口 3000 的进程
    PORT_3000_PIDS=$(lsof -ti :3000)
    if [ -z "$PORT_3000_PIDS" ]; then
        echo "$(date): No process found listening on port 3000." | tee -a "$LOG_FILE"
    else
        for PID in $PORT_3000_PIDS; do
            echo "$(date): Found process on port 3000 with PID $PID. Attempting to kill..." | tee -a "$LOG_FILE"
            sudo kill -9 "$PID"
            sleep 1
            if ps -p "$PID" > /dev/null 2>&1; then
                echo "$(date): ❌ Failed to kill port 3000 PID $PID" | tee -a "$LOG_FILE"
            else
                echo "$(date): ✅ Successfully killed port 3000 PID $PID" | tee -a "$LOG_FILE"
            fi
        done
    fi

    ###############################
    # 启动主程序，自动输入 N 跳过交互，并捕获日志
    export PYTORCH_MPS_HIGH_WATERMARK_RATIO=0.0

    # 清空临时日志文件
    rm -f "$TMP_LOG"

    # 运行主程序并记录输出
    printf "N\n\n" | ./run_rl_swarm.sh 2>&1 | tee "$TMP_LOG" | tee -a "$LOG_FILE"

    # 获取退出码
    EXIT_CODE=${PIPESTATUS[1]}

    ###############################
    # 检查异常日志关键词
    ERROR_FOUND=false
    if grep -Ei "Traceback|exception|RuntimeError|Segmentation fault|Killed|wandb: Run history:" "$TMP_LOG" > /dev/null; then
        ERROR_FOUND=true
    fi

    if [[ $EXIT_CODE -ne 0 || "$ERROR_FOUND" == "true" ]]; then
        echo "$(date): ❌ Detected crash or error (code: $EXIT_CODE), restarting..." | tee -a "$LOG_FILE"
        sleep 20
    else
        echo "$(date): ✅ run_rl_swarm.sh exited normally. Exiting loop." | tee -a "$LOG_FILE"
        break  # 你可以改成 continue，如果想一直循环
    fi

    sleep 60
done
