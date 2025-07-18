#!/bin/bash

LOG_FILE="./00000chognqi.txt"
TMP_LOG="./.tmp_rl_log.txt"

###############################
# 清空日志文件
echo "$(date): 🔁 清理旧日志文件..."
rm -f "$LOG_FILE" "$TMP_LOG"
rm -f /root/'=0.1.20'
rm -f /root/rl_swarm_output.log
rm -f /root/monitor.log
rm -f "$LOG_FILE"
touch "$LOG_FILE"
chmod 666 "$LOG_FILE"

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
    # 启动主程序并捕获日志
    export PYTORCH_MPS_HIGH_WATERMARK_RATIO=0.0

    printf "N\n\n" | ./run_rl_swarm.sh 2>&1 | tee "$TMP_LOG" | tee -a "$LOG_FILE"

    # 获取退出码
    EXIT_CODE=${PIPESTATUS[1]}

    ###############################
    # 判断是否异常
    ERROR_FOUND=false

    # 关键字检测
    if grep -Ei "Traceback|exception|RuntimeError|Segmentation fault|Killed" "$TMP_LOG" > /dev/null; then
        ERROR_FOUND=true
    fi

    # 检查 wandb offline run 日志
    W_RUN=$(grep -oE 'offline-run-[0-9_]+-[a-z0-9]+' "$TMP_LOG" | tail -n 1)
    W_PATH="./logs/wandb/$W_RUN/logs"
    if [ -n "$W_RUN" ] && [ -d "$W_PATH" ]; then
        echo "$(date): 🚨 wandb offline log detected at $W_PATH — treating as crash." | tee -a "$LOG_FILE"
        ERROR_FOUND=true
    fi

    ###############################
    # 根据检测结果决定重启或退出
    if [[ $EXIT_CODE -ne 0 || "$ERROR_FOUND" == "true" ]]; then
        echo "$(date): ❌ Detected crash or error (exit code $EXIT_CODE), restarting in 20 seconds..." | tee -a "$LOG_FILE"
        sleep 20
    else
        echo "$(date): ✅ run_rl_swarm.sh exited normally. Exiting loop." | tee -a "$LOG_FILE"
        break
    fi

    sleep 60
done
