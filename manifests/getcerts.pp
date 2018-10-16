# == Class: letsencryptssl::getcerts
#
#
# === Authors
#
# Author Name <hugo.vanduijn@naturalis.nl>
#
#
class letsencryptssl::getcerts (
  $cert_server              = '145.136.242.64',
  $cert_server_ssh_user     = 'root',
  $cert_server_ssh_privkey  = '<PRIVKEY HERE>',
  $cert_server_dir          = '/etc/letsencrypt/',
  $local_dir                = '/etc/puppetlabs/code/environments/production/modules/letsencryptssl/files/'
){

# create private key file for accessing cert server
  file { '/root/.ssh/certbot.key':
    content => $cert_server_ssh_privkey,
    mode    => '0600',
  }

# create cron for fetching certificates using rsync 4 times a day. 
  cron { 'getcerts':
    command     => "rsync -rulmog --delete -f'- accounts' -f='- csr' -f='- keys' -f='- renewal' --chown=puppet:puppet -e 'ssh -i /root/.ssh/certbot.key' ${cert_server_ssh_user}@${cert_server}:${cert_server_dir} ${local_dir}",
    user        => root,
    hour        => '*/6',
    minute      => '30',
  }

# exec ssh-keyscan for adding cert server to known_hosts
  exec { "ssh_known_host_${cert_server}":
    command => "/usr/bin/ssh-keyscan ${cert_server} >> /root/.ssh/known_hosts",
    unless  => "/bin/grep ${cert_server} /root/.ssh/known_hosts",
    user    => 'root',
  }
}

