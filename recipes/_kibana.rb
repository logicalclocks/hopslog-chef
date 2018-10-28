my_private_ip = my_private_ip()


elastic = private_recipe_ip("elastic", "default") + ":#{node['elastic']['port']}"
kibana = private_recipe_ip("hopslog", "default") + ":#{node['kibana']['port']}"

# delete default index created from previous hopsworks versions
http_request 'delete old hopsworks default index pattern directly from elasticsearch' do
  action :delete
  url "http://#{elastic}/#{default_pattern}"
  retries numRetries
  retry_delay retryDelay
end

# delete .kibana index created from previous hopsworks versions 
http_request 'delete old hopsworks .kibana index directly from elasticsearch' do
  action :delete
  url "http://#{elastic}/.kibana"
  retries numRetries
  retry_delay retryDelay
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
numRetries=10
retryDelay=20

default_pattern = node['elastic']['default_kibana_index']

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


# Update old projects with new kibana saved objects etc. 
# It makes the same kibana requests as the project controller in Hopsworks.
exec = "#{node['ndb']['scripts_dir']}/mysql-client.sh"
bash 'add_kibana_indices_for_old_projects' do
        user "root"
        code <<-EOH
            set -e
	    #{exec} -ss -e \"select projectname from hopsworks.project order by projectname\" | while read projectname;
	    do
	      #skip first line if it contains slash character. Used to skip "Using socket: /tmp/mysql.sock
	      if [[ "$projectname" != *\/* ]]; then
  	        echo "1. Creating kibana index pattern for logs: ${projectname}"
  	        curl -XPOST "#{kibana}/api/saved_objects/index-pattern/${projectname}_logs-*" -H "kbn-xsrf:required" -H "Content-Type:application/json" -d '{"attributes": {"title": "'"$projectname"'_logs-*"}}'
  	        echo "2. Creating kibana index pattern for logs: ${projectname}"
  	        curl -XPUT "#{elastic}/${projectname}_experiments"
  	        echo "3. Creating kibana index pattern for experiments: ${projectname}"
  	        curl -XPOST "#{kibana}/api/saved_objects/index-pattern/${projectname}_experiments" -H "kbn-xsrf:required" -H "Content-Type:application/json" -d '{"attributes": {"title": "'"$projectname"'_experiments"}}'
  	        echo "4. Creating kibana experiments summary search: ${projectname}"
  	        curl -XPOST "#{kibana}/api/saved_objects/search/${projectname}_experiments_summary-search?overwrite=true" -H "kbn-xsrf:required" -H "Content-Type:application/json" -d '{"attributes":{"title":"Experiments summary","description":"","hits":0,"columns":["_id","user","name","start","finished","status","module","function","hyperparameter","metric"],"sort":["start","desc"],"version":1,"kibanaSavedObjectMeta":{"searchSourceJSON":"{\"index\":\"'"$projectname"'_experiments\",\"highlightAll\":true,\"version\":true,\"query\":{\"language\":\"lucene\",\"query\":\"\"},\"filter\":[]}"}}}'
  	        echo "5. Creating kibana experiments summary dashboard: ${projectname}"
  	        curl -XPOST "#{kibana}/api/saved_objects/dashboard/${projectname}_experiments_summary-dashboard?overwrite=true" -H "kbn-xsrf:required" -H "Content-Type:application/json" -d '{"attributes":{"title":"Experiments summary dashboard","hits":0,"description":"A summary of all experiments run in this project","panelsJSON":"[{\"gridData\":{\"h\":9,\"i\":\"1\",\"w\":12,\"x\":0,\"y\":0},\"id\":\"'"$projectname"'_experiments_summary-search\",\"panelIndex\":\"1\",\"type\":\"search\",\"version\":\"6.2.3\"}]","optionsJSON":"{\"darkTheme\":false,\"hidePanelTitles\":false,\"useMargins\":true}","version":1,"timeRestore":false,"kibanaSavedObjectMeta":{"searchSourceJSON":"{\"query\":{\"language\":\"lucene\",\"query\":\"\"},\"filter\":[],\"highlightAll\":true,\"version\":true}"}}}'
  	      fi   
            done
        EOH
end
