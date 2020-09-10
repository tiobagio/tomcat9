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

bash 'chmod keystore' do
  code <<-EOH
  chown -R tomcat:tomcat "#{node['tomcat']['install_location']}"
  EOH
  action :run
end

# Generate self-signed SSL certificate unless the user has provided one
if (node['tomcat']['ssl_certificate'].nil? &&
    node['tomcat']['ssl_certificate_key'].nil?)

   ssl_keyfile = File.join(node['tomcat']['install_location'], "#{node['tomcat']['server-name']}.key")
   ssl_crtfile = File.join(node['tomcat']['install_location'], "#{node['tomcat']['server-name']}.crt")

   server_name = node['tomcat']['server-name']
#   server_name_type = if OmnibusHelper.is_ip?(server_name)
#                        "IP"
#                      else
#                        "DNS"
#                      end

#default['tomcat']['server-name'] = "pgws_com"

## ssl information
#default['tomcat']['ssl_company_name'] = "chef.io"
#default['tomcat']['ssl_organizational_unit_name'] = "sa"
#default['tomcat']['ssl_country_name'] = "sg"
#default['tomcat']['ssl_key_length'] = 4096
#default['tomcat']['ssl_duration'] =  365
# create self-signed certificate
   openssl_x509_certificate ssl_crtfile do
     country  node['tomcat']['ssl_country_name']
     city     node['tomcat']['ssl_country_name']
     state    node['tomcat']['ssl_country_name']
     org      node['tomcat']['ssl_company_name']
     org_unit node['tomcat']['ssl_organizational_unit_name']
     common_name server_name

     key_length node['tomcat']['ssl_key_length']
#     subject_alt_name [ "#{server_name_type}:#{server_name}" ]
     owner node['tomcat']['user']
     group node['tomcat']['group']
     ca_key_pass "changeit"
     ca_cert_file ssl_crtfile
     ca_key_file  ssl_keyfile
     mode '0600'
   end

  node.default['tomcat']['ssl_certificate'] = ssl_crtfile
  node.default['tomcat']['ssl_certificate_key'] = ssl_keyfile
end

# The cert and key must be readable by the tomcat user
#file node['tomcat']['ssl_certificate'] do
#  owner  node['tomcat']['user']
#  group  node['tomcat']['group']
#  mode '0600'
#end

#file node['tomcat']['ssl_certificate_key'] do
#  owner  node['tomcat']['user']
#  group  node['tomcat']['group']
#  mode '0600'
#end

bash 'save original conf/server/xml' do
  user node['tomcat']['user']
  group node['tomcat']['group']
  cwd node['tomcat']['install_location']
  code <<-EOH
    mv conf/server.xml conf/server.xml.orig
  EOH
  action :run
end

bash 'create a keystore' do
  user node['tomcat']['user']
  group node['tomcat']['group']
  code <<-EOH  
  keytool -genkey -noprompt \
    -alias tomcat \
    -dname "CN=tech.gov.sg, OU=gcc, O=gcc, L=SG, S=SG, C=SG" \
    -keystore "#{node['tomcat']['keystore']}" \
    -storepass "#{node['tomcat']['keystore_password']}" \
    -keypass "#{node['tomcat']['keystore_password']}"
  EOH
  action :run
end


bash 'import tomcat key to keystore' do
  user node['tomcat']['user']
  group node['tomcat']['group']
  cwd node['tomcat']['install_location']
  code <<-EOH
  keytool -importcert -alias selfsignkey -keystore "#{node['tomcat']['keystore']}" \
  -trustcacerts -file "#{ssl_crtfile}" -storepass "#{node['tomcat']['keystore_password']}" -noprompt
  EOH
  action :run
end



template "#{node['tomcat']['install_location']}/conf/server.xml" do
  source 'server.xml.erb'
  owner node['tomcat']['user']
  mode '0644'
end

template "/etc/systemd/system/tomcat.service" do
  source 'tomcat.service.erb'
  owner 'root'
  mode '0644'
end

service 'tomcat' do
  action [:enable, :start]
end

