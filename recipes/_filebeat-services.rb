file "#{node['filebeat']['base_dir']}/filebeat.xml" do
  action :delete
end

group node['logger']['group'] do
  gid node['logger']['group_id']
  action :create
  not_if "getent group #{node['logger']['group']}"
  not_if { node['install']['external_users'].casecmp("true") == 0 }
end

user node['logger']['user'] do
  uid node['logger']['user_id']
  gid node['logger']['group_id']
  shell "/bin/nologin"
  action :create
  system true
  not_if "getent passwd #{node['logger']['user']}"
  not_if { node['install']['external_users'].casecmp("true") == 0 }
end

#Add glassfish user to elastic group
group node['elastic']['group'] do
  action :modify
  members [node['logger']['user']]
  append true
  not_if { node['install']['external_users'].casecmp("true") == 0 }
end

service_owner = node['logger']['user']
service_group = node['logger']['group']

logstash_fqdn = consul_helper.get_service_fqdn("logstash")
logstash_endpoint = "#{logstash_fqdn}:#{node['logstash']['beats']['services_port']}"

# This generates too many cyclic dependencies if we need to get the 
# attributes right. In reality the log paths never change
# so I hardcode them.
log_paths = [
  "#{node['install']['dir']}/hadoop/logs/*.log",
  "#{node['install']['dir']}/apache-hive/logs/*.log",
  "#{node['install']['dir']}/onlinefs/logs/*.log",
  "#{node['install']['dir']}/domains/domain1/logs/*.log",
  "#{node['install']['dir']}/mysql-cluster/log/*.log",
  "#{node['install']['dir']}/kafka/logs/*.log",
]

template "#{node['filebeat']['base_dir']}/filebeat-service.yml" do
  source "filebeat.yml.erb"
  user service_owner
  group service_group
  mode 0655
  variables({
      :paths => log_paths,
      :multiline => true,
      :multiline_pattern => "([0-9]{4}-[0-9]{2}-[0-9]{2})|\\[|([0-9]{2}:[0-9]{2}:[0-9]{2})",
      :fields => false,
      :logstash_endpoint => logstash_endpoint,
      :log_name => "service"
  })
end

template "#{node['filebeat']['base_dir']}/bin/start-filebeat-service.sh" do
  source "start-filebeat.sh.erb"
  user service_owner
  group service_group
  mode 0750
  variables({ 
    :pid => "#{node['filebeat']['pid_dir']}/filebeat-service.pid",
    :config_file => "filebeat-service.yml"
  })
end

template"#{node['filebeat']['base_dir']}/bin/stop-filebeat-service.sh" do
  source "stop-filebeat.sh.erb"
  user service_owner
  group service_group
  mode 0750
  variables({ 
    :pid => "#{node['filebeat']['pid_dir']}/filebeat-service.pid",
    :user => service_owner
  })
end

service_name="filebeat-service"

service service_name do
  provider Chef::Provider::Service::Systemd
  supports :restart => true, :stop => true, :start => true, :status => true
  action :nothing
end

case node['platform_family']
when "rhel"
  systemd_script = "/usr/lib/systemd/system/#{service_name}.service" 
when "debian"
  systemd_script = "/lib/systemd/system/#{service_name}.service"
end

deps = ""
if exists_local("hopslog", "default") 
  deps = "logstash.service"
end  

template systemd_script do
  source "filebeat.service.erb"
  owner "root"
  group "root"
  mode 0754
  variables({ 
     :user => service_owner,
     :pid => "#{node['filebeat']['pid_dir']}/filebeat-service.pid",
     :exec_start => "#{node['filebeat']['base_dir']}/bin/start-filebeat-service.sh",
     :exec_stop => "#{node['filebeat']['base_dir']}/bin/stop-filebeat-service.sh",
     :deps => deps,
  })
  if node['services']['enabled'] == "true"
    notifies :enable, resources(:service => service_name)
  end
  notifies :restart, resources(:service => service_name)
end

kagent_config service_name do
 service "ELK"
 log_file "#{node['filebeat']['base_dir']}/log/service"
end

if conda_helpers.is_upgrade
  kagent_config "#{service_name}" do
    action :systemd_reload
  end
end
