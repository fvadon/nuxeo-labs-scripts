#!/bin/bash

# To be run as root (sudo), install Nuxeo FT, Java 8 and ES locally.
# Configure a cluster for Nuxeo

# Increase open files limit
echo '*       soft    nofile      4096' >> /etc/security/limits.conf
echo '*       hard    nofile      8192' >> /etc/security/limits.conf

# Add the nuxeo repository to the repository list
echo "-- Adding Nuxeo repo"
code=$(lsb_release -cs)
echo "deb http://apt.nuxeo.org/ $code releases" > /etc/apt/sources.list.d/nuxeo.list
echo "deb http://apt.nuxeo.org/ $code fasttracks" >> /etc/apt/sources.list.d/nuxeo.list

# Register the nuxeo key
wget -q -O- http://apt.nuxeo.org/nuxeo.key | apt-key add -

# Pre-accept Sun Java license & set Nuxeo options
echo nuxeo nuxeo/bind-address select 127.0.0.1 | debconf-set-selections
echo nuxeo nuxeo/http-port select 8080 | debconf-set-selections
echo nuxeo nuxeo/database select Autoconfigure PostgreSQL | debconf-set-selections

# Upgrade packages and install ssh, vim
echo "-- upgrade packages and install ssh"
export DEBIAN_FRONTEND=noninteractive
locale-gen en_US.UTF-8
aptitude update
aptitude -q -y safe-upgrade
aptitude -q -y install apache2
echo "Please wait a few minutes for you instance installation to complete" > /var/www/index.html
aptitude -q -y install openssh-server openssh-client vim

# Install Java 8
echo "-- Java 8"
aptitude -q -y install openjdk-7-jdk
wget -q -O/tmp/jdk-8-linux-x64.tgz --no-check-certificate --header 'Cookie: oraclelicense=accept-securebackup-cookie' 'http://download.oracle.com/otn-pub/java/jdk/8u40-b26/jdk-8u40-linux-x64.tar.gz'
tar xzf /tmp/jdk-8-linux-x64.tgz -C /usr/lib/jvm
rm /tmp/jdk-8-linux-x64.tgz
ln -s /usr/lib/jvm/jdk1.8.0_40 /usr/lib/jvm/java-8

update-alternatives --install /usr/bin/java java /usr/lib/jvm/java-8/jre/bin/java 1081
update-alternatives --install /usr/bin/javaws javaws /usr/lib/jvm/java-8/jre/bin/javaws 1081
update-alternatives --install /usr/bin/jexec jexec /usr/lib/jvm/java-8/lib/jexec 1081

update-alternatives --set java /usr/lib/jvm/java-8/jre/bin/java
update-alternatives --set javaws /usr/lib/jvm/java-8/jre/bin/java
update-alternatives --set jexec /usr/lib/jvm/java-8/lib/jexec

# Install nuxeo 
echo"-- Install Nuxeo"
aptitude -q -y install nuxeo

# Update some defaults
update-alternatives --set editor /usr/bin/vim.basic

# Install ES
echo"-- Install ES"

wget -qO - https://packages.elastic.co/GPG-KEY-elasticsearch | apt-key add -
echo "deb http://packages.elastic.co/elasticsearch/1.5/debian stable main" | tee -a /etc/apt/sources.list
apt-get update && apt-get install elasticsearch
update-rc.d elasticsearch defaults 95 10

# Config ES for Nuxeo 
echo"-- Install Custom config for ES and Nuxeo"
sed -i '$a #Param from FVN install script' /etc/elasticsearch/elasticsearch.yml
sed -i '$a network.host: 127.0.0.1' /etc/elasticsearch/elasticsearch.yml # Restricting ES to access to local
sed -i '$a cluster.name: nuxeoescluster' /etc/elasticsearch/elasticsearch.yml # Custom ES cluster

# Config Nuxeo for ES
sed -i '$a #Param from FVN install script' /etc/nuxeo/nuxeo.conf
sed -i '$a elasticsearch.addressList=localhost:9300' /etc/nuxeo/nuxeo.conf
sed -i '$a elasticsearch.clusterName=nuxeoescluster' /etc/nuxeo/nuxeo.conf
sed -i '$a audit.elasticsearch.enabled=false' /etc/nuxeo/nuxeo.conf #Disable audit log in ES for now

echo "-- Start Nuxeo and ES"
service elasticsearch start
service nuxeo restart

echo"-- Finished"