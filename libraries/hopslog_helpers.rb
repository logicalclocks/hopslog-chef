module Hopslog
  module Helpers

    def get_kibana_url()
      if node['kibana']['opendistro_security']['https']['enabled'].casecmp?("true")
        return "https://#{my_host()}:#{node['kibana']['port']}"
      else
        return "http://#{my_private_ip()}:#{node['kibana']['port']}"
      end
    end
    # Used during upgrades, since the filebeat sklearn and tfserving from 1.3 -> 1.4 changed ownership from "serving"
    # to "glassfish"
    def fix_serving_beat_ownership(serving_name, serving_user, serving_group)
      execute "fix ownership of filebeat #{serving_name} data" do
        command "chown -R #{serving_user}:#{serving_group} #{node['filebeat']['base_dir']}/data/#{serving_name}"
        user "root"
        action :run
        not_if "[ $(stat -c %U #{node['filebeat']['base_dir']}/data/#{serving_name}) = #{serving_name} ]"
      end

      execute "fix ownership of filebeat #{serving_name}logs" do
        command "chown #{serving_user}:#{serving_group} #{node['filebeat']['base_dir']}/log/#{serving_name}*"
        user "root"
        action :run
        not_if "[ $(stat -c %U #{node['filebeat']['base_dir']}/log/#{serving_name}) = #{serving_user} ]"
      end
    end

  end
end

Chef::Recipe.send(:include, Hopslog::Helpers)
Chef::Resource.send(:include, Hopslog::Helpers)
Chef::Provider.send(:include, Hopslog::Helpers)
