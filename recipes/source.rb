#
# Author::  Seth Chisamore (<schisamo@opscode.com>)
# Cookbook Name:: php
# Recipe:: package
#
# Copyright 2011, Opscode, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

configure_options = node['php']['configure_options'].join(" ")

include_recipe "build-essential"
include_recipe "xml"
include_recipe "mysql::client" if configure_options =~ /mysql/

pkgs = value_for_platform(
    ["centos","redhat","fedora", "scientific"] =>
        {"default" => %w{ bzip2-devel libc-client-devel curl-devel freetype-devel gmp-devel libjpeg-devel krb5-devel libmcrypt-devel libpng-devel openssl-devel t1lib-devel mhash-devel }},
    [ "debian", "ubuntu" ] =>
        {"default" => %w{ libbz2-dev libc-client2007e-dev libcurl4-gnutls-dev libfreetype6-dev libgmp3-dev libjpeg62-dev libkrb5-dev libmcrypt-dev libpng12-dev libssl-dev libt1-dev }},
    "default" => %w{ libbz2-dev libc-client2007e-dev libcurl4-gnutls-dev libfreetype6-dev libgmp3-dev libjpeg62-dev libkrb5-dev libmcrypt-dev libpng12-dev libssl-dev libt1-dev }
  )

pkgs.each do |pkg|
  package pkg do
    action :install
  end
end

version = node['php']['version']

ruby_block "get source archive and unpack" do
  block do
    remote_path = "#{node['php']['url']}/php-#{version}.tar.gz"
    local_build_directory = "#{Chef::Config[:file_cache_path]}/php-#{version}"
    local_path = "#{local_build_directory}.tar.gz"
    raise Exception, "wget failed. url: #{remote_path}" unless `wget #{remote_path} -O #{local_path} >/dev/null 2>&1; echo $?`.strip.to_i === 0
    `rm -rf #{local_build_directory}`
    raise Exception, "unpack failed. path: #{local_path}" unless `cd $(dirname #{local_path}) >/dev/null 2>&1 && tar zxf php-#{version}.tar.gz >/dev/null 2>&1; echo $?`.strip.to_i === 0
  end
  retries 5
  not_if "which php"
end

bash "build php" do
  cwd Chef::Config[:file_cache_path]
  code <<-EOF
  (cd php-#{version} && ./configure #{configure_options})
  (cd php-#{version} && make && make install)
  EOF
  not_if "which php"
end

directory node['php']['conf_dir'] do
  owner "root"
  group "root"
  mode "0755"
  recursive true
end

directory node['php']['ext_conf_dir'] do
  owner "root"
  group "root"
  mode "0755"
  recursive true
end

template "#{node['php']['conf_dir']}/php.ini" do
  extension_dir = `php-config --extension-dir 2>/dev/null`.strip
  node.set['php']['ext_dir'] = extension_dir
  source "php.ini.erb"
  owner "root"
  group "root"
  mode "0644"
end
