  bash 'kill_running_service' do
    user "root"
    ignore_failure true
    code <<-EOF
      service stop logstash
      systemctl stop logstash
    EOF
  end

  file "/etc/init.d/logstash" do
    action :delete
    ignore_failure true
  end
  
  file "/usr/lib/systemd/system/logstash.service" do
    action :delete
    ignore_failure true
  end
  file "/lib/systemd/system/logstash.service" do
    action :delete
    ignore_failure true
  end

  directory node['logstash']['home'] do
    recursive true
    action :delete
    ignore_failure true
  end

  link node['logstash']['base_dir'] do
    action :delete
    ignore_failure true
  end


package_url = "#{node['logstash']['url']}"
base_package_filename = File.basename(package_url)
cached_package_filename = "/tmp/#{base_package_filename}"

file cached_package_filename do
  action :delete
  ignore_failure true
end

