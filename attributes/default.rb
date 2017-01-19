include_attribute "elastic"
include_attribute "elasticsearch"

default.hopslog.user                     = node.elastic.user
default.hopslog.group                    = node.elastic.group



default.logstash.url                      = "#{node.download_url}/logstash-#{node.logstash.version}.tar.gz"
default.logstash.version                  = "2.3.4"
default.logstash.http.port                = ""

default.logstash.systemd                  = "true"
default.logstash.dir                      = "/srv"
default.logstash.home                     = node.logstash.dir + "/logstash-" + "#{node.logstash.version}"
default.logstash.base_dir                 = node.logstash.dir + "/logstash"
default.logstash.pid_file                 = "/tmp/logstash.pid"
