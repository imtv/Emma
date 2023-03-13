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
    if [ "$1" == "h2" ]; then
        config_type="h2"
    fi
    if [ "$1" == "grpc" ]; then
        config_type="grpc"
    fi
    apt install -y wget curl unzip
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
    install_xray
}

install_xray(){ 
    green "$(date +"%Y-%m-%d %H:%M:%S") ==== 安装xray"
    mkdir /usr/local/etc/xray/
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install --version 1.8.0 #临时
    #bash <(curl -L https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)
    cd /usr/local/etc/xray/
    rm -f config.json
    v2uuid=$(cat /proc/sys/kernel/random/uuid)
    config_tcp_xtls
    config_h2
    config_grpc
    if [ "$config_type" == "tcp_xtls" ]; then      
        change_2_tcp_xtls
    fi
    if [ "$config_type" == "h2" ]; then   
        change_2_h2
    fi
    if [ "$config_type" == "grpc" ]; then  
        change_2_grpc
    fi
    systemctl enable xray.service
    sed -i "s/User=nobody/User=root/;" /etc/systemd/system/xray.service
    systemctl daemon-reload
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
    },
    "policy": {
        "levels": {
            "0": {
                "handshake": 2,
                "connIdle": 120
            }
        }
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
                        "flow": "xtls-rprx-vision"
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "tcp",
                "security": "reality",
                "realitySettings": {
                    "show": false,
                    "dest": "www.lovelive-anime.jp:443",
                    "xver": 0,
                    "serverNames": [
                        "lovelive-anime.jp",
                        "www.lovelive-anime.jp"
                    ],
                    "privateKey": "sExZCeQDVSAfBSsjqxn3DicCbOSv5kmCUhurmIcLbnY",
                    "shortIds": [
                        "a1",
                        "bc19",
                        "b2da06",
                        "2d940fe6",
                        "b85e293fa1",
                        "4a9f72b5c803",
                        "19f70b462cea5d",
                        "6ba85179e30d4fc2"
                    ]
                }
            },
            "sniffing": {
                "enabled": true,
                "destOverride": [
                    "http",
                    "tls"
                ]
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "tag": "direct"
        },
        {
            "protocol": "blackhole",
            "tag": "block"
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
        }
    ]
}
EOF
}

change_2_tcp_xtls(){
    echo "tcp_xtls" > /usr/local/etc/xray/atrandys_config
    \cp /usr/local/etc/xray/tcp_xtls_config.json /usr/local/etc/xray/config.json
    #systemctl restart xray

}

config_h2(){
cat > /usr/local/etc/xray/h2_config.json<<-EOF
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

change_2_h2(){
    echo "h2" > /usr/local/etc/xray/atrandys_config
    \cp /usr/local/etc/xray/h2_config.json /usr/local/etc/xray/config.json
    #systemctl restart xray
}

config_grpc(){
cat > /usr/local/etc/xray/grpc_config.json<<-EOF
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

change_2_grpc(){
    echo "grpc" > /usr/local/etc/xray/atrandys_config
    \cp /usr/local/etc/xray/grpc_config.json /usr/local/etc/xray/config.json
    #systemctl restart xray
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
    echo -e "\033[34m\033[01mXRAY-REALITY安装脚本20230313-1\033[0m"
    green "======================================================="
    echo
    green " 1. 安装 xray: VLESS-TCP-XTLS-uTLS-REALITY"
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
    check_domain "h2"
    ;;
    3)
    check_domain "grpc"
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
