require 'chef/mixin/shell_out'
extend Chef::Mixin::ShellOut

include_recipe 'apt'
include_recipe 'primero::common'
package 'build-essential'

node.force_default[:primero][:couchdb][:config][:log][:file] = "#{node[:primero][:log_dir]}/couchdb/couch.log"
node.force_default[:primero][:couchdb][:config][:log][:level] = "info"
node.force_default[:primero][:couchdb][:config][:couch_httpd_auth][:require_valid_user] = true
node.force_default[:primero][:couchdb][:config][:admins] = {
  node[:primero][:couchdb][:username] => node[:primero][:couchdb][:password],
}

package 'couchdb'

file node[:primero][:couchdb][:cert_path] do
  content node[:primero][:couchdb][:ssl][:cert]
  owner 'root'
  group 'root'
  mode '644'
end

file node[:primero][:couchdb][:key_path] do
  content node[:primero][:couchdb][:ssl][:key]
  owner 'root'
  group 'root'
  mode '400'
end

template '/etc/couchdb/local.ini' do
  owner 'couchdb'
  group 'couchdb'
  source 'couchdb/local.ini.erb'
  variables( :config => node[:primero][:couchdb][:config] )
  mode '0644'
  notifies :restart, 'service[couchdb]', :immediately
end

service 'couchdb' do
  action [:enable, :restart]
  provider Chef::Provider::Service::Upstart
end

include_recipe 'primero::nginx_couch'
