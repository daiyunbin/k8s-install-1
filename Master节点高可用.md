当需要外网操作k8s集群时，需要用到k8s master高可用，通过一个vip连到master集群。
参考连接：https://jimmysong.io/kubernetes-handbook/practice/master-ha.html

本文档记录了该操作：

1.需要在Master手工安装keepalived, haproxy。
```bash
yum install -y keepalived
yum install -y haproxy
```

2.修改haproxy的配置文件
* 需要将HAProxy默认的配置文件balance从source修改为roundrobin方式;
* 配置文件haproxy.cfg默认路径是/etc/haproxy/haproxy.cfg;
* 需要手工创建/run/haproxy的目录，否则haproxy会启动失败;
* server指定的就是实际的Master节点地址以及真正工作的端口号,有多少台Master就写多少条记录。

3.修改keepalived的配置文件，配置正确的VIP。
* 配置文件keepalived.conf的默认路径是/etc/keepalived/keepalived.conf；
* virtual_ipaddress提供的就是VIP的地址，该地址在子网内必须是空闲未必分配的。

4.配置好后，先启动主Master的keepalived和haproxy。等VIP确定后再启动其他Master比较靠谱。
```bash
systemctl enable keepalived
systemctl start keepalived
systemctl enable haproxy
systemctl start haproxy
```

5.检验
```bash
# 查看是否有VIP地址分配
ip a s
# 查看keepalived的状态
systemctl status keepalived -l
# 查看haproxy的状态
systemctl status haproxy -l
# 获取到kubectl的服务器信息
kubectl version
```
以上操作输出说明keepalived和haproxy都是成功的。
这个时候可以依次将其他Master节点的keepalived和haproxy启动。

6.查看vip
```bash
[root@kube-node1 scripts]# kubectl cluster-info
Kubernetes master is running at https://192.168.100.3:443
```