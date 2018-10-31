my_private_ip = my_private_ip()


elastic = private_recipe_ip("elastic", "default") + ":#{node['elastic']['port']}"
kibana = private_recipe_ip("hopslog", "default") + ":#{node['kibana']['port']}"

numRetries=10
retryDelay=20

default_pattern = node['elastic']['default_kibana_index']

# delete .kibana index created from previous hopsworks versions if it exists
http_request 'delete old hopsworks .kibana index directly from elasticsearch' do
  action :delete
  url "http://#{elastic}/.kibana"
  retries numRetries
  retry_delay retryDelay
  not_if "test \"$(curl -s -o /dev/null -w '%{http_code}\n' http://#{elastic}/.kibana)\" = \"404\""
  only_if { node['install']['version'].start_with?("0.6") }
end

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

service_name="kibana"

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


if node['kagent']['enabled'] == "true" 
   kagent_config service_name do
     service "ELK"
     log_file "#{node['kibana']['base_dir']}/log/kibana.log"
   end
end

if node['install']['upgrade'] == "true"
  kagent_config "#{service_name}" do
    action :systemd_reload
  end
end  

http_request 'create index pattern in kibana' do
  action :post
  url "http://#{kibana}/api/saved_objects/index-pattern/#{default_pattern}?overwrite=true"
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

template"#{node['kibana']['base_dir']}/config/hops_upgrade_060.sh" do
  source "hops_upgrade_060.sh.erb"
  owner node['hopslog']['user']
  group node['hopslog']['group']
  mode 0655
  variables({
     :kibana_addr => kibana,
     :elastic_addr => elastic
           })
end


# Update old projects with new kibana saved objects etc. 
# It makes the same kibana requests as the project controller in Hopsworks.
exec = "#{node['ndb']['scripts_dir']}/mysql-client.sh"
bash 'add_kibana_indices_for_old_projects' do
        user "root"
        code <<-EOH
            set -e
	    #{exec} -ss -e \"select lower(projectname) as projectname from hopsworks.project order by projectname\" | while read projectname;
	    do
	      #skip first line if it contains slash character. Used to skip "Using socket: /tmp/mysql.sock
	      if [[ ${projectname} != *\/* ]]; then
  	        #{node['kibana']['base_dir']}/config/hops_upgrade_060.sh ${projectname}
  	      fi   
            done
        EOH
        only_if { node['install']['version'].start_with?("0.6") }
end
