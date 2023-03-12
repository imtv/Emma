#!/bin/bash

blue(){
    echo -e "\033[34m\033[01m$1\033[0m"
}
green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}
red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}
yellow(){
    echo -e "\033[33m\033[01m$1\033[0m"
}

logcmd(){
    eval $1 | tee -ai /var/atrandys.log
}

check_domain(){
    if [ "$1" == "tcp_xtls" ]; then
        config_type="tcp_xtls"
    fi
    if [ "$1" == "tcp_tls" ]; then
        config_type="tcp_tls"
    fi
    if [ "$1" == "ws_tls" ]; then
        config_type="ws_tls"
    fi
    $systemPackage install -y wget curl unzip
    blue "输入当前服务器的IP地址:"
    read your_domain
    blue "输入流媒体解锁服务器SOCKS的IP:"
    read stream_IP
    blue "端口:"
    read stream_port
    blue "用户名:"
    read stream_id
    blue "密码:"
    read stream_password
}

install_xray(){ 
    green "$(date +"%Y-%m-%d %H:%M:%S") ==== 安装xray"
    mkdir /usr/local/etc/xray/
    bash <(curl -L https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)
    cd /usr/local/etc/xray/
    rm -f config.json
    v2uuid=$(cat /proc/sys/kernel/random/uuid)
}

config_tcp_xtls(){
cat > /usr/local/etc/xray/tcp_xtls_config.json<<-EOF
{
    "log": {
        "loglevel": "warning"
    }, 
    "dns": {
        "servers": [
            "https+local://dns.adguard.com/dns-query"
        ],
        "queryStrategy": "UseIPv4"
    },
    "inbounds": [
        {
            "listen": "0.0.0.0", 
            "port": 443, 
            "protocol": "vless", 
            "settings": {
                "clients": [
                    {
                        "id": "$v2uuid", 
                        "level": 0, 
                        "email": "a@b.com",
                        "flow":"xtls-rprx-direct"
                    }
                ], 
                "decryption": "none", 
                "fallbacks": [
                    {
                        "dest": 37212
                    }, 
                    {
                        "alpn": "h2", 
                        "dest": 37213
                    }
                ]
            }, 
        "sniffing": { 
            "destOverride": [
                "http",
                "tls"
            ],
            "enabled": true
        },
            "streamSettings": {
                "network": "tcp", 
                "security": "xtls", 
                "xtlsSettings": {
                    "serverName": "$your_domain", 
                    "alpn": [
                        "h2", 
                        "http/1.1"
                    ], 
                    "certificates": [
                        {
                            "certificateFile": "/usr/local/etc/xray/cert/fullchain.cer", 
                            "keyFile": "/usr/local/etc/xray/cert/private.key"
                        }
                    ]
                }
            }
        }
    ], 
    "outbounds": [
        {
            "protocol": "freedom", 
            "settings": { }
        },
    {
      "tag": "hhsg",
      "protocol": "socks",
      "settings": {"servers": [{"address": "${stream_IP}","port": ${stream_port},"users": [{"user": "${stream_id}","pass": "${stream_password}"}]}]}
    },
    {
      "tag": "mmtw",
      "protocol": "socks",
      "settings": {"servers": [{"address": "${stream_IP}","port": ${stream_port},"users": [{"user": "${stream_id}","pass": "${stream_password}"}]}]}
    },
        {
            "protocol": "blackhole",
            "settings": {
                "response": {
                    "type": "http"
                }
            },
            "tag": "block"
        }
    ],
    "routing": { 
        "domainStrategy": "IPIfNonMatch",
        "rules": [
            {
                "type": "field",
                "domain": ["geosite:netflix","tudum.com","geosite:disney","geosite:hbo","geosite:primevideo"],
                "outboundTag": "hhsg"
            },
            {
                "type": "field",
                "domain": ["catchplay.com.tw","catchplay.com","cloudfront.net","akamaized.net","services.googleapis.cn","xn--ngstr-lra8j.com"],
                "outboundTag": "mmtw"
            },
            {
                "type": "field",
                "domain": [
                    "geosite:category-ads-all",
                    "geosite:cn"
                ],
                "outboundTag": "block"
            },
            {
                "type": "field",
                "ip": [
                    "geoip:cn",
                    "geoip:private"
                ],
                "outboundTag": "block"
            }
        ]
    }
}
EOF
}

