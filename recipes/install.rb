group node['hopslog']['group'] do
  action :create
  not_if "getent group #{node['hopslog']['group']}"
end


user node['hopslog']['user'] do
  action :create
  gid node['hopslog']['group']
  home "/home/#{node['hopslog']['user']}"  
  system true
  shell "/bin/bash"
  manage_home true
  not_if "getent passwd #{node['hopslog']['user']}"
end

group node['hopslog']['group'] do
  action :modify
  members ["#{node['hopslog']['user']}"]
  append true
end


group node['hops']['yarn']['user'] do
  action :create
  not_if "getent group #{node['hops']['yarn']['user']}"
end


user node['hops']['yarn']['user'] do
  home "/home/#{node['hops']['yarn']['user']}"
  gid node['hops']['yarn']['user']
  system true
  shell "/bin/bash"
  manage_home true
  action :create
  not_if "getent passwd #{node['hops']['yarn']['user']}"
end



include_recipe "java"

#
# Logstash
#


package_url = "#{node['logstash']['url']}"
base_package_filename = File.basename(package_url)
cached_package_filename = "#{Chef::Config['file_cache_path']}/#{base_package_filename}"

remote_file cached_package_filename do
  source package_url
  owner "root"
  mode "0644"
  action :create_if_missing
end

directory node['hopslog']['dir'] do
  owner node['hopslog']['user']
  group node['hopslog']['group']
  mode "755"
  action :create
  not_if { File.directory?("#{node['hopslog']['dir']}") }
end

logstash_downloaded = "#{node['logstash']['home']}/.logstash.extracted_#{node['logstash']['version']}"
# Extract logstash
bash 'extract_logstash' do
        user "root"
        code <<-EOH
                tar -xf #{cached_package_filename} -C #{node['hopslog']['dir']}
                chown -R #{node['hopslog']['user']}:#{node['hopslog']['group']} #{node['logstash']['home']}
                chmod 750 #{node['logstash']['home']}
                cd #{node['logstash']['home']}
                touch #{logstash_downloaded}
                chown #{node['hopslog']['user']} #{logstash_downloaded}
        EOH
     not_if { ::File.exists?( logstash_downloaded ) }
end

link node['logstash']['base_dir'] do
  owner node['hopslog']['user']
  group node['hopslog']['group']
  to node['logstash']['home']
end


directory "#{node['logstash']['base_dir']}/log" do
  owner node['hopslog']['user']
  group node['hopslog']['group']
  mode "750"
  action :create
end


directory "#{node['logstash']['base_dir']}/config" do
  owner node['hopslog']['user']
  group node['hopslog']['group']
  mode "750"
  action :create
end


#
# Kibana
#

package_url = "#{node['kibana']['url']}"
base_package_filename = File.basename(package_url)
cached_package_filename = "#{Chef::Config['file_cache_path']}/#{base_package_filename}"

remote_file cached_package_filename do
  source package_url
  owner "root"
  mode "0644"
  action :create_if_missing
end


kibana_downloaded = "#{node['kibana']['home']}/.kibana.extracted_#{node['kibana']['version']}"
# Extract kibana
bash 'extract_kibana' do
        user "root"
        code <<-EOH
                tar -xf #{cached_package_filename} -C #{node['hopslog']['dir']}
                chown -R #{node['hopslog']['user']}:#{node['hopslog']['group']} #{node['kibana']['home']}
                chmod 750 #{node['kibana']['home']}
                cd #{node['kibana']['home']}
                touch #{kibana_downloaded}
                chown #{node['hopslog']['user']} #{kibana_downloaded}
        EOH
     not_if { ::File.exists?( kibana_downloaded ) }
end

link node['kibana']['base_dir'] do
  owner node['hopslog']['user']
  group node['hopslog']['group']
  to node['kibana']['home']
end


directory "#{node['kibana']['base_dir']}/log" do
  owner node['hopslog']['user']
  group node['hopslog']['group']
  mode "750"
  action :create
end


directory "#{node['kibana']['base_dir']}/conf" do
  owner node['hopslog']['user']
  group node['hopslog']['group']
  mode "750"
  action :create
end

#
# Filebeat
#

package_url = "#{node['filebeat']['url']}"
base_package_filename = File.basename(package_url)
cached_package_filename = "#{Chef::Config['file_cache_path']}/#{base_package_filename}"

remote_file cached_package_filename do
  source package_url
  owner "root"
  mode "0644"
  action :create_if_missing
end


filebeat_downloaded = "#{node['filebeat']['home']}/.filebeat.extracted_#{node['filebeat']['version']}"
# Extract filebeat
bash 'extract_filebeat' do
        user "root"
        code <<-EOH
                tar -xf #{cached_package_filename} -C #{node['hopslog']['dir']}
                chown -R #{node['hops']['yarn']['user']}:#{node['hops']['yarn']['group']} #{node['filebeat']['home']}
                chmod 750 #{node['filebeat']['home']}
                cd #{node['filebeat']['home']}
                touch #{filebeat_downloaded}
                chown #{node['hops']['yarn']['user']} #{filebeat_downloaded}
        EOH
     not_if { ::File.exists?( filebeat_downloaded ) }
end

link node['filebeat']['base_dir'] do
  owner node['hops']['yarn']['user']
  group node['hops']['yarn']['group']
  to node['filebeat']['home']
end


directory "#{node['filebeat']['base_dir']}/log" do
  owner node['hops']['yarn']['user']
  group node['hops']['yarn']['group']
  mode "750"
  action :create
end
