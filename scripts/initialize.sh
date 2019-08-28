#!/usr/bin/bash

# 设置 kube-node1 的 root 账户可以无密码登录所有节点
ssh-keygen -t rsa
ssh-copy-id root@kube-node1
ssh-copy-id root@kube-node2
ssh-copy-id root@kube-node3

# 优化内核参数
cat > kubernetes.conf <<EOF
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
net.ipv4.ip_forward=1
net.ipv4.tcp_tw_recycle=0
vm.swappiness=0 # 禁止使用 swap 空间，只有当系统 OOM 时才允许使用它
vm.overcommit_memory=1 # 不检查物理内存是否够用
vm.panic_on_oom=0 # 开启 OOM
fs.inotify.max_user_instances=8192
fs.inotify.max_user_watches=1048576
fs.file-max=52706963
fs.nr_open=52706963
net.ipv6.conf.all.disable_ipv6=1
net.netfilter.nf_conntrack_max=2310720
EOF

source environment.sh
for node_ip in ${NODE_IPS[@]}
  do 
    echo ">>> ${node_ip}"

    # 添加 docker 账户
    ssh root@${node_ip}  "sudo useradd -m docker"

    # 将可执行文件目录添加到 PATH 环境变量中
    ssh root@${node_ip}  "echo 'PATH=/opt/k8s/bin:$PATH' >>/root/.bashrc && source /root/.bashrc"

    # 安装依赖包
    ssh root@${node_ip}  "yum install -y epel-release && yum install -y conntrack ntpdate ntp ipvsadm ipset jq iptables curl sysstat libseccomp wget"

    # 关闭防火墙
    ssh root@${node_ip}  "systemctl stop firewalld && systemctl disable firewalld" 
    ssh root@${node_ip}  "iptables -F && iptables -X && iptables -F -t nat && iptables -X -t nat" 
    ssh root@${node_ip}  "iptables -P FORWARD ACCEPT"

    # 关闭 swap 分区
    ssh root@${node_ip}  "swapoff -a && sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab"
    
    # 关闭SELinux
    ssh root@${node_ip}  "sudo setenforce 0"
    ssh root@${node_ip}  "sudo sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config"

    # 加载内核模块    
    ssh root@${node_ip}  "sudo modprobe br_netfilter && sudo modprobe ip_vs"
    
    # 设置系统参数
    scp kubernetes.conf  root@${node_ip}:/etc/sysctl.d/kubernetes.conf
    ssh root@${node_ip}  "sysctl -p /etc/sysctl.d/kubernetes.conf"

    # 设置系统时区
    ssh root@${node_ip}  "sudo timedatectl set-timezone Asia/Shanghai && sudo timedatectl set-local-rtc 0"
    ssh root@${node_ip}  "sudo systemctl restart rsyslog && sudo systemctl restart crond"

    # 关闭无关的服务
    ssh root@${node_ip}  "systemctl stop postfix && systemctl disable postfix"

    # 创建相关目录
    ssh root@${node_ip}  "mkdir -p /opt/k8s/{bin,work} /etc/{kubernetes,etcd}/cert"

    # 分发集群环境变量定义脚本
    scp environment.sh  root@${node_ip}:/opt/k8s/bin
    ssh root@${node_ip}  "chmod +x /opt/k8s/bin/*"
  done
