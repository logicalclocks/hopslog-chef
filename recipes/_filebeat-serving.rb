#
# Common configuration between all serving types
#

my_private_ip = my_private_ip()
logstash_fqdn = consul_helper.get_service_fqdn("logstash")
logstash_service_endpoint = logstash_fqdn + ":#{node['logstash']['beats']['serving_port']}"

tf_serving_log_name = "tf_serving"
sklearn_serving_log_name = "sklearn_serving"

file "#{node['filebeat']['base_dir']}/filebeat.xml" do
  action :delete
end

tf_log_glob = "#{node['hopslog']['dir']}/staging/serving/**/*.log"
sk_log_glob = "#{node['hopslog']['dir']}/staging/serving/**/*-application.log"
if node.attribute?("hopsworks") && node['hopsworks'].attribute?("staging_dir")
    tf_log_glob = "#{node['hopsworks']['staging_dir']}/serving/**/*.log"
    sk_log_glob = "#{node['hopsworks']['staging_dir']}/serving/**/*.log"
end


if node.attribute?("hopsworks") && node['hopsworks'].attribute?("user")
  serving_user = node['hopsworks']['user']
  serving_group = node['hopsworks']['user']
else
  serving_user = "glassfish"
  serving_group = "glassfish"
end


group node['hopslog']['group'] do
  action :modify
  members [serving_user]
  append true
  not_if { node['install']['external_users'].casecmp("true") == 0 }
end

#
# TF Serving Configuration
#

template"#{node['filebeat']['base_dir']}/filebeat-tf-serving.yml" do
  source "filebeat.yml.erb"
  user serving_user
  group serving_group
  mode 0655
  variables({ 
    :paths => [tf_log_glob],
    :multiline => false,
    :fields => true,
    :model_server => "tensorflow_serving",
    :my_private_ip => my_private_ip,
    :logstash_endpoint => logstash_service_endpoint,
    :log_name => tf_serving_log_name
  })
end

template "#{node['filebeat']['base_dir']}/bin/start-filebeat-tf-serving.sh" do
  source "start-filebeat.sh.erb"
  owner serving_user
  group serving_group
  mode 0750
  variables({ 
    :pid => "#{node['filebeat']['pid_dir']}/filebeat-tf-serving.pid",
    :config_file => "filebeat-tf-serving.yml"
  })
end


template"#{node['filebeat']['base_dir']}/bin/stop-filebeat-tf-serving.sh" do
  source "stop-filebeat.sh.erb"
  owner serving_user
  group serving_group
  mode 0750
  variables({ 
    :pid => "#{node['filebeat']['pid_dir']}/filebeat-tf-serving.pid",
    :user => serving_user
  })
end

tf_serving_service_name="filebeat-tf-serving"

service tf_serving_service_name do
  provider Chef::Provider::Service::Systemd
  supports :restart => true, :stop => true, :start => true, :status => true
  action :nothing
end

case node['platform_family']
when "rhel"
  systemd_tf_script = "/usr/lib/systemd/system/#{tf_serving_service_name}.service"
when "debian"
  systemd_tf_script = "/lib/systemd/system/#{tf_serving_service_name}.service"
end

deps = ""
if exists_local("hopslog", "default") 
  deps = "logstash.service"
end

template systemd_tf_script do
  source "filebeat.service.erb"
  owner "root"
  group "root"
  mode 0754
  variables({ 
     :user => serving_user,
     :pid => "#{node['filebeat']['pid_dir']}/filebeat-tf-serving.pid",
     :exec_start => "#{node['filebeat']['base_dir']}/bin/start-filebeat-tf-serving.sh",
     :exec_stop => "#{node['filebeat']['base_dir']}/bin/stop-filebeat-tf-serving.sh",
     :deps => deps,
  })
  if node['services']['enabled'] == "true"
    notifies :enable, resources(:service => tf_serving_service_name)
  end
  notifies :restart, resources(:service => tf_serving_service_name)
end

kagent_config tf_serving_service_name do
  action :systemd_reload
end  


if node['kagent']['enabled'] == "true" 
   kagent_config tf_serving_service_name do
     service "ELK"
     log_file "#{node['filebeat']['base_dir']}/log/tf_serving.log"
   end
end


if conda_helpers.is_upgrade
  # Change ownership of logs and data
  fix_serving_beat_ownership(tf_serving_log_name, serving_user, serving_group)
  kagent_config "#{tf_serving_service_name}" do
    action :systemd_reload
  end
end

#
# SkLearn Serving Configuration
#

template"#{node['filebeat']['base_dir']}/filebeat-sklearn-serving.yml" do
  source "filebeat.yml.erb"
  user serving_user
  group serving_group
  mode 0655
  variables({
                :paths => [sk_log_glob],
                :multiline => false,
                :fields => true,
                :model_server => "flask",
                :my_private_ip => my_private_ip,
                :logstash_endpoint => logstash_service_endpoint,
                :log_name => sklearn_serving_log_name
            })
end

template "#{node['filebeat']['base_dir']}/bin/start-filebeat-sklearn-serving.sh" do
  source "start-filebeat.sh.erb"
  owner serving_user
  group serving_group
  mode 0750
  variables({
                :pid => "#{node['filebeat']['pid_dir']}/filebeat-sklearn-serving.pid",
                :config_file => "filebeat-sklearn-serving.yml"
            })
end

template"#{node['filebeat']['base_dir']}/bin/stop-filebeat-sklearn-serving.sh" do
  source "stop-filebeat.sh.erb"
  owner serving_user
  group serving_group
  mode 0750
  variables({
                :pid => "#{node['filebeat']['pid_dir']}/filebeat-sklearn-serving.pid",
                :user => serving_user
            })
end

sklearn_serving_service_name="filebeat-sklearn-serving"

service sklearn_serving_service_name do
  provider Chef::Provider::Service::Systemd
  supports :restart => true, :stop => true, :start => true, :status => true
  action :nothing
end

case node['platform_family']
when "rhel"
  systemd_sklearn_script = "/usr/lib/systemd/system/#{sklearn_serving_service_name}.service"
when "debian"
  systemd_sklearn_script = "/lib/systemd/system/#{sklearn_serving_service_name}.service"
end

template systemd_sklearn_script do
  source "filebeat.service.erb"
  owner "root"
  group "root"
  mode 0754
  variables({
                :user => serving_user,
                :pid => "#{node['filebeat']['pid_dir']}/filebeat-sklearn-serving.pid",
                :exec_start => "#{node['filebeat']['base_dir']}/bin/start-filebeat-sklearn-serving.sh",
                :exec_stop => "#{node['filebeat']['base_dir']}/bin/stop-filebeat-sklearn-serving.sh",
            })
  if node['services']['enabled'] == "true"
    notifies :enable, resources(:service => sklearn_serving_service_name)
  end
  notifies :restart, resources(:service => sklearn_serving_service_name)
end

kagent_config sklearn_serving_service_name do
  action :systemd_reload
end


if node['kagent']['enabled'] == "true"
  kagent_config sklearn_serving_service_name do
    service "ELK"
    log_file "#{node['filebeat']['base_dir']}/log/sklearn_serving.log"
  end
end


if conda_helpers.is_upgrade
  fix_serving_beat_ownership(sklearn_serving_log_name, serving_user, serving_group)
  kagent_config "#{sklearn_serving_service_name}" do
    action :systemd_reload
  end
end
