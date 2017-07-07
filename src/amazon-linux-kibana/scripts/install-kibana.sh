sudo rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch;
sudo sh -c 'echo "[kibana-5.x]" >> /etc/yum.repos.d/kibana.repo'
sudo sh -c 'echo "name=Kibana repository for 5.x packages" >> /etc/yum.repos.d/kibana.repo'
sudo sh -c 'echo "baseurl=https://artifacts.elastic.co/packages/5.x/yum" >> /etc/yum.repos.d/kibana.repo'
sudo sh -c 'echo "gpgcheck=1" >> /etc/yum.repos.d/kibana.repo'
sudo sh -c 'echo "gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch" >> /etc/yum.repos.d/kibana.repo'
sudo sh -c 'echo "enabled=1" >> /etc/yum.repos.d/kibana.repo'
sudo sh -c 'echo "autorefresh=1" >> /etc/yum.repos.d/kibana.repo'
sudo sh -c 'echo "type=rpm-md" >> /etc/yum.repos.d/kibana.repo'
sudo yum install kibana-$kibanaVersion -y
sudo rpm --query kibana-$kibanaVersion