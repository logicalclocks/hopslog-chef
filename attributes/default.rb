include_attribute "hops"
include_attribute "elastic"
include_attribute "elasticsearch"
include_attribute "kagent"

default['hopslog']['user']                      = node['install']['user'].empty? ? node['elastic']['user'] : node['install']['user']
default['hopslog']['group']                     = node['install']['user'].empty? ? node['elastic']['group'] : node['install']['user']
default['hopslog']['dir']                       = node['install']['dir'].empty? ? "/srv" : node['install']['dir']
default['hopslog']['user-home']                 = "/home/#{node['hopslog']['user']}"

#
# Logstash
#
default['logstash']['version']                               = "7.2.0"
default['logstash']['url']                                   = "#{node['download_url']}/logstash-oss-#{node['logstash']['version']}.tar.gz"
default['logstash']['beats']['spark_port']                   = "5044"
default['logstash']['beats']['serving_port']                 = "5046"
default['logstash']['beats']['beamjobserverlocal_port']      = "5048"
default['logstash']['beats']['beamjobservercluster_port']    = "5049"
default['logstash']['beats']['beamsdkworker_port']           = "5050"
default['logstash']['beats']['python_jobs_port']             = "5051"
default['logstash']['beats']['jupyter_port']                 = "5052"
default['logstash']['http']['port']                          = "9600"

default['logstash']['systemd']                  = "true"
default['logstash']['home']                     = node['hopslog']['dir'] + "/logstash-" + "#{node['logstash']['version']}"
default['logstash']['base_dir']                 = node['hopslog']['dir'] + "/logstash"
default['logstash']['pid_file']                 = "/tmp/logstash.pid"
default['logstash']['bin_dir']                  = node['logstash']['base_dir'] + "/bin"
default['logstash']['consul_dir']               = node['logstash']['bin_dir'] + "/consul"
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
default['kibana']['pid_file']                   = "/tmp/kibana.pid"

#
# Filebeat

default['filebeat']['version']                  = "7.2.0"
default['filebeat']['url']                      = "#{node['download_url']}/filebeat-oss-#{node['filebeat']['version']}-linux-x86_64.tar.gz"
default['filebeat']['home']                     = node['hopslog']['dir'] + "/filebeat-" + "#{node['filebeat']['version']}-linux-x86_64"
default['filebeat']['base_dir']                 = node['hopslog']['dir'] + "/filebeat"
default['filebeat']['systemd']                  = "true"
default['filebeat']['pid_dir']                  = "/tmp"
default['filebeat']['port']                     = "5000"

default['filebeat']['spark_read_logs']           = node['hops']['base_dir'] + "/logs/userlogs/**/"
default['filebeat']['beamjobservercluster_logs'] = node['hops']['base_dir'] + "/logs/userlogs/**/beamjobserver-*.log"
default['filebeat']['beamjobserverlocal_logs']   = node['hopslog']['dir'] + "/staging/private_dirs/*/beamjobserver-*.log"
default['filebeat']['beamsdkworker_logs']        = node['hops']['base_dir'] + "/logs/userlogs/**/beamsdkworker-*.log"
default['filebeat']['beam_logs']                 = %w[beamjobservercluster beamjobserverlocal beamsdkworker]
default['filebeat']['skip']                      = "true"

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
