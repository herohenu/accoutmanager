require 'mina/bundler'
require 'mina/rails'
require 'mina/git'
# require 'mina/rbenv'  # for rbenv support. (http://rbenv.org)
require 'mina/rvm'    # for rvm support. (http://rvm.io)

# Basic settings:
#   domain       - The hostname to SSH to.
#   deploy_to    - Path to deploy into.
#   repository   - Git repo to clone from. (needed by mina/git)
#   branch       - Branch name to deploy. (needed by mina/git)

set :domain, '192.168.1.5'
set :deploy_to, '/home/git/deploy'
set :repository, 'git@fitark.org:leiyinghao/am.git'
set :branch, 'master'
set :term_mode, :system
# Manually create these paths in shared/ (eg: shared/config/database.yml) in your server.
# They will be linked in the 'deploy:link_shared_paths' step.
set :shared_paths, ['config/database.yml', 'log']

# Optional settings:
   set :user, 'git'    # Username in the server to SSH to.
#   set :port, '30000'     # SSH port number.

# This task is the environment that is loaded for most commands, such as
# `mina deploy` or `mina rake`.
task :environment do
  # If you're using rbenv, use this to load the rbenv environment.
  # Be sure to commit your .rbenv-version to your repository.
  # invoke :'rbenv:load'

  # For those using RVM, use this to load an RVM version@gemset.
  invoke :'rvm:use[ruby-1.9.3-p385@default]'
end

# Put any custom mkdir's in here for when `mina setup` is ran.
# For Rails apps, we'll make some of the shared paths that are shared between
# all releases.
task :setup => :environment do
  queue! %[mkdir -p "#{deploy_to}/shared/log"]
  queue! %[chmod g+rx,u+rwx "#{deploy_to}/shared/log"]

  queue! %[mkdir -p "#{deploy_to}/shared/config"]
  queue! %[chmod g+rx,u+rwx "#{deploy_to}/shared/config"]

  queue! %[touch "#{deploy_to}/shared/config/database.yml"]
  queue  %[echo "-----> Be sure to edit 'shared/config/database.yml'."]
end

desc "Deploys the current version to the server."
task :deploy => :environment do
  deploy do
    # Put things that will set up an empty directory into a fully set-up
    # instance of your project.
    invoke :'git:clone'
    invoke :'deploy:link_shared_paths'
    invoke :'bundle:install'
    invoke :'rails:db_migrate'
    invoke :'rails:assets_precompile'

    to :launch do
      queue! %[mkdir -p "#{deploy_to}/current/tmp/pids"]
      queue! %[chmod g+rx,u+rwx "#{deploy_to}/current/tmp/pids"]
    end
  end
end

# For help in making your deploy script, see the Mina documentation:
#
#  - http://nadarei.co/mina
#  - http://nadarei.co/mina/tasks
#  - http://nadarei.co/mina/settings
#  - http://nadarei.co/mina/helpers



task :down do
  invoke :maintenance_on
  #invoke :restart
end
task :maintenance_on  do
  #queue 'touch maintenance.txt'
  #杀死 unicorn  重启
  queue! %[  ps aux |grep unicorn|grep -v grep |awk '{print $2}'|xargs kill -9 ]
  #queue! %[ unicorn_rails -c "#{deploy_to}/current/config/unicorn.rb -D  -E production" ]
  queue! %[rainbows config.ru -c "#{deploy_to}/current/config/unicorn.rb -E production -D "]
end


#____________________mina 使用说明________________________________
#第一次部署项目时候  mina setup  需要编辑服务器上的 database.yml
# mina deploy  需要将key放在.ssh目录下
# mina deploy 失败锁定的时候用下面的命令强制解锁
# mina deploy:force_unlock
# 部署时候要新建数据库 prometheus_production
#      ps aux |grep unicorn|grep -v grep |awk '{print $2}'|xargs kill -9
#unicorn_rails -c ~/deploy/current/config/unicorn.rb -D  -E production

# rainbows config.ru -c config/unicorn.rb -E production -D
#nginx 配置

=begin
————————————————————————————nginx 配置 start——————————————————————————————————————————————————————
cd  /etc/nginx/sites-available/
sudo  mv default  default.bak

sudo vi prometheus
 -------------粘贴下面内容-------------begin------------->
uptream myapp_prometheus {
  server  unix:/tmp/unicorn.prometheus.sock;
}
server {
    listen   9000;
    server_name localhost;

#   access_log /home/git/hmp/log/access.log;
#    error_log  /home/git/hmp/log/error.log;
#    root       /home/git/deploy/current/public;;
    index      index.html;

    location / {
        proxy_set_header  X-Real-IP  $remote_addr;
        proxy_set_header  X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header  Host $http_host;
        proxy_redirect    off;
        try_files /system/maintenance.html $uri $uri/index.html $uri.html @ruby;
    }

    location @ruby {
        proxy_pass http://myapp_prometheus;
    }
}

-------------------------------end-------->
 sudo ln  -nfs  /etc/nginx/sites-available/prometheus   /etc/nginx/sites-enabled/prometheus

sudo /etc/init.d/nginx  start

如果启动失败察看日志
cd /var/log/nginx/
cat error.log

需要先启动unicorn






————————————————————————————nginx 配置 end——————————————————————————————————————————————————————
=end



