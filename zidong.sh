#!/bin/bash

LOG_FILE="./00000chognqi.txt"
RL_LOG="/root/rl-swarm/logs/latest.log"

# 创建日志文件
if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE"
    chmod 666 "$LOG_FILE"
fi

while true; do
    echo "$(date): ⏳ Starting RL-Swarm..." >> "$LOG_FILE"

    ######################
    # 清理 next-server
    NEXT_SERVER_PIDS=$(pgrep -f 'next-server')
    for PID in $NEXT_SERVER_PIDS; do
        echo "$(date): 🔪 Killing next-server PID $PID" >> "$LOG_FILE"
        kill -9 "$PID" 2>/dev/null
    done

    ######################
    # 清理端口 3000 占用
    PORT_3000_PIDS=$(lsof -ti :3000)
    for PID in $PORT_3000_PIDS; do
        echo "$(date): 🔪 Killing port 3000 PID $PID" >> "$LOG_FILE"
        kill -9 "$PID" 2>/dev/null
    done

    ######################
    # 启动主程序并输入 "N"
    export PYTORCH_MPS_HIGH_WATERMARK_RATIO=0.0
    printf "N\n\n" | ./run_rl_swarm.sh >> "$LOG_FILE" 2>&1

    ######################
    # 检查退出状态
    EXIT_CODE=$?
    echo "$(date): 🧪 run_rl_swarm.sh exited with code $EXIT_CODE" >> "$LOG_FILE"

    RESTART_REASON=""
    if [ $EXIT_CODE -ne 0 ]; then
        RESTART_REASON="非零退出码 $EXIT_CODE"
    elif grep -qE "P2PDaemonError|Daemon failed|EOFError|BlockingIOError" "$RL_LOG"; then
        RESTART_REASON="检测到关键错误日志"
    fi

    if [ -n "$RESTART_REASON" ]; then
        echo "$(date): ❗触发重启原因：$RESTART_REASON" >> "$LOG_FILE"

        ######################
        # 清理 again
        NEXT_SERVER_PIDS=$(pgrep -f 'next-server')
        for PID in $NEXT_SERVER_PIDS; do
            echo "$(date): 🔪 再次杀 next-server PID $PID" >> "$LOG_FILE"
            kill -9 "$PID" 2>/dev/null
        done

        PORT_3000_PIDS=$(lsof -ti :3000)
        for PID in $PORT_3000_PIDS; do
            echo "$(date): 🔪 再次杀 port 3000 PID $PID" >> "$LOG_FILE"
            kill -9 "$PID" 2>/dev/null
        done

        echo "$(date): 🔁 Waiting before restart..." >> "$LOG_FILE"
        sleep 20
        echo "$(date): ✅ Restarting run_rl_swarm.sh" >> "$LOG_FILE"
    fi

    sleep 60
done
