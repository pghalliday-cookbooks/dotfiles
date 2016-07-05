login_user = node['dotfiles']['user']
login_group = node['dotfiles']['group']
login_home = node['dotfiles']['home']
id_rsa = node['dotfiles']['ssh']['id_rsa']
authorized_keys = node['dotfiles']['ssh']['authorized_keys']

ssh_dir = ::File.join login_home, '.ssh'
id_rsa_file = ::File.join ssh_dir, 'id_rsa'
authorized_keys_file = ::File.join ssh_dir, 'authorized_keys'
dotfiles_dir = ::File.join login_home, 'pghalliday-dotfiles'
dotfiles_scripts_dir = ::File.join dotfiles_dir, 'scripts'

directory ssh_dir do
  owner login_user
  group login_user
  mode 0700
end

file id_rsa_file do
  content ::File.read id_rsa
  owner login_user
  group login_group
  mode 0600
end

file authorized_keys_file do
  content ::File.read authorized_keys
  owner login_user
  group login_group
  mode 0600
end

bash 'github_known_host' do
  code <<-EOH
  ssh-keyscan -t rsa github.com >> #{ssh_dir}/known_hosts
  EOH
  user login_user
  not_if "grep -e '^github.com\\(,[^ ]*\\)\\? ' #{ssh_dir}/known_hosts"
end

bash 'root_github_known_host' do
  code <<-EOH
  ssh-keyscan -t rsa github.com >> /root/.ssh/known_hosts
  EOH
  not_if "grep -e '^github.com\\(,[^ ]*\\)\\? ' /root/.ssh/known_hosts"
end

directory dotfiles_dir do
  owner login_user
  group login_group
end

# get latest git
apt_repository 'git' do
  uri 'ppa:git-core/ppa'
  distribution node['lsb']['codename']
end

%w{
openssh-server
git
vim
tmux
}.each do |name|
  package name do
    action :upgrade
  end
end

git dotfiles_scripts_dir do
  repository 'git@github.com:pghalliday-dotfiles/scripts.git'
  user login_user
  group login_group
  enable_checkout false
  checkout_branch 'master'
  revision 'master'
  action :sync
  notifies :run, 'bash[setup_dotfiles]', :immediately
  notifies :run, 'bash[setup_root_dotfiles]', :immediately
end

bash 'setup_dotfiles' do
  code <<-EOH
  set -e
  export HOME=#{login_home}
  #{dotfiles_scripts_dir}/terminal-setup.sh
  EOH
  user login_user
  action :nothing
end

bash 'setup_root_dotfiles' do
  code <<-EOH
  set -e
  export HOME=/root
  #{dotfiles_scripts_dir}/terminal-setup.sh
  EOH
  action :nothing
end
