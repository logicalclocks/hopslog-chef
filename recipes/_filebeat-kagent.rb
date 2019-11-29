file "#{node['filebeat']['base_dir']}/filebeat.xml" do
  action :delete
end

group node['hopslog']['group'] do
  action :modify
  members [node['kagent']['user']]
  append true
  not_if { node['install']['external_users'].casecmp("true") == 0 }
end

commands_log = "#{node['kagent']['dir']}/logs/**/conda_commands.log"
logstash_endpoint = private_recipe_ip("hopslog", "default") + ":#{node['logstash']['beats']['kagent_port']}"

template "#{node['filebeat']['base_dir']}/filebeat-kagent.yml" do
  source "filebeat.yml.erb"
  user node['kagent']['user']
  group node['kagent']['group']
  mode 0655
  variables({
              :paths => commands_log,
              :multiline => true,
              :logstash_endpoint => logstash_endpoint,
              :log_name => "kagent"
  })
end

template "#{node['filebeat']['base_dir']}/bin/start-filebeat-kagent.sh" do
  source "start-filebeat.sh.erb"
  user node['kagent']['user']
  group node['kagent']['group']
  mode 0750
  variables({ 
    :pid => "#{node['filebeat']['pid_dir']}/filebeat-kagent.pid",
    :config_file => "filebeat-kagent.yml"
  })
end

template"#{node['filebeat']['base_dir']}/bin/stop-filebeat-kagent.sh" do
  source "stop-filebeat.sh.erb"
  user node['kagent']['user']
  group node['kagent']['group']
  mode 0750
  variables({ 
    :pid => "#{node['filebeat']['pid_dir']}/filebeat-kagent.pid",
    :user => node['kagent']['user']
  })
end

service_name="filebeat-kagent"

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
     :user => node['kagent']['user'], 
     :pid => "#{node['filebeat']['pid_dir']}/filebeat-kagent.pid",
     :exec_start => "#{node['filebeat']['base_dir']}/bin/start-filebeat-kagent.sh",
     :exec_stop => "#{node['filebeat']['base_dir']}/bin/stop-filebeat-kagent.sh",
     :deps => deps,
  })
  if node['services']['enabled'] == "true"
    notifies :enable, resources(:service => service_name)
  end
  notifies :restart, resources(:service => service_name)
end

if node['kagent']['enabled'] == "true" 
   kagent_config service_name do
     service "ELK"
     log_file "#{node['filebeat']['base_dir']}/log/kagent"
   end
end


if conda_helpers.is_upgrade
  kagent_config "#{service_name}" do
    action :systemd_reload
  end
end  
