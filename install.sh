#!/bin/bash

# 檢查是否以 root 權限運行
if [ "$EUID" -ne 0 ]; then
  echo "請以 root 權限運行此腳本（例如使用 sudo）"
  exit 1
fi

# 檢查並釋放端口 80
if ss -tulnp | grep ':80' > /dev/null; then
  echo "端口 80 已被佔用，正在嘗試停止可能的 Nginx 服務..."
  systemctl stop nginx > /dev/null 2>&1
  systemctl disable nginx > /dev/null 2>&1
  if ss -tulnp | grep ':80' > /dev/null; then
    echo "錯誤：無法釋放端口 80，請手動檢查並終止佔用進程（例如：sudo ss -tulnp | grep :80）"
    exit 1
  fi
fi

# 檢查 APT 鎖
APT_LOCK_TIMEOUT=60
while [ -f /var/lib/apt/lists/lock ] || [ -f /var/cache/apt/archives/lock ] || [ -f /var/lib/dpkg/lock-frontend ]; do
  echo "等待 APT 鎖釋放（最多 $APT_LOCK_TIMEOUT 秒）..."
  sleep 5
  APT_LOCK_TIMEOUT=$((APT_LOCK_TIMEOUT - 5))
  if [ $APT_LOCK_TIMEOUT -le 0 ]; then
    echo "錯誤：無法釋放 APT 鎖，請檢查是否有其他 APT 進程（例如：ps aux | grep apt）"
    exit 1
  fi
done

# 檢查 unattended-upgrades 是否正在運行
if systemctl is-active --quiet unattended-upgrades; then
  echo "unattended-upgrades 正在運行，等待最多 60 秒..."
  UPGRADE_TIMEOUT=60
  while systemctl is-active --quiet unattended-upgrades; do
    sleep 5
    UPGRADE_TIMEOUT=$((UPGRADE_TIMEOUT - 5))
    if [ $UPGRADE_TIMEOUT -le 0 ]; then
      echo "錯誤：unattended-upgrades 未完成，請手動檢查（sudo systemctl status unattended-upgrades）"
      exit 1
    fi
  done
fi

# 檢測作業系統
if [ -f /etc/os-release ]; then
  . /etc/os-release
  OS=$ID
else
  echo "無法檢測作業系統"
  exit 1
fi

# 安裝 Web 伺服器和 Git
if [ "$OS" = "ubuntu" ]; then
  apt update -y
  apt install apache2 git -y
  systemctl start apache2
  systemctl enable apache2
  WEB_USER="www-data"
  WEB_DIR="/var/www/html"
elif [ "$OS" = "amzn" ]; then
  yum update -y
  yum install httpd git -y
  systemctl start httpd
  systemctl enable httpd
  WEB_USER="apache"
  WEB_DIR="/var/www/html"
else
  echo "不支援的作業系統：$OS"
  exit 1
fi

# 從 GitHub 下載 HTML 檔案
REPO_URL="https://github.com/Ai-test001/test.git"
TEMP_DIR="/tmp/my-html-website"
rm -rf "$TEMP_DIR"
git clone "$REPO_URL" "$TEMP_DIR"

# 複製檔案到 Web 伺服器目錄
rm -rf "$WEB_DIR"/*
cp -r "$TEMP_DIR"/* "$WEB_DIR"
rm -rf "$TEMP_DIR"

# 設置正確權限
chown -R "$WEB_USER":"$WEB_USER" "$WEB_DIR"
chmod -R 755 "$WEB_DIR"

# 檢查 Web 伺服器狀態
if systemctl is-active --quiet httpd || systemctl is-active --quiet apache2; then
  echo "網站已成功部署！請在瀏覽器中訪問 http://<你的伺服器IP>"
else
  echo "Web 伺服器啟動失敗，請檢查日誌（/var/log/apache2 或 /var/log/httpd）"
  exit 1
fi
