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

function start_menu(){
    echo -e "\033[34m\033[01m选择指向的网站\033[0m"
    echo
    green " a. elements.envato.com $(curl -s ipinfo.io/$(ping -c 1 elements.envato.com | grep 'bytes from' | awk '{print $4}' | cut -d ':' -f 1)/country)"
    green " b. www.bhphotovideo.com $(curl -s ipinfo.io/$(ping -c 1 www.bhphotovideo.com | grep 'bytes from' | awk '{print $4}' | cut -d ':' -f 1)/country)"
    green " c. plus.nhk.jp $(curl -s ipinfo.io/$(ping -c 1 plus.nhk.jp | grep 'bytes from' | awk '{print $4}' | cut -d ':' -f 1)/country)"
    green " d. kurand.jp $(curl -s ipinfo.io/$(ping -c 1 kurand.jp | grep 'bytes from' | awk '{print $4}' | cut -d ':' -f 1)/country)"
    green " e. www.rustictown.com $(curl -s ipinfo.io/$(ping -c 1 www.rustictown.com | grep 'bytes from' | awk '{print $4}' | cut -d ':' -f 1)/country)"
    green " f. www.hsbc.com.hk $(curl -s ipinfo.io/$(ping -c 1 www.hsbc.com.hk | grep 'bytes from' | awk '{print $4}' | cut -d ':' -f 1)/country)"
    green " g. hkow.hk $(curl -s ipinfo.io/$(ping -c 1 hkow.hk | grep 'bytes from' | awk '{print $4}' | cut -d ':' -f 1)/country)"
    yellow " 0. Exit"
    echo
    read -p "输入数字:" num
    case "$num" in
    a)
    site=elements.envato.com
    ;;
    b)
    site=elements.envato.com
    ;;
    c)
    site=elements.envato.com
    ;;
    d)
    site=elements.envato.com
    ;;
    e)
    site=elements.envato.com
    ;;
    f)
    site=elements.envato.com
    ;;
    g)
    site=elements.envato.com
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
