## Manage statefullsets like a PRO

# 1. restore state
```
1.1 create state
helm install postgresql-ha bitnami/postgresql-ha --version 15.1.4 -f postgres.yaml

#save passwords
PASSWORD= REPMGR_PASSWORD= ADMIN_PASSWORD=
helm delete postgresql-ha
pushd /var/openebs/local/pvc-141f9a03-5792-40ee-bea4-cf0296b6c042/
tar -cf /home/ansible/sts/postgresql_dev.tar data/
popd
gzip -9 postgresql_dev.tar
k delete pv, pvc ...

1.2 restore state
#change diagnostic to true
helm install postgresql-ha bitnami/postgresql-ha --version 15.1.4 -f postgres.yaml --set postgresql.password=$PASSWORD --set postgresql.repmgrPassword=$REPMGR_PASSWORD --set pgpool.adminPassword=$ADMIN_PASSWORD
cat postgresql_dev.tar.gz | kubectl exec -i postgresql-ha-postgresql-0  -c postgresql -- tar xfz - -C /bitnami/postgresql/
#change diagnostic to false
helm upgrade postgresql-ha bitnami/postgresql-ha --version 15.1.4 -f postgres.yaml --set postgresql.password=$PASSWORD --set postgresql.repmgrPassword=$REPMGR_PASSWORD --set pgpool.adminPassword=$ADMIN_PASSWORD
kubectl scale sts postgresql-ha-postgresql --replicas 0
kubectl scale sts postgresql-ha-postgresql --replicas 2

/opt/bitnami/scripts/postgresql-repmgr/entrypoint.sh repmgr -f   /opt/bitnami/repmgr/conf/repmgr.conf cluster show
```



# 2. Prevent from deletion and automate protection deletioin using bash
```
2.1 manual labeling
kubectl apply -f vap.yaml
kubectl label pod postgresql-ha-postgresql-0 forbid-deletion=true --overwrite
k delete po postgresql-ha-postgresql-0

2.2 automatic labeling using bash
kubectl apply -f sts-check.yaml

2.3 postgresql switchover
k exec -it postgresql-ha-postgresql-1 -- bash
r cluster show
k exec -it postgresql-ha-postgresql-1 -- bash
r standby switchover -L DEBUG -v

2.4 redis switchover
k exec -it redis-ha2-server-0 -c sentinel -- redis-cli -p 26379
sentinel failover mymaster

2.5 automatic labeling and probes using kuberntes operator (GO)
#github label-operator
#github beastlex probes
```

# 3. limit IO for pods
```
#3.1 links
https://stackoverflow.com/questions/62908632/is-there-any-way-to-control-read-write-speed-or-iops-limit-per-pod
https://github.com/kubernetes/kubernetes/issues/92287

#3.2 create cgroup using package cgroup-tools
cgcreate -g io:app
lsblk | grep vda
#change 254:0 to your disk major:minor
cgset -r io.max="254:0 wbps=1048576" app
cgset -r cgroup.procs=$$ app
cgget -a -g io:app
lscgroup -g io:app

#3.3 clean
cgdelete io:app

#3.4 create cgroup
cd /sys/fs/cgroup/
mkdir -p mytest/app2
echo "+io" > cgroup.subtree_control
echo "+io" > mytest/cgroup.subtree_control
lsblk | grep vda
#change 254:0 to your disk major:minor
echo "254:0 wbps=1048576" > mytest/app2/io.max
echo $$ > mytest/app2/cgroup.procs

#3.5 clean 
?

#3.6 check
apt-get update ; apt-get install -y fio
cd /tmp;fio --randrepeat=1 --ioengine=libaio --direct=1 --gtod_reduce=1 --name=test --filename=test_file.tmp --bs=4k \
 --iodepth=64 --size=5Mb --readwrite=randwrite;rm test_file.tmp
dd if=/dev/zero of=/tmp/test.txt bs=5M count=1 oflag=sync,direct; rm /tmp/test.txt

#3.7 limit IO using docker
docker run --device-write-bps /dev/vda:1048576 -it ubuntu

#3.8 cgroup=host in container
docker run --help |grep cgroupns
docker run -it bensonyanger/nerdctl -- nerdctl run --help |grep cgroupns
cat /proc/8674/cgroup


#3.9 Automate limiting IO using bash
kubectl apply -f sts-check.yaml

#3.10 test
k run ubuntu --image=ubuntu -- bash -c "sleep 5000"

#3.11 automatic labeling and probes using kuberntes operator (GO)
#github label-operator
#github beastlex probes
```
