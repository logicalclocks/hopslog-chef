my_private_ip = my_private_ip()

# User certs must belong to hopslog group to be able to rotate x509 material
group node['hopslog']['group'] do
  action :modify
  members node['kagent']['certs_user']
  append true
  not_if { node['install']['external_users'].casecmp("true") == 0 }
end

crypto_dir = x509_helper.get_crypto_dir(node['hopslog']['user'])
kagent_hopsify "Generate x.509" do
  user node['hopslog']['user']
  crypto_directory crypto_dir
  action :generate_x509
  not_if { node["kagent"]["enabled"] == "false" }
end

elastic_url = any_elastic_url()
elastic_addrs = all_elastic_urls_str()
kibana_url = get_kibana_url()

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

private_key = "#{crypto_dir}/#{x509_helper.get_private_key_pkcs8_name(node['hopslog']['user'])}"
certificate = "#{crypto_dir}/#{x509_helper.get_certificate_bundle_name(node['hopslog']['user'])}"
hops_ca = "#{crypto_dir}/#{x509_helper.get_hops_ca_bundle_name()}"
template"#{node['kibana']['base_dir']}/config/kibana.yml" do
  source "kibana.yml.erb"
  owner node['hopslog']['user']
  group node['hopslog']['group']
  mode 0655
  variables({
     :my_private_ip => my_private_ip,
     :elastic_addr => elastic_addrs,
     :private_key => private_key,
     :certificate => certificate,
     :hops_ca => hops_ca
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

bash 'wait_for_kibana_green' do
  user 'root'
  retries 5
  retry_delay 30
  code <<-EOH
    set -eo pipefail
    curl "#{kibana_url}/api/status" \
      -H "Authorization: Basic #{Base64.strict_encode64("#{node['elastic']['opendistro_security']['kibana']['username']}:#{node['elastic']['opendistro_security']['kibana']['password']}")}" \
      -H "kbn-xsrf:required" \
      --cacert #{hops_ca} | jq -e '.status.overall.state=="green"'
  EOH
end

bash 'create_index_pattern' do
  user 'root'
  code <<-EOH
    curl "#{kibana_url}/api/saved_objects/index-pattern/#{node['kibana']['service_index_pattern']}" \
      -H "Authorization: Basic #{Base64.strict_encode64("#{node['elastic']['opendistro_security']['service_log_viewer']['username']}:#{node['elastic']['opendistro_security']['service_log_viewer']['password']}")}" \
      -H "kbn-xsrf:required" \
      -H "Content-Type:application/json" \
      --cacert #{hops_ca} \
      -d '{"attributes": {"title": "#{node['kibana']['service_index_pattern']}", "timeFieldName": "logdate"}}'
  EOH
end

# Register Kibana with Consul
consul_service "Registering Kibana with Consul" do
  service_definition "kibana-consul.hcl.erb"
  action :register
end
