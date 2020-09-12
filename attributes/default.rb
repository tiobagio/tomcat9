default['tomcat']['download_url'] = "http://archive.apache.org/dist/tomcat/tomcat-9/v9.0.37/bin/apache-tomcat-9.0.37.tar.gz"
default['tomcat']['install_location'] = "/opt/tomcat"
default['tomcat']['port'] = 8080
default['tomcat']['ssl_port'] = 8443
default['tomcat']['ajp_port'] = 8008
default['tomcat']['java_options'] = "-Xmx128M"
default['tomcat']['user'] = "tomcat"
default['tomcat']['group'] = "tomcat"
default['tomcat']['autostart'] = "true"
default['tomcat']['server-name'] = "psmgw_com"

## ssl information
default['tomcat']['ssl_company_name'] = "chef.io"
default['tomcat']['ssl_organizational_unit_name'] = "sa"
default['tomcat']['ssl_country_name'] = "sg"
default['tomcat']['ssl_key_length'] = 4096
default['tomcat']['ssl_duration'] =  365

default['tomcat']['keystore'] = "/opt/tomcat/keystore" 
default['tomcat']['keystore_password'] = "changeit"


## guacamole
default['guacd']['user'] = "psmgwuser"
default['guacd']['group'] = "psmgwuser"