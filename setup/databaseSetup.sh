source ~/volumes/setup/parameters.sh

printf "\nMariaDB database setup with Galera Cluster and Maxscale!\n \n"

echo "Creating datadir"
sudo mkdir ~/volumes/db1/datadir
sudo mkdir ~/volumes/db2/datadir
sudo mkdir ~/volumes/db3/datadir

echo "Making db1"
docker run -d \
--name db1 \
--publish "3306" \
--publish "4444" \
--publish "4567" \
--publish "4568" \
--add-host dbgc1:$db1_ip \
--add-host dbgc2:$db2_ip \
--add-host dbgc3:$db3_ip \
--add-host maxscale:$maxscale_ip \
--env MYSQL_ROOT_PASSWORD="$MYSQL_ROOT_PASSWORD" \
--env MYSQL_USER="$MYSQL_USER" \
--env MYSQL_PASSWORD="$MYSQL_PASSWORD" \
-v ~/volumes/db1/conf.d:/etc/mysql/mariadb.conf.d \
-v ~/volumes/db1/datadir:/var/lib/mysql \
mariadb/server:10.4

sleep 10

echo "Making db2"
docker run -d \
--name db2 \
--publish "3306" \
--publish "4444" \
--publish "4567" \
--publish "4568" \
--add-host dbgc1:$db1_ip \
--add-host dbgc2:$db2_ip \
--add-host dbgc3:$db3_ip \
--add-host maxscale:$maxscale_ip \
--env MYSQL_ROOT_PASSWORD="$MYSQL_ROOT_PASSWORD" \
--env MYSQL_USER="$MYSQL_USER" \
--env MYSQL_PASSWORD="$MYSQL_PASSWORD" \
-v ~/volumes/db2/conf.d:/etc/mysql/mariadb.conf.d \
-v ~/volumes/db2/datadir:/var/lib/mysql \
mariadb/server:10.4

sleep 10

echo "Making db3"
docker run -d \
--name db3 \
--publish "3306" \
--publish "4444" \
--publish "4567" \
--publish "4568" \
--add-host dbgc1:$db1_ip \
--add-host dbgc2:$db2_ip \
--add-host dbgc3:$db3_ip \
--add-host maxscale:$maxscale_ip \
--env MYSQL_ROOT_PASSWORD="$MYSQL_ROOT_PASSWORD" \
--env MYSQL_USER="$MYSQL_USER" \
--env MYSQL_PASSWORD="$MYSQL_PASSWORD" \
-v ~/volumes/db3/conf.d:/etc/mysql/mariadb.conf.d \
-v ~/volumes/db3/datadir:/var/lib/mysql \
mariadb/server:10.4

printf "\nInserting Safe to Bootstrap\n"

sleep 5

echo "safe_to_bootstrap: 1" >> ~/volumes/db1/datadir/grastate.dat
sleep 5

printf "\nRestarting db's\n"
docker restart db1 db2 db3

sleep 5

printf "\n"
echo "Making dbproxy"
docker run -d \
--name dbproxy \
--publish "3306:3306" \
--add-host dbgc1:$db1_ip \
--add-host dbgc2:$db2_ip \
--add-host dbgc3:$db3_ip \
--add-host maxscale:$maxscale_ip \
--env MYSQL_ROOT_PASSWORD="$MYSQL_ROOT_PASSWORD" \
--env MYSQL_USER="$MYSQL_USER" \
--env MYSQL_PASSWORD="$MYSQL_PASSWORD" \
-v ~/volumes/dbproxy/maxscale.cnf:/etc/maxscale.cnf \
mariadb/maxscale:latest

printf "\nGoing to sleep... zzzZZZzzz\n\n"
sleep 30


printf "Reading IPs from containers\n"
ip_web1=$(docker inspect -f "{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}" web1)
sleep 1
ip_web2=$(docker inspect -f "{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}" web2)
sleep 1
ip_web3=$(docker inspect -f "{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}" web3)
sleep 1
ip_lb=$(docker inspect -f "{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}" lb)
sleep 1
ip_db1=$(docker inspect -f "{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}" db1)
sleep 1
ip_db2=$(docker inspect -f "{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}" db2)
sleep 1
ip_db3=$(docker inspect -f "{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}" db3)
sleep 1
ip_dbproxy=$(docker inspect -f "{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}" dbproxy)
sleep 1

echo "Adding IPs to /etc/hosts"

