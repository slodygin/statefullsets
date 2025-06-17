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



#2. Prevent from deletion and automate protection deletioin using bash
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

2.5 automatic labeling using GO
#github label-operator
#github beastlex probes
```
