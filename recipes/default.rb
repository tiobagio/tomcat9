#
# Cookbook:: tomcat9
# Recipe:: default
#
# Copyright:: 2020, The Authors, All Rights Reserved.

include_recipe 'java'

tmp_path = Chef::Config[:file_cache_path]

group 'tomcat' do
  comment	'tomcat group'
  group_name    node['tomcat']['group']
  action 	:create
end

user "#node['tomcat']['user']" do
  comment 'tomcat user'
  gid    node['tomcat']['group']
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
  cwd node['tomcat']['install_location']
  code <<-EOH
    tar -zxvf #{tmp_path}/tomcat.tar.gz --strip 1
  EOH
  action :run
end

# Generate self-signed SSL certificate unless the user has provided one
if (node['tomcat']['ssl_certificate'].nil? &&
    node['tomcat']['ssl_certificate_key'].nil?)

   ssl_keyfile = File.join(node['tomcat']['install_location'], "#{node['tomcat']['server_name']}.key")
   ssl_crtfile = File.join(node['tomcat']['install_location'], "#{node['tomcat']['server_name']}.crt")

   server_name = node['tomcat']['server_name']
#   server_name_type = if OmnibusHelper.is_ip?(server_name)
#                        "IP"
#                      else
#                        "DNS"
#                      end

   openssl_x509 ssl_crtfile do
     common_name server_name
     org node['tomcat']['ssl_company_name']
     org_unit node['tomcat']['ssl_organizational_unit_name']
     country node['tomcat']['ssl_country_name']
     key_length node['tomcat']['ssl_key_length']
     expire node['tomcat']['ssl_duration']
#     subject_alt_name [ "#{server_name_type}:#{server_name}" ]
     owner node['tomcat']['user']
     group node['tomcat']['group']
     mode '0600'
   end

  node.default['tomcat']['ssl_certificate'] = ssl_crtfile
  node.default['tomcat']['ssl_certificate_key'] = ssl_keyfile
end

# The cert and key must be readable by the opscode user since rabbitmq also reads it
file node['tomcat']['ssl_certificate'] do
  owner  node['tomcat']['user']
  group  node['tomcat']['group']
  mode '0600'
end

file node['tomcat']['ssl_certificate_key'] do
  owner  node['tomcat']['user']
  group  node['tomcat']['group']
  mode '0600'
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

