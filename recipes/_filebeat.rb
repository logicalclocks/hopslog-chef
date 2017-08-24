my_private_ip = my_private_ip()

kafka_endpoint = private_recipe_ip("kkafka", "default") + ":#{node.kkafka.broker.port}"

file "#{node.filebeat.base_dir}/filebeat.xml" do
  action :delete
end

template"#{node.filebeat.base_dir}/filebeat.yml" do
  source "filebeat.yml.erb"
  owner node.hopslog.user
  group node.hopslog.group
  mode 0655
  variables({ 
     :my_private_ip => my_private_ip,
     :kafka_endpoint => kafka_endpoint
           })
end


directory "#{node.filebeat.base_dir}/bin" do
  owner node.hopslog.user
  group node.hopslog.group
  mode "750"
  action :create
end


template"#{node.filebeat.base_dir}/bin/start-filebeat.sh" do
  source "start-filebeat.sh.erb"
  owner node.hopslog.user
  group node.hopslog.group
  mode 0750
end

template"#{node.filebeat.base_dir}/bin/stop-filebeat.sh" do
  source "stop-filebeat.sh.erb"
  owner node.hopslog.user
  group node.hopslog.group
  mode 0750
end


case node.platform
when "ubuntu"
 if node.platform_version.to_f <= 14.04
   node.override.filebeat.systemd = "false"
 end
end


service_name="filebeat"

if node.filebeat.systemd == "true"

  service service_name do
    provider Chef::Provider::Service::Systemd
    supports :restart => true, :stop => true, :start => true, :status => true
    action :nothing
  end

  case node.platform_family
  when "rhel"
    systemd_script = "/usr/lib/systemd/system/#{service_name}.service" 
  when "debian"
    systemd_script = "/lib/systemd/system/#{service_name}.service"
  end

  template systemd_script do
    source "#{service_name}.service.erb"
    owner "root"
    group "root"
    mode 0754
if node.services.enabled == "true"
    notifies :enable, resources(:service => service_name)
end
    notifies :restart, resources(:service => service_name)
  end

  kagent_config service_name do
    action :systemd_reload
  end  

else #sysv

  service service_name do
    provider Chef::Provider::Service::Init::Debian
    supports :restart => true, :stop => true, :start => true, :status => true
    action :nothing
  end

  template "/etc/init.d/#{service_name}" do
    source "#{service_name}.erb"
    owner node.hopslog.user
    group node.hopslog.group
    mode 0754
    notifies :enable, resources(:service => service_name)
    notifies :restart, resources(:service => service_name), :immediately
  end

end


if node.kagent.enabled == "true" 
   kagent_config service_name do
     service "ELK"
     log_file "#{node.filebeat.base_dir}/log/filebeat.log"
   end
end

