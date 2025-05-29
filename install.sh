#!/bin/bash

# 設置錯誤處理：任何命令失敗時退出
set -e

# 定義日誌檔案
LOG_FILE="/var/log/install_html.log"

# 函數：記錄訊息到日誌檔案和終端
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# 檢查是否以 root 權限運行
if [ "$EUID" -ne 0 ]; then
    log "請以 root 權限運行此腳本（例如使用 sudo）"
    exit 1
fi

# 檢查並釋放端口 80
log "檢查端口 80 是否被佔用..."
if ss -tulnp | grep ':80' > /dev/null; then
    log "端口 80 已被佔用，嘗試終止相關進程..."
    systemctl stop nginx apache2 >/dev/null 2>&1
    PIDS=$(lsof -t -i:80 || true)
    if [ -n "$PIDS" ]; then
        for pid in $PIDS; do
            log "終止進程 PID: $pid"
            kill -9 $pid
        done
    fi
    sleep 2
    if ss -tulnp | grep ':80' > /dev/null; then
        log "錯誤：無法釋放端口 80，請手動檢查（sudo ss -tulnp | grep :80）"
        exit 1
    fi
fi

# 檢查 APT 鎖並清理
log "檢查 APT 鎖..."
if [ -f /var/lib/apt/lists/lock ] || [ -f /var/cache/apt/archives/lock ] || [ -f /var/lib/dpkg/lock-frontend ]; then
    log "檢測到 APT 鎖，嘗試清理..."
    rm -f /var/lib/apt/lists/lock /var/cache/apt/archives/lock /var/lib/dpkg/lock-frontend
    dpkg --configure -a
fi

# 更新套件列表並安裝 Apache
log "更新套件列表並安裝 Apache..."
apt update -y
if ! command -v apache2 >/dev/null 2>&1; then
    log "Apache 未安裝，正在安裝..."
    apt install apache2 -y
else
    log "Apache 已安裝，跳過安裝"
fi

# 啟動並啟用 Apache
log "啟動並啟用 Apache 服務..."
systemctl start apache2
systemctl enable apache2

# 檢查 Apache 狀態
log "檢查 Apache 運行狀態..."
if systemctl is-active --quiet apache2; then
    log "Apache 運行正常！"
else
    log "Apache 啟動失敗，請檢查日誌：/var/log/apache2/error.log"
    exit 1
fi

# 部署 HTML 檔案到 Web 根目錄
log "部署 HTML 檔案到 /var/www/html..."
if [ -f "index.html" ]; then
    rm -rf /var/www/html/*
    cp index.html /var/www/html/
else
    log "錯誤：index.html 不存在於當前目錄，請檢查儲存庫內容"
    exit 1
fi

# 設置正確權限
log "設置檔案權限..."
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html

# 開放防火牆端口（如果使用 ufw）
log "配置防火牆以允許端口 80..."
ufw allow 80 >/dev/null 2>&1 || true

# 測試網站
log "測試網站是否可訪問..."
PUBLIC_IP=$(curl -s http://ifconfig.me || echo "localhost")
if curl -s -o /dev/null -w "%{http_code}" "http://$PUBLIC_IP" | grep -q "200"; then
    log "網站成功部署！請在瀏覽器訪問 http://$PUBLIC_IP"
else
    log "無法訪問網站，請檢查 Apache 日誌或網絡設置"
    exit 1
fi

log "安裝和部署完成！"
