#!/usr/bin/bash

source /opt/k8s/bin/environment.sh
cd /opt/k8s/work

# 下载 nginx 源码
mkdir nginx

if [ ! -f "/home/yyr/k8s-install/packages/nginx-1.15.3.tar.gz" ];then
  wget http://nginx.org/download/nginx-1.15.3.tar.gz
  tar -xzvf http://nginx.org/download/nginx-1.15.3.tar.gz -C nginx
else
  tar -xzvf /home/yyr/k8s-install/packages/nginx-1.15.3.tar.gz -C nginx
fi

# 配置编译参数
cd nginx/nginx-1.15.3
mkdir nginx-prefix
./configure --with-stream --without-http --prefix=$(pwd)/nginx-prefix --without-http_uwsgi_module --without-http_scgi_module --without-http_fastcgi_module

# 编译和安装
make && make install

# 验证编译的 nginx
./nginx-prefix/sbin/nginx -v

# 安装和部署 nginx
# 创建目录结构
cd /opt/k8s/work
for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    mkdir -p /opt/k8s/kube-nginx/{conf,logs,sbin}
  done

# 拷贝二进制程序
for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "mkdir -p /opt/k8s/kube-nginx/{conf,logs,sbin}"
    scp /opt/k8s/work/nginx/nginx-1.15.3/nginx-prefix/sbin/nginx  root@${node_ip}:/opt/k8s/kube-nginx/sbin/kube-nginx
    ssh root@${node_ip} "chmod a+x /opt/k8s/kube-nginx/sbin/*"
  done

# 配置 nginx，开启 4 层透明转发功能
cat > kube-nginx.conf << \EOF
worker_processes 1;

events {
    worker_connections  1024;
}

stream {
    upstream backend {
        hash $remote_addr consistent;
        server 192.168.100.61:6443        max_fails=3 fail_timeout=30s;
        server 192.168.100.62:6443        max_fails=3 fail_timeout=30s;
        server 192.168.100.63:6443        max_fails=3 fail_timeout=30s;
    }

    server {
        listen 127.0.0.1:8443;
        proxy_connect_timeout 1s;
        proxy_pass backend;
    }
}
EOF

# 分发配置文件
for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp kube-nginx.conf  root@${node_ip}:/opt/k8s/kube-nginx/conf/kube-nginx.conf
  done

# 配置 kube-nginx systemd unit 文件
cat > kube-nginx.service <<EOF
[Unit]
Description=kube-apiserver nginx proxy
After=network.target
After=network-online.target
Wants=network-online.target

[Service]
Type=forking
ExecStartPre=/opt/k8s/kube-nginx/sbin/kube-nginx -c /opt/k8s/kube-nginx/conf/kube-nginx.conf -p /opt/k8s/kube-nginx -t
ExecStart=/opt/k8s/kube-nginx/sbin/kube-nginx -c /opt/k8s/kube-nginx/conf/kube-nginx.conf -p /opt/k8s/kube-nginx
ExecReload=/opt/k8s/kube-nginx/sbin/kube-nginx -c /opt/k8s/kube-nginx/conf/kube-nginx.conf -p /opt/k8s/kube-nginx -s reload
PrivateTmp=true
Restart=always
RestartSec=5
StartLimitInterval=0
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

# 分发 systemd unit 文件
for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp kube-nginx.service  root@${node_ip}:/etc/systemd/system/
  done

# 启动 kube-nginx 服务
for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "systemctl daemon-reload && systemctl enable kube-nginx && systemctl restart kube-nginx"
  done

# 检查 kube-nginx 服务运行状态
for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "systemctl status kube-nginx |grep 'Active:'"
  done
