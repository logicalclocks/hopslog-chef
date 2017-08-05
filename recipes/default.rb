include_recipe "hopslog::_logstash"
include_recipe "hopslog::_kibana"

if node['filebeat']['skip'].eql?('false') 
     include_recipe "hopslog::_filebeat"
end
