#!/bin/bash

LOG_FILE="./00000chognqi.txt"

# 确保日志文件存在并赋予权限
if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE"
    chmod 666 "$LOG_FILE"
fi

while true; do
    echo "$(date): Starting the script" | tee -a "$LOG_FILE"

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
    # 启动主程序，自动输入 N 跳过交互
    # 这里直接用管道传入，且用 tee 实时显示并追加关键输出到日志
    export PYTORCH_MPS_HIGH_WATERMARK_RATIO=0.0
    printf "N\n\n" | ./run_rl_swarm.sh 2>&1 | tee -a "$LOG_FILE"

    ###############################
    # 检查是否异常退出
    EXIT_CODE=${PIPESTATUS[1]}
    if [ $EXIT_CODE -ne 0 ]; then
        echo "$(date): run_rl_swarm.sh exited unexpectedly with code $EXIT_CODE" | tee -a "$LOG_FILE"
        sleep 20
        echo "$(date): Restarting run_rl_swarm.sh after cleanup" | tee -a "$LOG_FILE"
    else
        echo "$(date): run_rl_swarm.sh exited normally" | tee -a "$LOG_FILE"
        # 你可以在这里决定是否退出循环，比如 break
    fi

    # 休息1分钟后重启循环
    sleep 60
done
