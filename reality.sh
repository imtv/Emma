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
    eval $1 | tee -ai /var/xray.log
}

start_install(){
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
    blue "输入流媒体解锁服务器SOCKS的IP:"
    read stream_IP
    blue "端口:"
    read stream_port
    blue "用户名:"
    read stream_id
    blue "密码:"
    read stream_password

    echo -e "\033[34m\033[01m选择指向的网站\033[0m"
    echo
    green " a. elements.envato.com
    green " b. www.bhphotovideo.com
    green " c. plus.nhk.jp
    green " d. kurand.jp
    green " e. www.rustictown.com
    green " f. www.hsbc.com.hk
    green " g. hkow.hk
    echo
    read -p "输入数字:" num
    case "$num" in
    a)
    site=elements.envato.com
    ;;
    b)
    site=www.bhphotovideo.com
    ;;
    c)
    site=plus.nhk.jp
    ;;
    d)
    site=kurand.jp
    ;;
    e)
    site=www.rustictown.com
    ;;
    f)
    site=www.hsbc.com.hk
    ;;
    g)
    site=hkow.hk
    ;;

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
    local_addr=`curl ipv4.icanhazip.com`
    key=$(xray x25519)
    privateKey=$(sed -n 's/Private key: \(.*\)/\1/p' <<< "$key")
    publicKey=$(sed -n 's/Public key: \(.*\)/\1/p' <<< "$key")
    shortIds=("$(openssl rand -hex 6)" "$(openssl rand -hex 6)" "$(openssl rand -hex 6)" "$(openssl rand -hex 8)" "$(openssl rand -hex 8)" "$(openssl rand -hex 8)")
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
    systemctl restart xray
    echo
    echo
    green "==xray配置参数=="
    get_myconfig
    echo
    echo
    green "本次安装检测信息如下，如nginx与xray正常启动，表示安装正常："
    ps -aux | grep -e xray
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
                "domain": ["geosite:netflix","tudum.com","geosite:disney"],
                "outboundTag": "hhsg"
            },
            {
                "type": "field",
                "domain": ["catchplay.com.tw","catchplay.com","cloudfront.net","akamaized.net","services.googleapis.cn","xn--ngstr-lra8j.com"],
                "outboundTag": "mmtw"
            },
            {
                "type": "field",
                "domain": ["openai.com","bard.google.com","geosite:hbo","geosite:primevideo"],
                "outboundTag": "dtus"
            },
            {
                "type": "field",
                "domain": [
                    "geosite:category-ads-all",
                    "geosite:cn",
                    "geosite:private"
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
                    "dest": "$site:443",
                    "xver": 0,
                    "serverNames": [
                        "$site"
                    ],
                    "privateKey": "$privateKey",
                    "shortIds": [
                        "${shortIds[0]}",
                        "${shortIds[1]}",
                        "${shortIds[2]}",
                        "${shortIds[3]}",
                        "${shortIds[4]}",
                        "${shortIds[5]}"
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
        },
        {
          "tag": "dtus",
          "protocol": "socks",
          "settings": {"servers": [{"address": "${stream_IP}","port": ${stream_port},"users": [{"user": "${stream_id}","pass": "${stream_password}"}]}]}
        }
    ]
}
EOF

cat > /usr/local/etc/xray/myconfig_tcp_xtls.json<<-EOF
{
ip  ：${local_addr}
port：443
id  ：${v2uuid}
flow：xtls-rprx-vision
network   ：tcp
publicKey ：${publicKey}
shortIds  ：${shortIds[0]},${shortIds[1]},${shortIds[2]},${shortIds[3]},${shortIds[4]},${shortIds[5]}
}
EOF
    
}

