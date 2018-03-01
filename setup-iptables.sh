#!/bin/bash

#  coding "feel"
#  email "568824204@qq.com"
#  /etc/sysconfig/iptables
# ssh root@MachineB 'bash -s' < local_script.sh
# use puppet later
# yum -y install iptables-services net-tools
# systemctl  status iptables.service
# systemctl  stop iptables
# systemctl start iptables.service
# systemctl  enabled iptables
# systemctl restart docker
# https://fralef.me/docker-and-iptables.html

systemctl stop firewalld.service
systemctl disable firewalld.service


declare -A hosts

#对以下机器 端口全部开放
hosts=(
  [qa]=xxxxxxx
)

declare -A webports

#本机需要对外开放的端口
webports=(
  [nginx]=80
  [nginxs]=443
)

# 声明 主机名
declare  -x  localname  
#  主机名
localname="qa"

#查看iptables现有规则
echo "--------------------------------------------------------------"
iptables -L -n
echo "--------------------------------------------------------------"

# iptables 样例设置脚本
#
# 清除 iptables 内一切现存的规则
# iptables -F

iptables -F  INPUT
iptables -F  OUTPUT
# 容让 SSH 连接到 tcp 端口 22
# 当通过 SSH 远程连接到服务器，你必须这样做才能群免被封锁于系统外
iptables  -A INPUT -p tcp -m state --state NEW -m tcp --dport 22 -j ACCEPT

# 设置默认策略
# 启动白名单机制,默认拒绝所有的报文
iptables  -P INPUT DROP
iptables  -P FORWARD DROP
# 设置默认OUTPUT默认规则是应许全部报文出去
iptables  -P OUTPUT ACCEPT


# 设置 localhost 的访问权
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo  -j ACCEPT

#接纳属于现存及相关连接的封包
iptables -A  INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
#屏蔽了nmap探测的icmp回应,以下规则是针对我自己的vps 添加的
iptables -A INPUT -j REJECT --reject-with icmp-host-prohibited
#允许ping
iptables -A INPUT -p icmp --icmp-type 8 -i eth0 -j ACCEPT


iptables  -t filter -N IN_WEB

iptables -nvL IN_WEB
#清除 iptables 自定义链

#rule_num=`iptables -nvL --line-numbers | grep "IN_WEB" | awk '{print $1}'| grep -v Chain | wc -l`

rule_num=`iptables -nvL IN_WEB |grep "ACCEPT" |wc -l`

if [ $rule_num -ne 0 ]; then
  for((i=1;i<=$rule_num;i++)); do
        iptables -D IN_WEB 1
  done
  #iptables  -X  IN_WEB
fi

# 开发外网端口
if [ "$(hostname)" == "$localname" ]; then
  for p in "${!webports[@]}"
  do
   echo  "外网开放端口 ${webports[$p]}"
   iptables -A IN_WEB -p tcp -m state --state NEW -m tcp --dport ${webports[$p]} -j ACCEPT
   iptables -I INPUT -p tcp --dport ${webports[$p]} -j IN_WEB

  done
fi

echo "接纳来自被信任IP地址的封包"

#接纳来自被信任IP地址的封包
for h in "${!hosts[@]}"
do
  if [ "$(hostname)" != "$h" ]; then
    echo "接纳来自被信任IP地址的封包ip:${hosts[$h]}"
    iptables -A IN_WEB -s  ${hosts[$h]} -j ACCEPT
    iptables -I INPUT  -s  ${hosts[$h]} -j IN_WEB
  fi
done



# 存储设置
# 
# /sbin/service iptables save
#
# 列出规则
#
iptables -L -v

 