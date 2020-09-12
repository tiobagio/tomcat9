#
# Cookbook:: tomcat9
# Recipe:: default
#
# Copyright:: 2020, The Authors, All Rights Reserved.

#include_recipe 'java'

tmp_path = Chef::Config[:file_cache_path]

#pre-requisities
package 'cairo' 
package 'libpng' 
package 'libjpeg' 
package 'java' 
package 'java-devel' 
package 'openssl'

ENV['CATALINA_HOME'] = node['tomcat']['install_location']

group node['tomcat']['group'] do
  comment	'tomcat group'
  action 	:create
end

user node['tomcat']['user'] do
  comment 'tomcat user'
  gid   node['tomcat']['group']
  home 	node['tomcat']['install_location']
  shell '/bin/bash'
  action :create
end

remote_file "#{tmp_path}/tomcat.tar.gz" do
  source "http://archive.apache.org/dist/tomcat/tomcat-9/v9.0.37/bin/apache-tomcat-9.0.37.tar.gz" 
  owner node['tomcat']['user']
  group node['tomcat']['group']
  mode '0644'
  action :create
end

directory node['tomcat']['install_location'] do
  owner node['tomcat']['user']
  group node['tomcat']['group']
  mode '0755'
  action :create
end

bash 'Extract tomcat archive' do
  user node['tomcat']['user']
  group node['tomcat']['group']
  cwd node['tomcat']['install_location']
  code <<-EOH
    tar -zxvf #{tmp_path}/tomcat.tar.gz --strip 1
  EOH
  action :run
end

bash 'chmod tomcat install directory' do
  code <<-EOH
  chown -R tomcat:tomcat "#{node['tomcat']['install_location']}"
  EOH
  action :run
end

# create self-signed certificate
if (node['tomcat']['ssl_certificate'].nil? &&
  node['tomcat']['ssl_certificate_key'].nil?)

 ssl_keyfile = File.join(node['tomcat']['install_location'], "#{node['tomcat']['server-name']}.key")
 ssl_crtfile = File.join(node['tomcat']['install_location'], "#{node['tomcat']['server-name']}.pem")

 ## ssl information
#default['tomcat']['ssl_company_name'] = "chef.io"
#default['tomcat']['ssl_organizational_unit_name'] = "sa"
#default['tomcat']['ssl_country_name'] = "sg"
#default['tomcat']['ssl_key_length'] = 4096
#default['tomcat']['ssl_duration'] =  365
# create self-signed certificate

#openssl req -x509 -newkey rsa:4096 -keyout /tmp/tkey.pem -out /tmp/tcert.pem -days 365 \
# -subj "/C=SG/ST=Singapore/L=Singapore/O=Chef Software/OU=SA Department/CN=example.com" -nodes
#default['tomcat']['install_location'] = "/opt/tomcat"

openssl_x509_certificate ssl_crtfile do
  country  node['tomcat']['ssl_country_name']
  city     node['tomcat']['ssl_country_name']
  state    node['tomcat']['ssl_country_name']
  org      node['tomcat']['ssl_company_name']
  org_unit node['tomcat']['ssl_organizational_unit_name']
  common_name node['tomcat']['server-name']
  key_length node['tomcat']['ssl_key_length']
#     subject_alt_name [ "#{server_name_type}:#{server_name}" ]
  owner node['tomcat']['user']
  group node['tomcat']['group']
  ca_key_pass "changeit"
  mode '0600'
end

  node.default['tomcat']['ssl_certificate'] = ssl_crtfile
  node.default['tomcat']['ssl_certificate_key'] = ssl_keyfile   
end

bash 'save original conf/server/xml' do
  user node['tomcat']['user']
  group node['tomcat']['group']
  cwd node['tomcat']['install_location']
  code <<-EOH
    mv conf/server.xml conf/server.xml.orig
  EOH
  action :run
end

# keytool -genkey -noprompt -alias tomcat -keyalg RSA -keystore /opt/tomcat/keystore \
# -dname "CN=tech.gov.sg, OU=gcc, O=gcc, L=SG, S=SG, C=SG"  -storepass changeit -keypass changeit

bash 'create a keystore' do
  user node['tomcat']['user']
  group node['tomcat']['group']
  code <<-EOH  
  keytool -genkey -noprompt \
    -alias tomcat \
    -keyalg RSA \
    -dname \"CN=tech.gov.sg, OU=gcc, O=gcc, L=SG, S=SG, C=SG\" \
    -keystore "#{node['tomcat']['keystore']}" \
    -storepass "#{node['tomcat']['keystore_password']}" \
    -keypass "#{node['tomcat']['keystore_password']}"
  EOH
  action :run
end

#keytool -import -alias toldkey -keystore /opt/tomcat/keystore -trustcacerts -file /opt/tomcat/psmgw_com.crt -storepass changeit -noprompt
bash 'import tomcat key to keystore' do
  user node['tomcat']['user']
  group node['tomcat']['group']
  cwd node['tomcat']['install_location']
  code <<-EOH
  keytool -import -alias selfsignkey -keystore "#{node['tomcat']['keystore']}" \
  -trustcacerts -file "#{ssl_crtfile}" -storepass "#{node['tomcat']['keystore_password']}" -noprompt
  EOH
  action :run
end

# configure server.xml
template "/opt/tomcat/conf/server.xml" do
  source 'server.xml.erb'
  owner node['tomcat']['user']
  mode '0644'
end

# configure tomat service
template "/etc/systemd/system/tomcat.service" do
  source 'tomcat.service.erb'
  owner 'root'
  mode '0644'
end

service 'tomcat' do
  action [:enable, :start]
end

#include_recipe "tomcat9::guacd"