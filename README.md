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

# 4. VMs in clouds with high IO
```
#4.1 IOPS
#provider    cpu/mem/disk      random  write read
hetzner ax51 16/64/1Tbnvme              96K  301K
hetzner ax41 12/64/512nvme              76K  200k
hetzner ax41 separate 512nvme           107k 349k
hetzner ax41 separate 512nvme k8s+openebs+hostpath 63k 140k
hetzner vm 8/32/160                     36K  52.9K
selectel 8/64/480  sata                 34K  91К
selectel 12/128/480  sata               40k  106k
selectel vm hdd 4/8/100gb               6K   13K

aws gp3       (/mnt)    42k 42k
aws localssd  (/mnt2)   100k 170k

gcp balanced pd(/mnt)   71k  74K
gcp localssd   (/mnt2)  100k 180k

laptop                  71k  121k

#4.2 speed test
fio --randrepeat=1 --ioengine=libaio --direct=1 --gtod_reduce=1 --name=test --filename=test_file.tmp --bs=4k --iodepth=64 --size=100Mb --readwrite=randwrite;rm -f test_file.tmp
fio --randrepeat=1 --ioengine=libaio --direct=1 --gtod_reduce=1 --name=test --filename=test_file.tmp --bs=4k --iodepth=64 --size=100Mb --readwrite=randread;rm -f test_file.tmp

#4.3 IOPS in clouds
m6id.large           2CPU/8GB   108GB ssdlocal + 119GB gp3           $128
c3-standard-4-lssd   4CPU/16GB  375GB ssdlocal + 376GB balanced pd   $149


#4.4 aws
yum install -y fio mdadm
mkdir /mnt2 /mnt3
mkfs.ext4 /dev/nvme2n1
mkfs.ext4 /dev/nvme1n1
mount /dev/nvme2n1 /mnt
mount /dev/nvme1n1 /mnt2
cd /mnt/
umount /mnt /mnt2
mdadm --create --level=1 --raid-devices=2 /dev/md0 /dev/nvme1n1 --write-mostly /dev/nvme2n1
mkfs.ext4 /dev/md0
mount /dev/md0 /mnt3
cd /mnt3


#4.5 gcp
apt-get update ; apt-get install -y fio mdadm
mkdir /mnt2 /mnt3
mkfs.ext4 /dev/nvme1n1
mkfs.ext4 /dev/nvme0n2
mount /dev/nvme0n2 /mnt
mount /dev/nvme1n1 /mnt2
cd /mnt/
umount /mnt /mnt2
mdadm --create --level=1 --raid-devices=2 /dev/md0 /dev/nvme1n1 --write-mostly /dev/nvme0n2
mkfs.ext4 /dev/md0
mount /dev/md0 /mnt3
cd /mnt3



#4.5 gcp
apt-get update ; apt-get install -y fio mdadm
mkdir /mnt2 /mnt3
mkfs.ext4 /dev/nvme1n1
mkfs.ext4 /dev/nvme0n2
mount /dev/nvme0n2 /mnt
mount /dev/nvme1n1 /mnt2
cd /mnt/
umount /mnt /mnt2
mdadm --create --level=1 --raid-devices=2 /dev/md0 /dev/nvme1n1 --write-mostly /dev/nvme0n2
mkfs.ext4 /dev/md0
mount /dev/md0 /mnt3
cd /mnt3


#4.6 software raid in big enterprises
https://discord.com/blog/how-discord-supercharges-network-disks-for-extreme-low-latency
```
