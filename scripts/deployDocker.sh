#!/usr/bin/bash

source /opt/k8s/bin/environment.sh
cd /opt/k8s/work

# 部署 worker 节点
# 安装依赖包
for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "yum install -y epel-release"
    ssh root@${node_ip} "yum install -y conntrack ipvsadm ntp ntpdate ipset jq iptables curl sysstat libseccomp && modprobe ip_vs "
  done

# 下载 docker 二进制文件
if [ ! -f "/home/yyr/k8s-install/packages/docker-18.09.6.tgz" ];then
  wget https://download.docker.com/linux/static/stable/x86_64/docker-18.09.6.tgz
  tar -xvf docker-18.09.6.tgz
else
  tar -xvf /home/yyr/k8s-install/packages/docker-18.09.6.tgz   
fi

# 分发二进制文件到所有 worker 节点
for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp docker/*  root@${node_ip}:/opt/k8s/bin/
    ssh root@${node_ip} "chmod +x /opt/k8s/bin/*"
  done

# 创建和分发 systemd unit 文件
cat > docker.service <<"EOF"
[Unit]
Description=Docker Application Container Engine
Documentation=http://docs.docker.io

[Service]
WorkingDirectory=##DOCKER_DIR##
Environment="PATH=/opt/k8s/bin:/bin:/sbin:/usr/bin:/usr/sbin"
EnvironmentFile=-/run/flannel/docker
ExecStart=/opt/k8s/bin/dockerd $DOCKER_NETWORK_OPTIONS
ExecReload=/bin/kill -s HUP $MAINPID
Restart=on-failure
RestartSec=5
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
Delegate=yes
KillMode=process

[Install]
WantedBy=multi-user.target
EOF

# 分发 systemd unit 文件到所有 worker 机器
sed -i -e "s|##DOCKER_DIR##|${DOCKER_DIR}|" docker.service
for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp docker.service root@${node_ip}:/etc/systemd/system/
  done

# 配置 docker 配置文件
cat > docker-daemon.json <<EOF
{
    "registry-mirrors": ["https://docker.mirrors.ustc.edu.cn","https://hub-mirror.c.163.com"],
    "insecure-registries": ["docker02:35000"],
    "max-concurrent-downloads": 20,
    "live-restore": true,
    "max-concurrent-uploads": 10,
    "debug": true,
    "data-root": "${DOCKER_DIR}/data",
    "exec-root": "${DOCKER_DIR}/exec",
    "log-opts": {
      "max-size": "100m",
      "max-file": "5"
    }
}
EOF

# 分发 docker 配置文件到所有 worker 节点
for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "mkdir -p  /etc/docker/ ${DOCKER_DIR}/{data,exec}"
    scp docker-daemon.json root@${node_ip}:/etc/docker/daemon.json
  done

# 启动 docker 服务
for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "systemctl daemon-reload && systemctl enable docker && systemctl restart docker"
  done

# 检查服务运行状态
for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "systemctl status docker|grep Active"
  done

# 检查 docker0 网桥
for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "/usr/sbin/ip addr show flannel.1 && /usr/sbin/ip addr show docker0"
  done