config_tcp_tls(){
cat > /usr/local/etc/xray/tcp_tls_config.json<<-EOF
{
    "log": {
        "loglevel": "warning"
    }, 
    "dns": {
        "servers": [
            "https+local://dns.adguard.com/dns-query"
        ],
        "queryStrategy": "UseIPv4"
    },
    "inbounds": [
        {
            "listen": "0.0.0.0", 
            "port": 443, 
            "protocol": "vless", 
            "settings": {
                "clients": [
                    {
                        "id": "$v2uuid", 
                        "flow":"xtls-rprx-vision"
                    }
                ], 
                "decryption": "none", 
                "fallbacks": [
                    {
                        "dest": 37212
                    }, 
                    {
                        "alpn": "h2", 
                        "dest": 37213
                    }
                ]
            }, 
        "sniffing": { 
            "destOverride": [
                "http",
                "tls"
            ],
            "enabled": true
        },
            "streamSettings": {
                "network": "tcp", 
                "security": "tls", 
                "tlsSettings": {
                    "certificates": [
                        {
                            "certificateFile": "/usr/local/etc/xray/cert/fullchain.cer", 
                            "keyFile": "/usr/local/etc/xray/cert/private.key"
                        }
                    ]
                }
            }
        }
    ], 
    "outbounds": [
        {
            "protocol": "freedom", 
            "settings": { }
        },
    {
      "tag": "hhsg",
      "protocol": "socks",
      "settings": {"servers": [{"address": "${stream_IP}","port": ${stream_port},"users": [{"user": "${stream_id}","pass": "${stream_password}"}]}]}
    },
    {
      "tag": "mmtw",
      "protocol": "socks",
      "settings": {"servers": [{"address": "${stream_IP}","port": ${stream_port},"users": [{"user": "${stream_id}","pass": "${stream_password}"}]}]}
    },
        {
            "protocol": "blackhole",
            "settings": {
                "response": {
                    "type": "http"
                }
            },
            "tag": "block"
        }
    ],
    "routing": { 
        "domainStrategy": "IPIfNonMatch",
        "rules": [
            {
                "type": "field",
                "domain": ["geosite:netflix","tudum.com","geosite:disney","geosite:hbo","geosite:primevideo"],
                "outboundTag": "hhsg"
            },
            {
                "type": "field",
                "domain": ["catchplay.com.tw","catchplay.com","cloudfront.net","akamaized.net","services.googleapis.cn","xn--ngstr-lra8j.com"],
                "outboundTag": "mmtw"
            },
            {
                "type": "field",
                "domain": [
                    "geosite:category-ads-all",
                    "geosite:cn"
                ],
                "outboundTag": "block"
            },
            {
                "type": "field",
                "ip": [
                    "geoip:cn",
                    "geoip:private"
                ],
                "outboundTag": "block"
            }
        ]
    }
}
EOF
}

config_ws_tls(){
cat > /usr/local/etc/xray/ws_tls_config.json<<-EOF
{
  "log": {
    "loglevel": "warning"
  },
    "dns": {
        "servers": [
            "https+local://dns.adguard.com/dns-query"
        ],
        "queryStrategy": "UseIPv4"
    },
  "inbounds": [
    {
      "port": 2002,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$v2uuid"
          }
        ],
        "decryption": "none"
      },
        "sniffing": { 
            "destOverride": [
                "http",
                "tls"
            ],
            "enabled": true
        },
      "streamSettings": {
        "network": "grpc",
        "grpcSettings": {
          "serviceName": "$your_domain"
        }
      }
    }
  ],
    "outbounds": [
        {
            "protocol": "freedom", 
            "settings": { }
        },
    {
      "tag": "hhsg",
      "protocol": "socks",
      "settings": {"servers": [{"address": "${stream_IP}","port": ${stream_port},"users": [{"user": "${stream_id}","pass": "${stream_password}"}]}]}
    },
    {
      "tag": "mmtw",
      "protocol": "socks",
      "settings": {"servers": [{"address": "${stream_IP}","port": ${stream_port},"users": [{"user": "${stream_id}","pass": "${stream_password}"}]}]}
    },
        {
            "protocol": "blackhole",
            "settings": {
                "response": {
                    "type": "http"
                }
            },
            "tag": "block"
        }
    ],
    "routing": { 
        "domainStrategy": "IPIfNonMatch",
        "rules": [
            {
                "type": "field",
                "domain": ["geosite:netflix","tudum.com","geosite:disney","geosite:hbo","geosite:primevideo"],
                "outboundTag": "hhsg"
            },
            {
                "type": "field",
                "domain": ["catchplay.com.tw","catchplay.com","cloudfront.net","akamaized.net","services.googleapis.cn","xn--ngstr-lra8j.com"],
                "outboundTag": "mmtw"
            },
            {
                "type": "field",
                "domain": [
                    "geosite:category-ads-all",
                    "geosite:cn"
                ],
                "outboundTag": "block"
            },
            {
                "type": "field",
                "ip": [
                    "geoip:cn",
                    "geoip:private"
                ],
                "outboundTag": "block"
            }
        ]
    }
}
EOF
}

remove_xray(){
    green "$(date +"%Y-%m-%d %H:%M:%S") - 删除xray."
    systemctl stop xray.service
    systemctl disable xray.service
    rm -rf /usr/local/share/xray/ /usr/local/etc/xray/
    rm -f /usr/local/bin/xray
    rm -rf /etc/systemd/system/xray*
    green "xray has been deleted."
}

function start_menu(){
    clear
    green "======================================================="
    echo -e "\033[34m\033[01mXRAY-REALITY安装脚本20230312\033[0m"
    green "======================================================="
    echo
    green " 1. 安装 xray: vless+tcp+xtls/VLESS-TCP-XTLS-uTLS-REALITY"
    green " 2. 安装 xray: vless+tcp+xtls-Vision/VLESS-H2-uTLS-REALITY"
    green " 3. 安装 xray: vless+grpc+tls/VLESS-GRPC-uTLS-REALITY"
    echo
    green " 4. 更新 xray"
    red " 5. 删除 xray"
    yellow " 0. Exit"
    echo
    read -p "输入数字:" num
    case "$num" in
    1)
    check_domain "tcp_xtls"
    ;;
    2)
    check_domain "tcp_tls"
    ;;
    3)
    check_domain "ws_tls"
    ;;
    4)
    bash <(curl -L https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)
    systemctl restart xray
    ;;
    5)
    remove_xray 
    ;;
    0)
    exit 1
    ;;
    *)
    clear
    red "请输入正确的数字"
    sleep 2s
    start_menu
    ;;
    esac
}

start_menu
