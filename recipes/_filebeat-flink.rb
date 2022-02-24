my_private_ip = my_private_ip()

logstash_fqdn = consul_helper.get_service_fqdn("logstash")
logstash_endpoint = logstash_fqdn + ":#{node['logstash']['beats']['flink_port']}"

file "#{node['filebeat']['base_dir']}/filebeat.xml" do
  action :delete
end

template"#{node['filebeat']['base_dir']}/filebeat-flink.yml" do
  source "filebeat.yml.erb"
  owner node['hops']['yarn']['user']
  group node['hops']['yarn']['group']
  mode 0655
  variables({ 
    :paths => [node['filebeat']['flink_read_logs']],
    :multiline => true,
    :multiline_pattern => '\'[0-9]{4}-[0-9]{2}-[0-9]{2}\'',
    :fields => false,
    :my_private_ip => my_private_ip,
    :logstash_endpoint => logstash_endpoint,
    :log_name => "flink"
  })
end

template "#{node['filebeat']['base_dir']}/bin/start-filebeat-flink.sh" do
  source "start-filebeat.sh.erb"
  owner node['hops']['yarn']['user']
  group node['hops']['yarn']['group']
  mode 0750
  variables({ 
    :pid => "#{node['filebeat']['pid_dir']}/filebeat-flink.pid",
    :config_file => "filebeat-flink.yml"
  })
end

template"#{node['filebeat']['base_dir']}/bin/stop-filebeat-flink.sh" do
  source "stop-filebeat.sh.erb"
  owner node['hops']['yarn']['user']
  group node['hops']['yarn']['group']
  mode 0750
  variables({ 
    :pid => "#{node['filebeat']['pid_dir']}/filebeat-flink.pid",
    :user => node['hops']['yarn']['user']
  })
end

service_name="filebeat-flink"

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
     :user => node['hops']['yarn']['user'],
     :pid => "#{node['filebeat']['pid_dir']}/filebeat-flink.pid",
     :exec_start => "#{node['filebeat']['base_dir']}/bin/start-filebeat-flink.sh",
     :exec_stop => "#{node['filebeat']['base_dir']}/bin/stop-filebeat-flink.sh",
     :deps => deps,
  })
  if node['services']['enabled'] == "true"
    notifies :enable, resources(:service => service_name)
  end
  notifies :restart, resources(:service => service_name)
end

kagent_config service_name do
  action :systemd_reload
end  


if node['kagent']['enabled'] == "true" 
   kagent_config service_name do
     service "ELK"
     log_file "#{node['filebeat']['base_dir']}/log/filebeat.log"
   end
end


if conda_helpers.is_upgrade
  kagent_config "#{service_name}" do
    action :systemd_reload
  end
end  
