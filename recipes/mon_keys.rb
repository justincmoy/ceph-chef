#
# Author: Chris Jones <cjones303@bloomberg.net>
# Cookbook: ceph
# Recipe: mon_keys
#
# Copyright 2016, Bloomberg Finance L.P.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# The name of the recipe, mon_keys, is prefixed with 'mon' so as to indicate the grouping of the recipe since it must
# be ran after mon_start.

# This recipe can only be ran AFTER a monitor has started
# NOTE: This recipe will create bootstrap keys for OSD, [MDS, RGW automatically]

# NOTE: MAY NEED TO MOVE Key gen to it's own recipe for all keys in the /tmp directory for Jewel and later...
execute 'format bootstrap-osd-secret as keyring' do
  command lazy { "ceph-authtool '/var/lib/ceph/bootstrap-osd/#{node['ceph']['cluster']}.keyring' --create-keyring --name=client.bootstrap-osd --add-key=#{ceph_chef_bootstrap_osd_secret}" }
  only_if { ceph_chef_bootstrap_osd_secret }
  not_if "test -f /var/lib/ceph/bootstrap-osd/#{node['ceph']['cluster']}.keyring"
  sensitive true if Chef::Resource::Execute.method_defined? :sensitive
end

# NOTE: Don't want to do any 'ceph' calls until a quorum has been established or the ceph-create-keys python script will sit in a constant wait state...
# BOOTSTRAP_KEY=`ceph --name mon. --keyring /etc/ceph/#{node['ceph']['cluster']}.mon.keyring auth get-or-create-key client.bootstrap-osd mon 'allow profile bootstrap-osd'`
bash 'save-bootstrap-osd-key' do
  code <<-EOH
    BOOTSTRAP_KEY=$(ceph-authtool "/etc/ceph/#{node['ceph']['cluster']}.mon.keyring" -n mon. -p)
    ceph-authtool "/var/lib/ceph/bootstrap-osd/#{node['ceph']['cluster']}.keyring" \
        --create-keyring \
        --name=client.bootstrap-osd \
        --add-key="$BOOTSTRAP_KEY"
  EOH
  not_if { ceph_chef_bootstrap_osd_secret }
  not_if "test -f /var/lib/ceph/bootstrap-osd/#{node['ceph']['cluster']}.keyring"
  notifies :create, 'ruby_block[save_bootstrap_osd]', :immediately
  sensitive true if Chef::Resource::Execute.method_defined? :sensitive
end

# Part of monitor-secret calls above - Also, you can set node['ceph']['monitor-secret'] = ceph_chef_keygen()
# in a higher level recipe like the way ceph-chef does it in ceph-mon.rb
ruby_block 'save_bootstrap_osd' do
  block do
    fetch = Mixlib::ShellOut.new("ceph-authtool '/var/lib/ceph/bootstrap-osd/#{node['ceph']['cluster']}.keyring' --print-key --name=client.bootstrap-osd")
    fetch.run_command
    key = fetch.stdout
    ceph_chef_save_bootstrap_osd_secret(key.delete!("\n"))
  end
  action :nothing
end

# Make sure the bootstrap-osd key is set for the node. Could have a wrapper move the file to the correct place but the var is not set.
ruby_block 'check_bootstrap_osd' do
  block do
    fetch = Mixlib::ShellOut.new("ceph-authtool '/var/lib/ceph/bootstrap-osd/#{node['ceph']['cluster']}.keyring' --print-key --name=client.bootstrap-osd")
    fetch.run_command
    key = fetch.stdout
    ceph_chef_save_bootstrap_osd_secret(key.delete!("\n"))
  end
  not_if { ceph_chef_bootstrap_osd_secret }
  only_if "test -f /var/lib/ceph/bootstrap-osd/#{node['ceph']['cluster']}.keyring"
end

# IF the bootstrap key for bootstrap-rgw exists then save it so it's available if wanted later. All bootstrap
# keys are created during this recipe process!
ruby_block 'save_bootstrap_rgw' do
  block do
    fetch = Mixlib::ShellOut.new("ceph-authtool '/var/lib/ceph/bootstrap-rgw/#{node['ceph']['cluster']}.keyring' --print-key --name=client.bootstrap-rgw")
    fetch.run_command
    key = fetch.stdout
    ceph_chef_save_bootstrap_rgw_secret(key.delete!("\n"))
  end
  not_if { ceph_chef_bootstrap_rgw_secret }
  only_if "test -f /var/lib/ceph/bootstrap-rgw/#{node['ceph']['cluster']}.keyring"
  ignore_failure true
end

# IF the bootstrap key for bootstrap-mds exists then save it so it's available if wanted later
ruby_block 'save_bootstrap_mds' do
  block do
    fetch = Mixlib::ShellOut.new("ceph-authtool '/var/lib/ceph/bootstrap-mds/#{node['ceph']['cluster']}.keyring' --print-key --name=client.bootstrap-mds")
    fetch.run_command
    key = fetch.stdout
    ceph_chef_save_bootstrap_mds_secret(key.delete!("\n"))
  end
  not_if { ceph_chef_bootstrap_mds_secret }
  only_if "test -f /var/lib/ceph/bootstrap-mds/#{node['ceph']['cluster']}.keyring"
  ignore_failure true
end
