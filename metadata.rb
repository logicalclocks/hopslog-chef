maintainer       "Jim Dowling"
maintainer_email "jdowling@kth.se"
name             "hopslog"
license          "Apache v2.0"
description      "Installs/Configures Logstash and Kibana for Hopsworks"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          "2.5.0"
source_url       "https://github.com/hopshadoop/hopslog-chef"

%w{ ubuntu debian centos }.each do |os|
  supports os
end

depends 'elasticsearch', '~> 4.0.0'
depends 'kagent'
depends 'elastic'
depends 'kkafka'
depends 'conda'
depends 'hops'
depends 'consul'
depends 'java'

recipe "hopslog::install", "Installs Logstash and Kibana Server"
recipe "hopslog::default", "configures Logstash and Kibana Server"
recipe "hopslog::purge", "Deletes the Logstash and Kibana Servers"

attribute "hopslog/user",
          :description => "User to run Kibana server as",
          :type => "string"

attribute "hopslog/group",
          :description => "Group to run Kibana server as",
          :type => "string"

attribute "hopslog/user-home",
          :description => "Home directory of hopslog user",
          :type => "string"

attribute "logstash/url",
          :description => "Url to hopslog binaries",
          :type => "string"

attribute "logstash/version",
          :description => "Version of logstash to use",
          :type => "string"

attribute "logstash/beats/spark_port",
          :description => "Filebeat port for spark streaming logs",
          :type => "string"

attribute "logstash/beats/serving_port",
          :description => "Filebeat port for serving logs",
          :type => "string"

attribute "logstash/beats/python_jobs_port",
          :description => "Filebeat port for python jobs logs",
          :type => "string"

attribute "logstash/beats/jupyter_port",
          :description => "Filebeat port for jupyter server logs",
          :type => "string"

attribute "kibana/url",
          :description => "Url to hopslog binaries",
          :type => "string"

attribute "hopslog/dir",
          :description => "Parent directory to install logstash and kibana in (/srv is default)",
          :type => "string"

attribute "logstash/pid_file",
          :description => "Change the location for the pid_file.",
          :type => "string"

attribute "filebeat/url",
          :description => "Url to filebeat binaries",
          :type => "string"

attribute "filebeat/version",
          :description => "Filebeat version",
          :type => "string"

attribute "filebeat/spark_read_logs",
          :description => "Path to log files read by filebeat for spark (e.g., /srv/hops/domain1/logs/*.log)",
          :type => "string"

attribute "filebeat/skip",
          :description => "Dont start filebeat. Default: 'true'. Set to 'false' to start filebeat",
          :type => "string"

attribute "install/dir",
          :description => "Set to a base directory under which we will install.",
          :type => "string"

attribute "install/user",
          :description => "User to install the services as",
          :type => "string"

attribute "hopslog/private_ips",
          :description => "Set ip addresses",
          :type => "array"

attribute "hopslog/public_ips",
          :description => "Set ip addresses",
          :type => "array"

attribute "logstash/managed_cloud/batch_delay",
          :description => "the batch delay to send logs to the managed cloud platform",
          :type => "string"

attribute "logstash/managed_cloud/batch_size",
          :description => "the batch size to send logs to the managed cloud platform",
          :type => "string"

attribute "logstash/managed_cloud/max_size",
          :description => "the log message max size to send logs to the managed cloud platform",
          :type => "string"

attribute "logstash/pipeline/workers",
          :description => "Number of threads for each logstash pipeline - default 1",
          :type => "string"
