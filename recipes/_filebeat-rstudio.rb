file "#{node['filebeat']['base_dir']}/filebeat.xml" do
  action :delete
end

rstudio_owner = ""
rstudio_group = ""
if node.attribute?("hopsworks") && node['hopsworks'].attribute?("user")
  rstudio_owner = node['hopsworks']['user']
  rstudio_group = node['hopsworks']['user']
else
  rstudio_owner = "glassfish"
  rstudio_group = "glassfish"
end

#Add glassfish user to elastic group
group node['elastic']['user'] do
  action :modify
  members [rstudio_owner]
  append true
  not_if { node['install']['external_users'].casecmp("true") == 0 }
end

log_glob = "#{node['install']['dir']}/rstudio/*/*/*/*/logs/*.log"
if node.attribute?("rstudio") && node['rstudio'].attribute?("base_dir")
  log_glob = "#{node['rstudio']['base_dir']}/*/*/*/*/logs/*.log"
end
logstash_endpoint = private_recipe_ip("hopslog", "default") + ":#{node['logstash']['beats']['rstudio_port']}"

template "#{node['filebeat']['base_dir']}/filebeat-rstudio.yml" do
  source "filebeat.yml.erb"
  user rstudio_owner
  group rstudio_group
  mode 0655
  variables({
              :paths => [log_glob],
              :multiline => false,
              :fields => false,
              :logstash_endpoint => logstash_endpoint,
              :log_name => "rstudio"
            })
end

template "#{node['filebeat']['base_dir']}/bin/start-filebeat-rstudio.sh" do
  source "start-filebeat.sh.erb"
  user rstudio_owner
  group rstudio_group
  mode 0750
  variables({
              :pid => "#{node['filebeat']['pid_dir']}/filebeat-rstudio.pid",
              :config_file => "filebeat-rstudio.yml"
            })
end

template"#{node['filebeat']['base_dir']}/bin/stop-filebeat-rstudio.sh" do
  source "stop-filebeat.sh.erb"
  user rstudio_owner
  group rstudio_group
  mode 0750
  variables({
              :pid => "#{node['filebeat']['pid_dir']}/filebeat-rstudio.pid",
              :user => rstudio_owner
            })
end

service_name="filebeat-rstudio"

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
              :user => rstudio_owner,
              :pid => "#{node['filebeat']['pid_dir']}/filebeat-rstudio.pid",
              :exec_start => "#{node['filebeat']['base_dir']}/bin/start-filebeat-rstudio.sh",
              :exec_stop => "#{node['filebeat']['base_dir']}/bin/stop-filebeat-rstudio.sh",
              :deps => deps,
            })
  if node['services']['enabled'] == "true"
    notifies :enable, resources(:service => service_name)
  end
  notifies :restart, resources(:service => service_name)
end

kagent_config service_name do
  service "ELK"
  log_file "#{node['filebeat']['base_dir']}/log/rstudio"
end


if conda_helpers.is_upgrade
  kagent_config "#{service_name}" do
    action :systemd_reload
  end
end