change_2_tcp_xtls(){
    echo "tcp_xtls" > /usr/local/etc/xray/xray_config
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
    "routing": { 
        "domainStrategy": "IPIfNonMatch",
        "rules": [
            {
                "type": "field",
                "domain": ["geosite:netflix","tudum.com","geosite:disney"],
                "outboundTag": "hhsg"
            },
            {
                "type": "field",
                "domain": ["catchplay.com.tw","catchplay.com","cloudfront.net","akamaized.net","services.googleapis.cn","xn--ngstr-lra8j.com"],
                "outboundTag": "mmtw"
            },
            {
                "type": "field",
                "domain": ["openai.com","bard.google.com","geosite:hbo","geosite:primevideo"],
                "outboundTag": "dtus"
            },
            {
                "type": "field",
                "domain": [
                    "geosite:category-ads-all",
                    "geosite:cn",
                    "geosite:private"
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
                        "flow": ""
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "h2",
                "security": "reality",
                "realitySettings": {
                    "show": false,
                    "dest": "www.lovelive-anime.jp:443", 
                    "xver": 0,
                    "serverNames": [ 
                        "lovelive-anime.jp", 
                        "www.lovelive-anime.jp"
                    ],
                    "privateKey": "$privateKey",
                    "shortIds": [ 
                        "${shortIds[0]}",
                        "${shortIds[1]}",
                        "${shortIds[2]}",
                        "${shortIds[3]}",
                        "${shortIds[4]}",
                        "${shortIds[5]}"
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
        },
        {
          "tag": "dtus",
          "protocol": "socks",
          "settings": {"servers": [{"address": "${stream_IP}","port": ${stream_port},"users": [{"user": "${stream_id}","pass": "${stream_password}"}]}]}
        }
    ]
}
EOF

cat > /usr/local/etc/xray/myconfig_h2.json<<-EOF
{
ip  ：${local_addr}
port：443
id  ：${v2uuid}
flow：留空
network   ：h2
publicKey ：${publicKey}
shortIds  ：${shortIds[0]},${shortIds[1]},${shortIds[2]},${shortIds[3]},${shortIds[4]},${shortIds[5]}
}
EOF
    
}

change_2_h2(){
    echo "h2" > /usr/local/etc/xray/xray_config
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
    "routing": { 
        "domainStrategy": "IPIfNonMatch",
        "rules": [
            {
                "type": "field",
                "domain": ["geosite:netflix","tudum.com","geosite:disney"],
                "outboundTag": "hhsg"
            },
            {
                "type": "field",
                "domain": ["catchplay.com.tw","catchplay.com","cloudfront.net","akamaized.net","services.googleapis.cn","xn--ngstr-lra8j.com"],
                "outboundTag": "mmtw"
            },
            {
                "type": "field",
                "domain": ["openai.com","bard.google.com","geosite:hbo","geosite:primevideo"],
                "outboundTag": "dtus"
            },
            {
                "type": "field",
                "domain": [
                    "geosite:category-ads-all",
                    "geosite:cn",
                    "geosite:private"
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
                        "flow": ""
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "grpc",
                "security": "reality",
                "realitySettings": {
                    "show": false,
                    "dest": "www.lovelive-anime.jp:443",
                    "xver": 0,
                    "serverNames": [
                        "lovelive-anime.jp",
                        "www.lovelive-anime.jp"
                    ],
                    "privateKey": "$privateKey",
                    "shortIds": [
                        "${shortIds[0]}",
                        "${shortIds[1]}",
                        "${shortIds[2]}",
                        "${shortIds[3]}",
                        "${shortIds[4]}",
                        "${shortIds[5]}"
                    ]
                },
                "grpcSettings": {
                    "serviceName": "grpc"
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
        },
        {
          "tag": "dtus",
          "protocol": "socks",
          "settings": {"servers": [{"address": "${stream_IP}","port": ${stream_port},"users": [{"user": "${stream_id}","pass": "${stream_password}"}]}]}
        }
    ]
}
EOF

cat > /usr/local/etc/xray/myconfig_grpc.json<<-EOF
{
ip  ：${local_addr}
port：443
id  ：${v2uuid}
flow：留空
network    ：grpc
serviceName：grpc
publicKey  ：${publicKey}
shortIds   ：${shortIds[0]},${shortIds[1]},${shortIds[2]},${shortIds[3]},${shortIds[4]},${shortIds[5]}
}
EOF

}

change_2_grpc(){
    echo "grpc" > /usr/local/etc/xray/xray_config
    \cp /usr/local/etc/xray/grpc_config.json /usr/local/etc/xray/config.json
    #systemctl restart xray
}

get_myconfig(){
    check_config_type=$(cat /usr/local/etc/xray/xray_config)
    green "当前配置：$check_config_type"
    if [ "$check_config_type" == "tcp_xtls" ]; then
        cat /usr/local/etc/xray/myconfig_tcp_xtls.json
    fi
    if [ "$check_config_type" == "h2" ]; then
        cat /usr/local/etc/xray/myconfig_h2.json
    fi
    if [ "$check_config_type" == "grpc" ]; then
        cat /usr/local/etc/xray/myconfig_grpc.json
    fi
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
    green "======================================================="
    echo -e "\033[34m\033[01mXRAY-REALITY安装脚本20230323-1\033[0m"
    green "======================================================="
    echo
    green " 1. 安装 xray: VLESS-XTLS-uTLS-REALITY"
    green " 2. 安装 xray: VLESS-H2-uTLS-REALITY"
    green " 3. 安装 xray: VLESS-GRPC-uTLS-REALITY"
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
    start_install "tcp_xtls"
    ;;
    2)
    start_install "h2"
    ;;
    3)
    start_install "grpc"
    ;;
    4)
    bash <(curl -L https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)
    systemctl restart xray
    ;;

    5)
        if [ -f "/usr/local/etc/xray/xray_config" ]; then
            green "========================================================="
            green "当前配置：$(cat /usr/local/etc/xray/xray_config)"
            green "========================================================="
            echo
            green " 1. 切换至VLESS-XTLS-uTLS-REALITY"
            green " 2. 切换至VLESS-H2-uTLS-REALITY"
            green " 3. 切换至VLESS-GRPC-uTLS-REALITY"
            yellow " 0. 返回上级"
            echo
            read -p "输入数字:" num
            case "$num" in
            1)
            change_2_tcp_xtls
            systemctl restart xray
            ;;
            2)
            change_2_h2
            systemctl restart xray
            ;;
            3)
            change_2_grpc
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
            sleep 5s
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
