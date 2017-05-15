#app_name = fit...zig..r..ald
class passwd {
  $application_database = 'app_name'
}

package { 'git': ensure=> installed }

include repos

## Uncomment if your project needs RabbitMQ
# class rmq {
#     class {'rabbitmq':
#         admin_enable => true,
#         default_user => 'user_name',
#         default_pass => 'user_pass',
#     }
#     rabbitmq_vhost {'/appname':
#         ensure => present }
#     rabbitmq_user_permissions {'appname@/user_name':
#         configure_permission => '.*',
#         read_permission      => '.*',
#         write_permission     => '.*',
#     }
# }
# include rmq

# Class['appname'] defines the postgresql::globals (and therefore version
# info) so we create this later on
class psql_db {
  Class['postgresql::globals']
  ->
  class { 'postgresql::server':
    ip_mask_deny_postgres_user  => '0.0.0.0/32',
    ip_mask_allow_all_users     => '0.0.0.0/0',
    listen_addresses            => '*',
    ipv4acls                    => ['host all all 0.0.0.0/0 md5'],
    manage_firewall             => true,
    postgres_password           => 'postgres',
  }

  # This provides hstore, uuid-ossp.
  class { 'postgresql::server::contrib': }
  ->
  postgresql::server::db { 'appname':
      user     => 'appname',
      password => 'appname',
  }
  ->
  exec { 'appname-psql-su':
      command => '/usr/bin/psql -c "ALTER USER appname WITH SUPERUSER;"',
      user    => 'postgres',
  }
}

exec { 'iptables-flush-and-save':
    command => '/etc/init.d/iptables save',
    user    => 'root',
    onlyif  => '/sbin/iptables -F',
    require => [Class['psql_db']],
}

class { 'app_name::vagrant':
  db_host     => 'localhost',
  db_password => 'password',
  db_username => 'username',
  system_user => 'vagrant',
}
->
class {'psql_db': }
## Uncomment if you need Postgres's hstore extension.
# ->
# postgresql_psql {
#   'Make sure that hstore is enabled':
#   db => 'template1',
#   command =>'CREATE EXTENSION IF NOT EXISTS hstore;',
# }
->
file { '/opt/venvs/':
  ensure => 'directory',
  owner => 'vagrant',
  group => 'vagrant',
  mode => 755,
}
->
exec { 'initialize-app_name-virtualenv':
  command => '/opt/python/2.7.6/bin/virtualenv /opt/venvs/app_name',
  user => 'vagrant',
  creates => '/opt/venvs/app_name/',
}
->
exec { 'development-install-app_name':
 command => '/opt/venvs/app_name/bin/pip install -r /src/app_name/requirements.txt -r /src/app_name/requirements_test.txt',
 user => 'vagrant',
 cwd => '/src/app_name/',
 path => '/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin:/home/vagrant/bin:/usr/pgsql-9.3/bin/:$PATH',
}

# By default, have virtualenv activated when logged in.
exec { 'activate-app_name-venv':
  command => "/bin/echo 'source /opt/venvs/app_name/bin/activate' >> /home/vagrant/.bashrc",
  user => 'vagrant',
  unless => "/bin/grep -q /opt/venvs/app_name/bin/activate /home/vagrant/.bashrc; /usr/bin/test $? -eq 0",
}

# development requirements
package {
  # building libraries needed for SSO client connections
  'python-devel':
    ensure => installed;
  'libffi-devel':
    ensure => installed;
  'openssl-devel':
    ensure => installed;
}
