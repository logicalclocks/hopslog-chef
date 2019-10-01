private_ip = my_private_ip()

logstash_beamjobservercluster = private_recipe_ip("hopslog", "default") + ":#{node['logstash']['beats']['beamjobservercluster_port']}"
logstash_beamjobserverlocal = private_recipe_ip("hopslog", "default") + ":#{node['logstash']['beats']['beamjobserverlocal_port']}"
logstash_beamsdkworker = private_recipe_ip("hopslog", "default") + ":#{node['logstash']['beats']['beamsdkworker_port']}"

file "#{node['filebeat']['base_dir']}/filebeat.xml" do
  action :delete
end

node["filebeat"]["beam_logs"].each do |beam_log|
  next if beam_log.include? "beamjobserverlocal" and !node['hopsworks']['default']['private_ips'].include?(private_ip)
  logstash_endpoint = logstash_beamjobservercluster
  beamlogs_owner = node['hops']['yarn']['user']
  beamlogs_group = node['hops']['yarn']['group']
  log_glob = node['filebeat']["#{beam_log}_logs"]
  if beam_log.include? "sdkworker"
    logstash_endpoint = logstash_beamsdkworker
  elsif beam_log.include? "beamjobserverlocal"
    log_glob = node['filebeat']['beamjobserverlocal_logs']
    if node.attribute?("hopsworks") && node['hopsworks'].attribute?("staging_dir")
      log_glob = "#{node['hopsworks']['staging_dir']}/private_dirs/*/beamjobserver-*.log"
    end
    logstash_endpoint = logstash_beamjobserverlocal
    if node.attribute?("hopsworks") && node['hopsworks'].attribute?("user")
      beamlogs_owner = node['hopsworks']['user']
      beamlogs_group = node['hopsworks']['user']
    else
      beamlogs_owner = "glassfish"
      beamlogs_group = "glassfish"
    end
    #Add glassfish user to elastic group
    group node['elastic']['user'] do
      action :modify
      members [beamlogs_owner]
      append true
      not_if { node['install']['external_users'].casecmp("true") == 0 }
    end
    if node.attribute?("hopsworks") && node['hopsworks'].attribute?("staging_dir")
      log_glob = "#{node['hopsworks']['staging_dir']}/private_dirs/*/#{beam_log}-*.log"
    end
  end

    template "#{node['filebeat']['base_dir']}/filebeat-#{beam_log}.yml" do
      source "filebeat.yml.erb"
      owner beamlogs_owner
      group beamlogs_group
      mode 0655
      variables({
                    :paths => log_glob,
                    :multiline => false,
                    :my_private_ip => private_ip,
                    :logstash_endpoint => logstash_endpoint,
                    :log_name => "#{beam_log}"
                })
    end

    template "#{node['filebeat']['base_dir']}/bin/start-filebeat-#{beam_log}.sh" do
      source "start-filebeat.sh.erb"
      owner beamlogs_owner
      group beamlogs_group
      mode 0750
      variables({
                    :pid => "#{node['filebeat']['pid_dir']}/filebeat-#{beam_log}.pid",
                    :config_file => "filebeat-#{beam_log}.yml"
                })
    end

    template "#{node['filebeat']['base_dir']}/bin/stop-filebeat-#{beam_log}.sh" do
      source "stop-filebeat.sh.erb"
      owner node['hops']['yarn']['user']
      group node['hops']['yarn']['group']
      mode 0750
      variables({
                    :pid => "#{node['filebeat']['pid_dir']}/filebeat-#{beam_log}.pid",
                    :user => node['hops']['yarn']['user']
                })
    end

    service_name = "filebeat-#{beam_log}"

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
      source "filebeat.service.erb"
      owner "root"
      group "root"
      mode 0754
      variables({
                    :user => beamlogs_owner,
                    :pid => "#{node['filebeat']['pid_dir']}/filebeat-#{beam_log}.pid",
                    :exec_start => "#{node['filebeat']['base_dir']}/bin/start-filebeat-#{beam_log}.sh",
                    :exec_stop => "#{node['filebeat']['base_dir']}/bin/stop-filebeat-#{beam_log}.sh",
                })
      if node['services']['enabled'] == "true"
        notifies :enable, resources(:service => service_name)
      end
      notifies :restart, resources(:service => service_name)
    end

    kagent_config service_name do
      action :systemd_reload
    end

    if node['services']['enabled'] != "true" && node['flink']['systemd'] == "true"
      service "#{service_name}" do
        provider Chef::Provider::Service::Systemd
        supports :restart => true, :stop => true, :start => true, :status => true
        action :disable
      end

      kagent_config "#{service_name}" do
        action :systemd_reload
      end
    end

    if node['kagent']['enabled'] == "true"
      kagent_config service_name do
        service "ELK"
        log_file "#{node['filebeat']['base_dir']}/log/#{beam_log}.log"
      end
    end

    if node['install']['upgrade'] == "true"
      kagent_config "#{service_name}" do
        action :systemd_reload
      end
    end

end #for loop
