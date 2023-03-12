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

source /etc/os-release
RELEASE=$ID
VERSION=$VERSION_ID
cat >> /usr/src/atrandys.log <<-EOF
== Script: imtv/xray/install.sh
== Time  : $(date +"%Y-%m-%d %H:%M:%S")
== OS    : $RELEASE $VERSION
== Kernel: $(uname -r)
== User  : $(whoami)
EOF
sleep 2s
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
    blue "输入stream的IP:"
    read stream_IP
    blue "输入stream的端口:"
    read stream_port
    blue "输入stream的用户名:"
    read stream_id
    blue "输入stream的密码:"
    read stream_password
}

install_xray(){ 
    green "$(date +"%Y-%m-%d %H:%M:%S") ==== 安装xray"
    mkdir /usr/local/etc/xray/
    mkdir /usr/local/etc/xray/cert
    bash <(curl -L https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)
    cd /usr/local/etc/xray/
    rm -f config.json
    v2uuid=$(cat /proc/sys/kernel/random/uuid)

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

cat > /usr/local/etc/xray/myconfig_tcp_xtls.json<<-EOF
{
地址：${your_domain}
端口：443
id：${v2uuid}
加密：none
流控：xtls-rprx-direct
传输协议：tcp
伪装类型：none
底层传输：xtls
跳过证书验证：false
连接：vless://${v2uuid}@${your_domain}:443?security=xtls&encryption=none&headerType=none&type=tcp&flow=xtls-rprx-splice#${your_domain}
}
EOF
    
}
change_2_tcp_xtls(){
    echo "tcp_xtls" > /usr/local/etc/xray/atrandys_config
    \cp /usr/local/etc/xray/tcp_xtls_config.json /usr/local/etc/xray/config.json
    #systemctl restart xray

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

cat > /usr/local/etc/xray/myconfig_tcp_tls.json<<-EOF
{
===========配置参数=============
地址：${your_domain}
端口：443
id：${v2uuid}
加密：none
传输协议：tcp
伪装类型：none
底层传输：tls
跳过证书验证：false
}
EOF
}
change_2_tcp_tls(){
    echo "tcp_tls" > /usr/local/etc/xray/atrandys_config
    \cp /usr/local/etc/xray/tcp_tls_config.json /usr/local/etc/xray/config.json
    #systemctl restart xray
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

cat > /usr/local/etc/xray/myconfig_ws_tls.json<<-EOF
{
===========配置参数=============
地址：${your_domain}
端口：443
uuid：${v2uuid}
传输协议：grpc
ServiceName：${your_domain}
底层传输：tls
链接：vless://${v2uuid}@${your_domain}:443?mode=multi&type=grpc&encryption=none&serviceName=${your_domain}&security=tls#${your_domain}
}
EOF
}
change_2_ws_tls(){
    echo "ws_tls" > /usr/local/etc/xray/atrandys_config
    \cp /usr/local/etc/xray/ws_tls_config.json /usr/local/etc/xray/config.json
    #systemctl restart xray
}

get_myconfig(){
    check_config_type=$(cat /usr/local/etc/xray/atrandys_config)
    green "当前配置：$check_config_type"
    if [ "$check_config_type" == "tcp_xtls" ]; then
        cat /usr/local/etc/xray/myconfig_tcp_xtls.json
    fi
    if [ "$check_config_type" == "tcp_tls" ]; then
        cat /usr/local/etc/xray/myconfig_tcp_tls.json
    fi
    if [ "$check_config_type" == "ws_tls" ]; then
        cat /usr/local/etc/xray/myconfig_ws_tls.json
    fi
}

remove_xray(){
    green "$(date +"%Y-%m-%d %H:%M:%S") - 删除xray."
    systemctl stop xray.service
    systemctl disable xray.service
    rm -rf /usr/local/share/xray/ /usr/local/etc/xray/
    rm -f /usr/local/bin/xray
    rm -rf /etc/systemd/system/xray*
    rm -rf /root/.acme.sh/
    green "xray has been deleted."
    
}

function start_menu(){
    clear
    green "======================================================="
    echo -e "\033[34m\033[01m描述：\033[0m \033[32m\033[01mxray安装脚本20230312\033[0m"
    green "======================================================="
    echo
    green " 1. 安装 xray: vless+tcp+xtls/VLESS-TCP-XTLS-uTLS-REALITY"
    green " 2. 安装 xray: vless+tcp+xtls-Vision/VLESS-H2-uTLS-REALITY"
    green " 3. 安装 xray: vless+grpc+tls/VLESS-GRPC-uTLS-REALITY"
    echo
    green " 4. 更新 xray"
    green " 5. 切换配置"
    red " 6. 删除 xray"
    green " 7. 查看配置参数"
    yellow " 0. Exit"
    echo
    read -p "输入数字:" num
    case "$num" in
    1)
    check_release
    check_port
    check_domain "tcp_xtls"
    ;;
    2)
    check_release
    check_port
    check_domain "tcp_tls"
    ;;
    3)
    check_release
    check_port
    check_domain "ws_tls"
    ;;
    4)
    bash <(curl -L https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)
    systemctl restart xray
    ;;
    5)
        if [ -f "/usr/local/etc/xray/atrandys_config" ]; then
            green "========================================================="
            green "当前配置：$(cat /usr/local/etc/xray/atrandys_config)"
            red "注意！切换配置会使自定义修改的config.json内容丢失，请知晓"
            green "========================================================="
            echo
            green " 1. 切换至vless+tcp+xtls"
            green " 2. 切换至vless+tcp+tls"
            green " 3. 切换至vless+grpc+tls"
            yellow " 0. 返回上级"
            echo
            read -p "输入数字:" num
            case "$num" in
            1)
            change_2_tcp_xtls
            systemctl restart xray
            ;;
            2)
            change_2_tcp_tls
            systemctl restart xray
            ;;
            3)
            change_2_ws_tls
            systemctl restart xray
            ;;
            0)
            clear
            start_menu
            ;;
            *)
            clear
            red "请输入正确的数字"
            sleep 2s
            start_menu
            ;;
            esac
        else
            red "似乎你还没有使用过本脚本安装xray，不存在相关配置"
            sleep 2s
            clear
            start_menu
        fi
        
    ;;
    6)
    remove_xray 
    ;;
    7)
    get_myconfig
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
