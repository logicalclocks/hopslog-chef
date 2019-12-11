module Hopslog
  module Helpers

    def get_kibana_url()
      if node['kibana']['opendistro_security']['https']['enabled'].casecmp?("true")
        return "https://#{my_host()}:#{node['kibana']['port']}"
      else
        return "http://#{my_private_ip()}:#{node['kibana']['port']}"
      end
    end

  end
end

Chef::Recipe.send(:include, Hopslog::Helpers)
Chef::Resource.send(:include, Hopslog::Helpers)
Chef::Provider.send(:include, Hopslog::Helpers)
