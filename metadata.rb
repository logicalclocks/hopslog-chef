maintainer       "Jim Dowling"
maintainer_email "jdowling@kth.se"
name             "hopslog"
license          "Apache v2.0"
description      "Installs/Configures Logstash and Kibana for Hopsworks"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          "0.1.1"
source_url       "https://github.com/hopshadoop/hopslog-chef"

%w{ ubuntu debian centos }.each do |os|
  supports os
end

depends 'java'
depends 'kagent'
depends 'elastic'
depends 'kkafka'
depends 'hops'
depends 'hadoop_spark'

recipe "hopslog::install", "Installs Logstash and Kibana Server"
recipe "hopslog::default", "configures Logstash and Kibana Server"
recipe "hopslog::purge", "Deletes the Logstash and Kibana Servers"

attribute "hopslog/user",
          :description => "User to run Kibana server as",
          :type => "string"

attribute "hopslog/group",
          :description => "Group to run Kibana server as",
          :type => "string"

attribute "logstash/url",
          :description => "Url to hopslog binaries",
          :type => "string"

attribute "logstash/version",
          :description => "Version of logstash to use",
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

attribute "filebeat/read_logs",
          :description => "Path to log files read by filebeat (e.g., /srv/hops/domain1/logs/*.log)",
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
