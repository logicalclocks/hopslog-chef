include_attribute "elastic"
include_attribute "elasticsearch"
include_attribute "kagent"
include_attribute "kkafka"

default.hopslog.user                      = node.install.user.empty? ? node.elastic.user : node.install.user
default.hopslog.group                     = node.install.user.empty? ? node.elastic.group : node.install.user
default.hopslog.dir                       = node.install.dir.empty? ? "/srv" : node.install.dir

#
# Logstash
#
default.logstash.version                  = "2.4.1"
default.logstash.url                      = "#{node.download_url}/logstash-#{node.logstash.version}.tar.gz"
default.logstash.http.port                = ""

default.logstash.systemd                  = "true"
default.logstash.home                     = node.hopslog.dir + "/logstash-" + "#{node.logstash.version}"
default.logstash.base_dir                 = node.hopslog.dir + "/logstash"
default.logstash.pid_file                 = "/tmp/logstash.pid"


#
# Kibana
#
default.kibana.version                    = "4.6.4"
default.kibana.url                        = "#{node.download_url}/kibana-#{node.kibana.version}-linux-x86_64.tar.gz"
default.kibana.port                       = "5601"

default.kibana.systemd                    = "true"
default.kibana.home                       = node.hopslog.dir + "/kibana-" + "#{node.kibana.version}-linux-x86_64"
default.kibana.base_dir                   = node.hopslog.dir + "/kibana"
default.kibana.log_dir                    = node.kibana.base_dir + "/log"
default.kibana.pid_file                   = "/tmp/kibana.pid"
default.kibana.default_index		  = "hopsdefault"

#
# Filebeat

default.filebeat.version                  = "5.2.0"
default.filebeat.url                      = "#{node.download_url}/filebeat-#{node.filebeat.version}-linux-x86_64.tar.gz"
default.filebeat.home                     = node.hopslog.dir + "/filebeat-" + "#{node.filebeat.version}-linux-x86_64"
default.filebeat.base_dir                 = node.hopslog.dir + "/filebeat"
default.filebeat.systemd                  = "true"
default.filebeat.pid_file                 = "/tmp/filebeat.pid"

default.filebeat.read_logs                = ""

default.filebeat.skip                     = "true"
