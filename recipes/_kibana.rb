my_private_ip = my_private_ip()


elastic = private_recipe_ip("elastic", "default") + ":#{node['elastic']['port']}"
kibana = private_recipe_ip("hopslog", "default") + ":#{node['kibana']['port']}"

file "#{node['kibana']['base_dir']}/config/kibana.xml" do
  action :delete
end


template"#{node['kibana']['base_dir']}/config/kibana.yml" do
  source "kibana.yml.erb"
  owner node['hopslog']['user']
  group node['hopslog']['group']
  mode 0655
  variables({ 
     :my_private_ip => my_private_ip,
     :elastic_addr => elastic
           })
end


template"#{node['kibana']['base_dir']}/bin/start-kibana.sh" do
  source "start-kibana.sh.erb"
  owner node['hopslog']['user']
  group node['hopslog']['group']
  mode 0750
end

template"#{node['kibana']['base_dir']}/bin/stop-kibana.sh" do
  source "stop-kibana.sh.erb"
  owner node['hopslog']['user']
  group node['hopslog']['group']
  mode 0750
end


case node['platform']
when "ubuntu"
 if node['platform_version'].to_f <= 14.04
   node.override['kibana']['systemd'] = "false"
 end
end


service_name="kibana"

if node['kibana']['systemd'] == "true"

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
     log_file "#{node['kibana']['base_dir']}/log/kibana.log"
   end
end

numRetries=10
retryDelay=20

default_pattern = node['elastic']['default_kibana_index']

http_request 'create kibana index' do
  action :put
  url "http://#{elastic}/.kibana"
  headers({'Content-Type' => 'application/json'})
  message '{}'
  retries numRetries
  retry_delay retryDelay
end

http_request 'put default kibana index pattern' do
  action :put
  url "http://#{elastic}/.kibana/doc/index-pattern:#{default_pattern}"
  message "{\"type\" : \"index-pattern\",\"index-pattern\" : {\"title\" : \"#{default_pattern}\"}}"
  headers({'Content-Type' => 'application/json'})
  retries numRetries
  retry_delay retryDelay
end

http_request 'set default index' do
  action :put
  url "http://#{elastic}/.kibana/doc/config:#{node['logstash']['version']}"
  message "{\"type\" : \"config\",\"config\" : {\"defaultIndex\" : \"#{default_pattern}\"}}"
  headers({'Content-Type' => 'application/json'})
  retries numRetries
  retry_delay retryDelay
end

http_request 'create index pattern in kibana' do
  action :post
  url "http://#{kibana}/api/saved_objects/index-pattern/#{default_pattern}"
  message "{\"attributes\":{\"title\":\"#{default_pattern}\"}}"
  headers({'kbn-xsrf' => 'required',
    'Content-Type' => 'application/json'
  })
  retries numRetries
  retry_delay retryDelay
end

http_request 'set default index in kibana' do
  action :post
  url "http://#{kibana}/api/kibana/settings/defaultIndex"
  message "{\"value\":\"#{default_pattern}\"}"
  headers({'kbn-xsrf' => 'required',
    'Content-Type' => 'application/json'
  })
  retries numRetries
  retry_delay retryDelay
end

