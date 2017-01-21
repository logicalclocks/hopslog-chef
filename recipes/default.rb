my_private_ip = my_private_ip()
my_public_ip = my_public_ip()


elastic = private_recipe_ip("elastic", "default") + ":#{node.elastic.port}"


# file "#{node.logstash.base_dir}/conf/logstash-site.xml" do
#   action :delete
# end


# template"#{node.logstash.base_dir}/config/logstash.yml" do
#   source "logstash.yml.erb"
#   owner node.logstash.user
#   group node.logstash.group
#   mode 0655
#   variables({ 
#      :my_ip => my_private_ip,
#      :elastic_addr => elastic
#            })
# end


template"#{node.logstash.base_dir}/config/spark-streaming.conf" do
  source "spark-streaming.conf.erb"
  owner node.logstash.user
  group node.logstash.group
  mode 0655
  variables({ 
     :my_ip => my_private_ip,
     :elastic_addr => elastic
           })
end


template"#{node.logstash.base_dir}/bin/start-logstash.sh" do
  source "start-logstash.sh.erb"
  owner node.logstash.user
  group node.logstash.group
  mode 0750
end

template"#{node.logstash.base_dir}/bin/stop-logstash.sh" do
  source "stop-logstash.sh.erb"
  owner node.logstash.user
  group node.logstash.group
  mode 0750
end


case node.platform
when "ubuntu"
 if node.platform_version.to_f <= 14.04
   node.override.logstash.systemd = "false"
 end
end


service_name="logstash"

if node.logstash.systemd == "true"

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
    notifies :enable, resources(:service => service_name)
    notifies :start, resources(:service => service_name), :immediately
  end

  apache_hadoop_start "reload_logstash_daemon" do
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
    owner node.logstash.user
    group node.logstash.group
    mode 0754
    notifies :enable, resources(:service => service_name)
    notifies :restart, resources(:service => service_name), :immediately
  end

end


node.override['kibana']['base_dir'] = node.hopslog.base_dir
node.override['kibana']['user'] = node.hopslog.user
node.override['kibana']['group'] = node.hopslog.group
node.override['kibana']['kibana4_version'] = node.hopslog.kibana_version
node.override['kibana']['install_method'] = "source"

include_recipe "kibana::kibana4"

if node.kagent.enabled == "true" 
   kagent_config service_name do
     service service_name
     log_file "#{node.logstash.base_dir}/logstash.log"
   end
   kagent_config "kibana" do
     service "kibana"
     log_file "#{node.kibana.base_dir}/kibana.log"
   end
end
