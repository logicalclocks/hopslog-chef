my_private_ip = my_private_ip()


elastic = private_recipe_ip("elastic", "default") + ":#{node['elastic']['port']}"

template"#{node['logstash']['base_dir']}/config/spark-streaming.conf" do
  source "spark-streaming.conf.erb"
  owner node['hopslog']['user']
  group node['hopslog']['group']
  mode 0655
  variables({ 
     :my_private_ip => my_private_ip,
     :elastic_addr => elastic
           })
end


template"#{node['logstash']['base_dir']}/bin/start-logstash.sh" do
  source "start-logstash.sh.erb"
  owner node['hopslog']['user']
  group node['hopslog']['group']
  mode 0750
end

template"#{node['logstash']['base_dir']}/bin/stop-logstash.sh" do
  source "stop-logstash.sh.erb"
  owner node['hopslog']['user']
  group node['hopslog']['group']
  mode 0750
end


case node['platform']
when "ubuntu"
 if node['platform_version'].to_f <= 14.04
   node.override['logstash']['systemd'] = "false"
 end
end


service_name="logstash"

if node['logstash']['systemd'] == "true"

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
    source "#{service_name}.service.erb"
    owner "root"
    group "root"
    mode 0754
if node['services']['enabled'] == "true"
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
    owner node['hopslog']['user']
    group node['hopslog']['group']
    mode 0754
    notifies :enable, resources(:service => service_name)
    notifies :restart, resources(:service => service_name), :immediately
  end

end


if node['kagent']['enabled'] == "true" 
   kagent_config service_name do
     service "ELK"
     log_file "#{node['logstash']['base_dir']}/logstash.log"
   end
end

if node['install']['upgrade'] == "true"
  kagent_config "#{service_name}" do
    action :systemd_reload
  end
end  
