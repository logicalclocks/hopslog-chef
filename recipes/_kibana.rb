my_private_ip = my_private_ip()

elastic_url = any_elastic_url()
elastic_addrs = all_elastic_urls_str()
kibana_url = get_kibana_url()

group node['kagent']['certs_group'] do
  action :modify
  members ["#{node["elastic"]["user"]}"]
  append true
  not_if { node['install']['external_users'].casecmp("true") == 0 }
end

# delete .kibana index created from previous hopsworks versions if it exists
elastic_http 'delete old hopsworks .kibana index directly from elasticsearch' do
  action :delete
  url "#{elastic_url}/.kibana"
  user node['elastic']['opendistro_security']['admin']['username']
  password node['elastic']['opendistro_security']['admin']['password']
  only_if_cond node['install']['version'].start_with?("0.6")
  only_if_exists true
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
     :elastic_addr => elastic_addrs
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


deps = ""
if exists_local("elastic", "default") 
  deps = "elasticsearch.service"
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
  variables({
            :deps => deps
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
     log_file "#{node['kibana']['base_dir']}/log/kibana.log"
   end
end

if conda_helpers.is_upgrade
  kagent_config "#{service_name}" do
    action :systemd_reload
  end
end  

template"#{node['kibana']['base_dir']}/config/hops_upgrade_060.sh" do
  source "hops_upgrade_060.sh.erb"
  owner node['hopslog']['user']
  group node['hopslog']['group']
  mode 0655
  variables({
     :kibana_addr => kibana_url,
     :elastic_addr => elastic_url
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
