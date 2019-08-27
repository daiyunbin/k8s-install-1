*以root用户安装k8s
*VIP_IF 根据实际网卡情况设置

#准备工作

##按照自己实际情况修改./scripts/environment.sh脚本中的变量设置

##事先设置好集群机器的主机名
*hostnamectl set-hostname kube-node1
*hostnamectl set-hostname kube-node2
*hostnamectl set-hostname kube-node3
###修改/etc/hosts文件,添加：
*192.168.100.61 kube-node1 kube-node1
*192.168.100.62 kube-node2 kube-node2
*192.168.100.63 kube-node3 kube-node3

##最后执行 ./install-start.sh 即可
