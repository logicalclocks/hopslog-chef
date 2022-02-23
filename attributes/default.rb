include_attribute "hops"
include_attribute "elastic"
include_attribute "elasticsearch"
include_attribute "kagent"

default['hopslog']['user']                      = node['install']['user'].empty? ? node['elastic']['user'] : node['install']['user']
default['hopslog']['user_id']                   = node['elastic']['user_id']
default['hopslog']['group']                     = node['install']['user'].empty? ? node['elastic']['group'] : node['install']['user']
default['hopslog']['group_id']                  = node['elastic']['group_id']
default['hopslog']['dir']                       = node['install']['dir'].empty? ? "/srv" : node['install']['dir']
default['hopslog']['user-home']                 = "/home/#{node['hopslog']['user']}"

#
# Logstash
#
default['logstash']['version']                               = "7.2.0"
default['logstash']['url']                                   = "#{node['download_url']}/logstash-oss-#{node['logstash']['version']}.tar.gz"
default['logstash']['beats']['spark_port']                   = "5044"
default['logstash']['beats']['serving_port']                 = "5046"
default['logstash']['beats']['python_jobs_port']             = "5051"
default['logstash']['beats']['jupyter_port']                 = "5052"
default['logstash']['beats']['services_port']                = "5053"
default['logstash']['http']['port']                          = "9600"

default['logstash']['systemd']                  = "true"
default['logstash']['home']                     = node['hopslog']['dir'] + "/logstash-" + "#{node['logstash']['version']}"
default['logstash']['base_dir']                 = node['hopslog']['dir'] + "/logstash"
default['logstash']['pid_file']                 = "/tmp/logstash.pid"
default['logstash']['bin_dir']                  = node['logstash']['base_dir'] + "/bin"
default['logstash']['consul_dir']               = node['logstash']['bin_dir'] + "/consul"
default['logstash']['logs_dir']                 = "#{node['logstash']['base_dir']}/log"
default['logstash']['data_dir']                 = "#{node['logstash']['base_dir']}/data"

# Data volume directories
default['logstash']['data_volume']['root_dir']  = "#{node['data']['dir']}/logstash"
default['logstash']['data_volume']['logs_dir']  = "#{node['logstash']['data_volume']['root_dir']}/log"
default['logstash']['data_volume']['data_dir']  = "#{node['logstash']['data_volume']['root_dir']}/data"

default['logstash']['pipeline']['workers']       = 1

#
# Kibana
#
default['kibana']['version']                    = "7.2.0"
default['kibana']['url']                        = "#{node['download_url']}/kibana-oss-#{node['kibana']['version']}-linux-x86_64.tar.gz"
default['kibana']['port']                       = "5601"

default['kibana']['systemd']                    = "true"
default['kibana']['home']                       = node['hopslog']['dir'] + "/kibana-" + "#{node['kibana']['version']}-linux-x86_64"
default['kibana']['base_dir']                   = node['hopslog']['dir'] + "/kibana"
default['kibana']['log_dir']                    = node['kibana']['base_dir'] + "/log"
default['kibana']['data_dir']                   = "#{node['kibana']['base_dir']}/data"
default['kibana']['pid_file']                   = "/tmp/kibana.pid"

# Data volume directories
default['kibana']['data_volume']['root_dir']    = "#{node['data']['dir']}/kibana"
default['kibana']['data_volume']['log_dir']     = "#{node['kibana']['data_volume']['root_dir']}/log"
default['kibana']['data_volume']['data_dir']    = "#{node['kibana']['data_volume']['root_dir']}/data"

#
# Filebeat

default['filebeat']['version']                  = "7.2.0"
default['filebeat']['url']                      = "#{node['download_url']}/filebeat-oss-#{node['filebeat']['version']}-linux-x86_64.tar.gz"
default['filebeat']['home']                     = node['hopslog']['dir'] + "/filebeat-" + "#{node['filebeat']['version']}-linux-x86_64"
default['filebeat']['base_dir']                 = node['hopslog']['dir'] + "/filebeat"
default['filebeat']['logs_dir']                 = "#{node['filebeat']['base_dir']}/log"
default['filebeat']['data_dir']                 = "#{node['filebeat']['base_dir']}/data"
default['filebeat']['systemd']                  = "true"
default['filebeat']['pid_dir']                  = "/tmp"
default['filebeat']['port']                     = "5000"

# Data volume directories
default['filebeat']['data_volume']['root_dir']  = "#{node['data']['dir']}/filebeat"
default['filebeat']['data_volume']['logs_dir']  = "#{node['filebeat']['data_volume']['root_dir']}/log"
default['filebeat']['data_volume']['data_dir']  = "#{node['filebeat']['data_volume']['data_dir']}/data"

default['filebeat']['spark_read_logs']          = node['hops']['base_dir'] + "/logs/userlogs/**/"

default['logstash']['service_index']            = ".services-"
default['kibana']['service_index_pattern']      = ".services-*"

default['hopslog']['private_ips']         = ['10.0.2.15']
default['hopslog']['public_ips']          = ['10.0.2.15']

# Kibana Opendistro Security plugin
default['kibana']['opendistro_security']['url']                                   = "#{node['download_url']}/opendistro_security_kibana_plugin-#{node['elastic']['opendistro']['version']}.zip"
default['kibana']['opendistro_security']['https']['enabled']                      = "true"
default['kibana']['opendistro_security']['multitenancy']['global']['enabled']     = "false"
default['kibana']['opendistro_security']['multitenancy']['private']['enabled']    = "true"
default['kibana']['opendistro_security']['cookie']['ttl']                         = node['elastic']['opendistro_security']['jwt']['exp_ms'].to_i
# the session ttl time is set to be twice the time the cookie ttl time, in order to solve the session expiry issue in kibana_addr
# https://github.com/opendistro-for-elasticsearch/security-kibana-plugin/issues/31
default['kibana']['opendistro_security']['session']['ttl']                        = 2 * node['elastic']['opendistro_security']['jwt']['exp_ms'].to_i
default['kibana']['opendistro_security']['session']['keepalive']                  = "true"

#managed cloud
default['logstash']['managed_cloud']['batch_delay']                               = "2000"
default['logstash']['managed_cloud']['batch_size']                                = "50"
default['logstash']['managed_cloud']['max_size']                                  = "4096"
