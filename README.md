# My HTML Website

這是一個簡單的靜態 HTML 網站，可以透過 shell 腳本快速部署到 Linux 伺服器（支援 Ubuntu 和 Amazon Linux）。

## 前置條件
- 一台運行 Ubuntu 或 Amazon Linux 的伺服器（例如 AWS EC2）。
- 必須以 root 權限或使用 `sudo` 執行安裝腳本。
- 確保伺服器允許 HTTP（端口 80）流量。
- 確保端口 80 未被其他程式佔用（例如 Nginx）。
- 確保無其他 APT 進程運行（例如自動更新）。

## 安裝步驟
1. 下載安裝腳本：
   ```bash
   wget https://raw.githubusercontent.com/Ai-test001/test/main/install.sh