echo $ip_web1
docker exec db1 bash -c 'echo '"$ip_web1"'      web1>> /etc/hosts'
sleep 1
echo $ip_web2
docker exec db1 bash -c 'echo '"$ip_web2"'      web2>> /etc/hosts'
sleep 1
echo $ip_web3
docker exec db1 bash -c 'echo '"$ip_web3"'      web3>> /etc/hosts'
sleep 1
echo $ip_lb
docker exec db1 bash -c 'echo '"$ip_lb"'        lb>> /etc/hosts'
sleep 1
echo $ip_db1
docker exec db1 bash -c 'echo '"$ip_db1"'       db1>> /etc/hosts'
sleep 1
echo $ip_db2
docker exec db1 bash -c 'echo '"$ip_db2"'       db2>> /etc/hosts'
sleep 1
echo $ip_db3
docker exec db1 bash -c 'echo '"$ip_db3"'       db3>> /etc/hosts'
sleep 1
echo $ip_dbproxy
docker exec db1 bash -c 'echo '"$ip_dbproxy"'   maxscale>> /etc/hosts'

printf "\nChecking cluster size!\n \n"

echo "Checking cluster size"
docker exec db1 bash -c 'mysql -uroot -e "show status like \"wsrep_cluster_size\""'
echo "It should be cluster size 3"

sleep 10

printf "\nEngaging MySQL setup\n"
echo "MySQL setup for db-servers"
sleep 2
docker exec db1 bash -c 'mysql -uroot -p --password=rootpass -e "create user \"dats44\"@\"%\" identified by \"sure caught drop\""'
sleep 2
docker exec db1 bash -c 'mysql -uroot -p --password=rootpass -e "grant select on mysql.user to \"dats44\"@\"%\""'
sleep 2

echo "MySQL setup for MaxscaleUser"
docker exec db1 bash -c 'mysql -uroot -p --password=rootpass -e "create user \"maxscaleuser\"@\"172.17.0.9\" identified by \"sure caught drop\""'
sleep 2
docker exec db1 bash -c 'mysql -uroot -p --password=rootpass -e "grant select on mysql.user to \"maxscaleuser\"@\"172.17.0.9\""'
sleep 2
docker exec db1 bash -c 'mysql -uroot -p --password=rootpass -e "grant select on mysql.db to \"maxscaleuser\"@\"172.17.0.9\""'
sleep 2
docker exec db1 bash -c 'mysql -uroot -p --password=rootpass -e "grant select on mysql.tables_priv to \"maxscaleuser\"@\"172.17.0.9\""'
sleep 2
docker exec db1 bash -c 'mysql -uroot -p --password=rootpass -e "grant show databases on *.* to \"maxscaleuser\"@\"172.17.0.9\""'


sleep 5
printf "\nRestarting dbproxy\n"
docker restart dbproxy

sleep 5

printf "\nChecking if servers are online\n"
docker exec dbproxy maxctrl list servers

printf "\ncopying studentinfo to db containers\n"
docker cp ~/volumes/webapp/database/studentinfo-db.sql db1:/studentinfo-db.sql
sleep 2
echo "Checking the databases"
docker exec db1 bash -c 'mysql -uroot -e "source studentinfo-db.sql"'
sleep 2 
docker exec db1 bash -c 'mysql -uroot -e "show DATABASES"'

echo "Giving the nesassary privileges to MySQL user"
sleep 2
docker exec db1 bash -c 'mysql -uroot -p --password=rootpass -e "grant UPDATE on studentinfo.* to \"maxscaleuser\"@\"172.17.0.9\""'
sleep 2
docker exec db1 bash -c 'mysql -uroot -p --password=rootpass -e "grant DELETE on studentinfo.* to \"maxscaleuser\"@\"172.17.0.9\""'
sleep 2
docker exec db1 bash -c 'mysql -uroot -p --password=rootpass -e "grant INSERT on studentinfo.* to \"maxscaleuser\"@\"172.17.0.9\""'

sleep 2
docker exec db1 bash -c 'mysql -uroot -p --password=rootpass -e "grant UPDATE on studentinfo.* to \"dats44\"@\"%\""'
sleep 2
docker exec db1 bash -c 'mysql -uroot -p --password=rootpass -e "grant DELETE on studentinfo.* to \"dats44\"@\"%\""'
sleep 2
docker exec db1 bash -c 'mysql -uroot -p --password=rootpass -e "grant INSERT on studentinfo.* to \"dats44\"@\"%\""'
sleep 2
docker exec db1 bash -c 'mysql -uroot -e "grant select on studentinfo.* to \"dats44\"@\"%\""'

printf "\nFinal check \n \n"

docker exec db1 bash -c 'mysql -uroot -e "show DATABASES"'
docker exec db1 bash -c 'mysql -uroot -e "show status like \"wsrep_cluster_size\""'
docker exec dbproxy maxctrl list servers
