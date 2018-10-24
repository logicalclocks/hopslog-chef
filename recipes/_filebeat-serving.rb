my_private_ip = my_private_ip()

logstash_endpoint = private_recipe_ip("hopslog", "default") + ":#{node['logstash']['beats']['serving_port']}"

file "#{node['filebeat']['base_dir']}/filebeat.xml" do
  action :delete
end

log_glob = "#{node['hopslog']['dir']}/staging/serving/**/*.log"
if node.attribute?("hopsworks")
  if node['hopsworks'].attribute?("staging_dir")
    log_glob = "#{node['hopsworks']['staging_dir']}/serving/**/*.log"
  end
end


tfserving_user = node['install']['user'].empty? ? "tfserving" : node['install']['user'] 
tfserving_group = node['install']['user'].empty? ? "tfserving" : node['install']['user'] 
if node.attribute?("tfserving") 
  if node['tfserving'].attribute?("user")
    tfserving_user = node['tfserving']['user']
  end
  if node['tfserving'].attribute?("group")
    tfserving_group = node['tfserving']['group']
  end
end

group node['hopslog']['group'] do
  action :modify
  members [tfserving_user]
  append true
end

template"#{node['filebeat']['base_dir']}/filebeat-serving.yml" do
  source "filebeat.yml.erb"
  user tfserving_user
  group tfserving_group 
  mode 0655
  variables({ 
    :paths => log_glob, 
    :multiline => false,
    :my_private_ip => my_private_ip,
    :logstash_endpoint => logstash_endpoint,
    :log_name => "serving"
  })
end

template "#{node['filebeat']['base_dir']}/bin/start-filebeat-serving.sh" do
  source "start-filebeat.sh.erb"
  owner tfserving_user
  group tfserving_group 
  mode 0750
  variables({ 
    :pid => "#{node['filebeat']['pid_dir']}/filebeat-serving.pid",
    :config_file => "filebeat-serving.yml"
  })
end

template"#{node['filebeat']['base_dir']}/bin/stop-filebeat-serving.sh" do
  source "stop-filebeat.sh.erb"
  owner tfserving_user
  group tfserving_group 
  mode 0750
  variables({ 
    :pid => "#{node['filebeat']['pid_dir']}/filebeat-serving.pid",
    :user => tfserving_user
  })
end

service_name="filebeat-serving"

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

template systemd_script do
  source "filebeat.service.erb"
  owner "root"
  group "root"
  mode 0754
  variables({ 
     :user => tfserving_user, 
     :pid => "#{node['filebeat']['pid_dir']}/filebeat-serving.pid",
     :exec_start => "#{node['filebeat']['base_dir']}/bin/start-filebeat-serving.sh",
     :exec_stop => "#{node['filebeat']['base_dir']}/bin/stop-filebeat-serving.sh",
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


if node['install']['upgrade'] == "true"
  kagent_config "#{service_name}" do
    action :systemd_reload
  end
end  