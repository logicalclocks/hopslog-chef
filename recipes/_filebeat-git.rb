file "#{node['filebeat']['base_dir']}/filebeat.xml" do
  action :delete
end

git_owner = ""
git_group = ""
if node.attribute?("hopsworks") && node['hopsworks'].attribute?("user")
  git_owner = node['hopsworks']['user']
  git_group = node['hopsworks']['user']
else
  git_owner = "glassfish"
  git_group = "glassfish"
end

#Add glassfish user to elastic group
group node['elastic']['user'] do
  action :modify
  members [git_owner]
  append true
  not_if { node['install']['external_users'].casecmp("true") == 0 }
end

log_glob = "#{node['install']['dir']}/git/*/*/*/*/logs/*.log"
if node.attribute?("git") && node['git'].attribute?("base_dir")
  log_glob = "#{node['git']['base_dir']}/*/*/*/*/logs/*.log"
end

logstash_fqdn = consul_helper.get_service_fqdn("logstash")
logstash_endpoint = "#{logstash_fqdn}:#{node['logstash']['beats']['git_port']}"

template "#{node['filebeat']['base_dir']}/filebeat-git.yml" do
  source "filebeat.yml.erb"
  user git_owner
  group git_group
  mode 0655
  variables({
              :paths => [log_glob],
              :multiline => false,
              :fields => false,
              :logstash_endpoint => logstash_endpoint,
              :log_name => "git"
            })
end

template "#{node['filebeat']['base_dir']}/bin/start-filebeat-git.sh" do
  source "start-filebeat.sh.erb"
  user git_owner
  group git_group
  mode 0750
  variables({
              :pid => "#{node['filebeat']['pid_dir']}/filebeat-git.pid",
              :config_file => "filebeat-git.yml"
            })
end

template"#{node['filebeat']['base_dir']}/bin/stop-filebeat-git.sh" do
  source "stop-filebeat.sh.erb"
  user git_owner
  group git_group
  mode 0750
  variables({
              :pid => "#{node['filebeat']['pid_dir']}/filebeat-git.pid",
              :user => git_owner
            })
end

service_name="filebeat-git"

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
              :user => git_owner,
              :pid => "#{node['filebeat']['pid_dir']}/filebeat-git.pid",
              :exec_start => "#{node['filebeat']['base_dir']}/bin/start-filebeat-git.sh",
              :exec_stop => "#{node['filebeat']['base_dir']}/bin/stop-filebeat-git.sh",
              :deps => deps,
            })
  if node['services']['enabled'] == "true"
    notifies :enable, resources(:service => service_name)
  end
  notifies :restart, resources(:service => service_name)
end

kagent_config service_name do
  service "ELK"
  log_file "#{node['filebeat']['base_dir']}/log/git"
end


if conda_helpers.is_upgrade
  kagent_config "#{service_name}" do
    action :systemd_reload
  end
end  
