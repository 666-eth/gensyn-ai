#!/bin/bash

LOG_FILE="/root/rl-swarm/monitor.log"
WORKSPACE="/root/rl-swarm"
cd "$WORKSPACE"
export PYTORCH_MPS_HIGH_WATERMARK_RATIO=0.0
source .venv/bin/activate

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

clear_program_logs() {
    log "清空主程序日志文件"
    : > "$WORKSPACE/rl_swarm_output.log"
}

show_recent_logs() {
    local now=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$now] 最新3条程序日志：" | tee -a "$LOG_FILE"
    tail -n 3 "$WORKSPACE/rl_swarm_output.log" 2>/dev/null || echo "暂无日志" | tee -a "$LOG_FILE"
    echo "[$now] ------------------------" | tee -a "$LOG_FILE"
}

stop_processes() {
    log "正在停止进程..."

    pkill -f "next dev" || true
    pkill -f "run_rl_swarm.sh" || true
    pkill -f "python" || true

    sleep 5

    if pgrep -f "next dev" > /dev/null || pgrep -f "run_rl_swarm.sh" > /dev/null || pgrep -f "python" > /dev/null; then
        log "部分进程未能终止，执行强制 kill -9"
        pkill -9 -f "next dev" || true
        pkill -9 -f "run_rl_swarm.sh" || true
        pkill -9 -f "python" || true
        sleep 2
    fi

    log "进程停止完成"
}

start_program() {
    log "正在启动RL-Swarm程序..."
    cd "$WORKSPACE"
    clear_program_logs
    log "自动提供输入参数..."

    nohup bash -c 'echo -e "N\n" | bash run_rl_swarm.sh' > "$WORKSPACE/rl_swarm_output.log" 2>&1 &

    sleep 150
    if check_processes; then
        log "RL-Swarm程序已成功启动"
        return 0
    else
        log "RL-Swarm程序启动失败"
        return 1
    fi
}

check_processes() {
    if tail -n 1 "$WORKSPACE/rl_swarm_output.log" 2>/dev/null | grep -Eq "^[0-9]+%\|█+\|\s*[0-9]+/[0-9]+\s\[[0-9]{2}:[0-9]{2}<[0-9]{2}:[0-9]{2},\s*[0-9.]+s/it\]$"; then
        log "检测到进度条信息，程序运行正常"
        return 0
    else
        return 1
    fi
}

restart_program() {
    log "准备重启程序..."
    stop_processes
    start_program
    log "重启完成"
}

check_for_errors() {
    if grep -q "BlockingIOError: \[Errno 11\] Resource temporarily unavailable" "$WORKSPACE/rl_swarm_output.log" 2>/dev/null; then
        log "检测到 BlockingIOError 错误，需要立即重启"
        clear_program_logs
        return 1
    fi

    if grep -q "EOFError: Ran out of input" "$WORKSPACE/rl_swarm_output.log" 2>/dev/null; then
        log "检测到 EOFError 错误，需要立即重启"
        clear_program_logs
        return 1
    fi

    if grep -q "hydra.errors.InstantiationException" "$WORKSPACE/rl_swarm_output.log" 2>/dev/null && \
       grep -q "P2PDaemonError('Daemon failed to start" "$WORKSPACE/rl_swarm_output.log" 2>/dev/null; then
        log "检测到 P2PDaemon 启动失败（Hydra InstantiationException），需要立即重启"
        clear_program_logs
        return 1
    fi

    if grep -q "An error was detected while running rl-swarm" "$WORKSPACE/rl_swarm_output.log" 2>/dev/null && \
       grep -q "Shutting down trainer..." "$WORKSPACE/rl_swarm_output.log" 2>/dev/null; then
        log "检测到 RL-Swarm 报错退出，准备重启"
        clear_program_logs
        return 1
    fi

    return 0
}

log "守护程序已启动，开始监控RL-Swarm进程"
clear_program_logs

(
    while true; do
        show_recent_logs
        sleep 15
    done
) &
LOGS_DISPLAY_PID=$!

restart_on_signal() {
    log "收到重启信号"
    clear_program_logs
    restart_program
}
trap restart_on_signal USR1

cleanup_monitoring() {
    log "清理监控进程"
    kill $LOGS_DISPLAY_PID 2>/dev/null || true
    exit 0
}
trap cleanup_monitoring EXIT

while true; do
    if ! check_processes; then
        log "检测到进程异常，准备重启"
        restart_program
    elif ! check_for_errors; then
        log "进程运行中，但检测到错误，准备重启"
        restart_program
    else
        log "进程运行正常"
    fi
    sleep 180
done
