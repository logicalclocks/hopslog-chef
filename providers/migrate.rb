action :run do

  bash 'Move logstash data to data volume' do
    user 'root'
    code <<-EOH
    mv -f #{node['logstash']['data_dir']}/* #{node['logstash']['data_volume']['data_dir']}
    rm -rf #{node['logstash']['data_dir']}
  EOH
    only_if { conda_helpers.is_upgrade }
    only_if { ::File.directory?(node['logstash']['data_dir'])}
    not_if { ::File.symlink?(node['logstash']['data_dir'])}
  end

  bash 'Move logstash logs to data volume' do
    user 'root'
    code <<-EOH
    mv -f #{node['logstash']['logs_dir']}/* #{node['logstash']['data_volume']['logs_dir']}
    rm -rf #{node['logstash']['logs_dir']}
  EOH
    only_if { conda_helpers.is_upgrade }
    only_if { ::File.directory?(node['logstash']['logs_dir'])}
    not_if { ::File.symlink?(node['logstash']['logs_dir'])}
  end

  bash 'Move opensearch-dashboards data to data volume' do
    user 'root'
    code <<-EOH
    mv -f #{node['kibana']['data_dir']}/* #{node['kibana']['data_volume']['data_dir']}
    rm -rf #{node['kibana']['data_dir']}
  EOH
    only_if { conda_helpers.is_upgrade }
    only_if { ::File.directory?(node['kibana']['data_dir'])}
    not_if { ::File.symlink?(node['kibana']['data_dir'])}
  end

  bash 'Move opensearch-dashboards logs to data volume' do
    user 'root'
    code <<-EOH
    mv -f #{node['kibana']['log_dir']}/* #{node['kibana']['data_volume']['log_dir']}
    rm -rf #{node['kibana']['log_dir']}
  EOH
    only_if { conda_helpers.is_upgrade }
    only_if { ::File.directory?(node['kibana']['log_dir'])}
    not_if { ::File.symlink?(node['kibana']['log_dir'])}
  end

  bash 'Move filebeat logs to data volume' do
    user 'root'
    code <<-EOH
    mv -f #{node['filebeat']['logs_dir']}/* #{node['filebeat']['data_volume']['logs_dir']}
    rm -rf #{node['filebeat']['logs_dir']}
  EOH
    only_if { conda_helpers.is_upgrade }
    only_if { ::File.directory?(node['filebeat']['logs_dir'])}
    not_if { ::File.symlink?(node['filebeat']['logs_dir'])}
  end


  bash 'Move filebeat data to data volume' do
    user 'root'
    code <<-EOH
    mv -f #{node['filebeat']['data_dir']}/* #{node['filebeat']['data_volume']['data_dir']}
    rm -rf #{node['filebeat']['data_dir']}
  EOH
    only_if { conda_helpers.is_upgrade }
    only_if { ::File.directory?(node['filebeat']['data_dir']) }
    not_if { ::File.symlink?(node['filebeat']['data_dir']) }
    not_if { ::Dir.empty?(node['filebeat']['data_dir']) }
  end

  dirs_bug_fix = ['/data/jupyter', '/data/service', '/data/sklearn_serving', '/data/spark', '/data/tf_serving']
  for dir in dirs_bug_fix do
    bash "Move filebeat data #{dir} to the correct data volume - bug fix" do
      user 'root'
      # The guards do not contain the non-normal exit code inside the resource
      # if the dir does not exist AND IF you add the resource inside a for loop.
      # I don't know why this is happening but ignore_failure hides the
      # underlying error code
      ignore_failure true
      code <<-EOH
      mv -f #{dir} #{node['filebeat']['data_volume']['data_dir']}
    EOH
      only_if { conda_helpers.is_upgrade }
      only_if { ::File.directory?(dir) }
      not_if { ::File.directory?("#{node['filebeat']['data_volume']['data_dir']}/#{::File.basename(dir)}") }
    end
  end


end
