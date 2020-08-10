### 集群机器
* kube-node1：192.168.100.61
* kube-node2：192.168.100.62
* kube-node3：192.168.100.63
### 注意
* 本文档中的 etcd 集群、master 节点、worker 节点均使用这三台机器；
* 需要使用 root 账号安装 k8s
* IFACE 根据实际网卡情况设置

# 准备工作

### 事先设置好集群机器的主机名
* hostnamectl set-hostname kube-node1
* hostnamectl set-hostname kube-node2
* hostnamectl set-hostname kube-node3
### 修改/etc/hosts文件，添加：
* 192.168.100.61 kube-node1 kube-node1
* 192.168.100.62 kube-node2 kube-node2
* 192.168.100.63 kube-node3 kube-node3
### 请根据自己的机器、网络情况修改./scripts目录下相关脚本中的变量设置和ip配置
environment.sh、deployEtcd.sh、kube-apiserver-nginx.sh、
deploy-kube-apiserver.sh、deploy-kube-controller-manager.sh、deploy-kube-scheduler.sh
等脚本中存在要修改的项。
### 最后执行 ./install-start.sh 即可
