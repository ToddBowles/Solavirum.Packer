sudo rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch
sudo sh -c 'echo "[elasticsearch-5.x]" >> /etc/yum.repos.d/elasticsearch.repo'
sudo sh -c 'echo "name=Elasticsearch repository for 5.x packages" >> /etc/yum.repos.d/elasticsearch.repo'
sudo sh -c 'echo "baseurl=https://artifacts.elastic.co/packages/5.x/yum" >> /etc/yum.repos.d/elasticsearch.repo'
sudo sh -c 'echo "gpgcheck=1" >> /etc/yum.repos.d/elasticsearch.repo'
sudo sh -c 'echo "gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch" >> /etc/yum.repos.d/elasticsearch.repo'
sudo sh -c 'echo "enabled=1" >> /etc/yum.repos.d/elasticsearch.repo'
sudo sh -c 'echo "autorefresh=1" >> /etc/yum.repos.d/elasticsearch.repo'
sudo sh -c 'echo "type=rpm-md" >> /etc/yum.repos.d/elasticsearch.repo'
sudo yum install elasticsearch-$elasticsearchVersion -y
sudo rpm --query elasticsearch-$elasticsearchVersion

sudo /usr/share/elasticsearch/bin/elasticsearch-plugin install discovery-ec2 -b || exit 1
sudo /usr/share/elasticsearch/bin/elasticsearch-plugin install mapper-size -b || exit 1
sudo /usr/share/elasticsearch/bin/elasticsearch-plugin install repository-s3 -b || exit 1