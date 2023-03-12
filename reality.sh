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
check_release(){
    green "$(date +"%Y-%m-%d %H:%M:%S") ==== 检查系统版本"
    if [ "$RELEASE" == "centos" ]; then
        systemPackage="yum"
        yum install -y wget
        if  [ "$VERSION" == "6" ] ;then
            red "$(date +"%Y-%m-%d %H:%M:%S") - 暂不支持CentOS 6.\n== Install failed."
            exit
        fi
        if  [ "$VERSION" == "5" ] ;then
            red "$(date +"%Y-%m-%d %H:%M:%S") - 暂不支持CentOS 5.\n== Install failed."
            exit
        fi
        if [ -f "/etc/selinux/config" ]; then
            CHECK=$(grep SELINUX= /etc/selinux/config | grep -v "#")
            if [ "$CHECK" == "SELINUX=enforcing" ]; then
                green "$(date +"%Y-%m-%d %H:%M:%S") - SELinux状态非disabled,关闭SELinux."
                setenforce 0
                sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
                #loggreen "SELinux is not disabled, add port 80/443 to SELinux rules."
                #loggreen "==== Install semanage"
                #logcmd "yum install -y policycoreutils-python"
                #semanage port -a -t http_port_t -p tcp 80
                #semanage port -a -t http_port_t -p tcp 443
                #semanage port -a -t http_port_t -p tcp 37212
                #semanage port -a -t http_port_t -p tcp 37213
            elif [ "$CHECK" == "SELINUX=permissive" ]; then
                green "$(date +"%Y-%m-%d %H:%M:%S") - SELinux状态非disabled,关闭SELinux."
                setenforce 0
                sed -i 's/SELINUX=permissive/SELINUX=disabled/g' /etc/selinux/config
            fi
        fi
        firewall_status=`firewall-cmd --state`
        if [ "$firewall_status" == "running" ]; then
            green "$(date +"%Y-%m-%d %H:%M:%S") - FireWalld状态非disabled,添加80/443到FireWalld rules."
            firewall-cmd --zone=public --add-port=80/tcp --permanent
            firewall-cmd --zone=public --add-port=443/tcp --permanent
            firewall-cmd --reload
        fi
        while [ ! -f "nginx-release-centos-7-0.el7.ngx.noarch.rpm" ]
        do
            wget http://nginx.org/packages/centos/7/noarch/RPMS/nginx-release-centos-7-0.el7.ngx.noarch.rpm
            if [ ! -f "nginx-release-centos-7-0.el7.ngx.noarch.rpm" ]; then
                red "$(date +"%Y-%m-%d %H:%M:%S") - 下载nginx rpm包失败，继续重试..."
            fi
        done
        rpm -ivh nginx-release-centos-7-0.el7.ngx.noarch.rpm --force --nodeps
        #logcmd "rpm -Uvh http://nginx.org/packages/centos/7/noarch/RPMS/nginx-release-centos-7-0.el7.ngx.noarch.rpm --force --nodeps"
        #loggreen "Prepare to install nginx."
        #yum install -y libtool perl-core zlib-devel gcc pcre* >/dev/null 2>&1
        yum install -y epel-release
    elif [ "$RELEASE" == "ubuntu" ]; then
        systemPackage="apt-get"
        if  [ "$VERSION" == "14" ] ;then
            red "$(date +"%Y-%m-%d %H:%M:%S") - 暂不支持Ubuntu 14.\n== Install failed."
            exit
        fi
        if  [ "$VERSION" == "12" ] ;then
            red "$(date +"%Y-%m-%d %H:%M:%S") - 暂不支持Ubuntu 12.\n== Install failed."
            exit
        fi
        ufw_status=`systemctl status ufw | grep "Active: active"`
        if [ -n "$ufw_status" ]; then
            ufw allow 80/tcp
            ufw allow 443/tcp
            ufw reload
        fi
        apt-get update >/dev/null 2>&1
    elif [ "$RELEASE" == "debian" ]; then
        systemPackage="apt-get"
        ufw_status=`systemctl status ufw | grep "Active: active"`
        if [ -n "$ufw_status" ]; then
            ufw allow 80/tcp
            ufw allow 443/tcp
            ufw reload
        fi
        apt-get update >/dev/null 2>&1
    else
        red "$(date +"%Y-%m-%d %H:%M:%S") - 当前系统不被支持. \n== Install failed."
        exit
    fi
}

install_xray(){ 
    green "$(date +"%Y-%m-%d %H:%M:%S") ==== 安装xray"
    mkdir /usr/local/etc/xray/
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
    red " 5. 删除 xray"
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
