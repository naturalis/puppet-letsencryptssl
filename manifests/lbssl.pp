# == Class: role_lamp::ssl
#
# ssl code for enabline ssl with or without letsencrypt
#
# Author Name <hugo.vanduijn@naturalis.nl>
#
#
define letsencryptssl::lbssl (
  $letsencrypt_domains,
  $letsencrypt_server   = 'https://acme-staging-v02.api.letsencrypt.org/directory',
  $cert_file            = "/etc/letsencrypt/live/${letsencrypt_domains[0]}/cert.pem",
  $cert_name            = $title,
  $cert_renew_days      = '30', # don't set this higher than 30 due to --keep-until-renewal option
  $cert_warning_days    = '14',
  $cert_critical_days   = '7',
)
{


  $install_command_start = "certbot --server ${letsencrypt_server} certonly --manual --email aut@naturalis.nl --manual-public-ip-logging-ok --agree-tos --non-interactive --preferred-challenges dns --expand --keep-until-expiring --config-dir /etc/letsencrypt --logs-dir /var/log/letsencrypt --work-dir ./ --manual-auth-hook ./auth-hook --manual-cleanup-hook ./cleanup-hook "
  $install_command_domains = inline_template('-d <%= @letsencrypt_domains.join(" -d ")%>')
  $install_command = "${install_command_start}${install_command_domains}"


# install letsencrypt certs only and crontab
  exec { "letsencrypt install cert ${title}":
    command     => "echo ${install_command} > /opt/installcert.sh",
    path        => ['/usr/local/sbin','/usr/local/bin','/usr/sbin','/usr/bin','/sbin','/bin','/snap/bin',],
    require     => Package['certbot'],
    onlyif      => "/usr/local/sbin/chkcert_${title}.sh | grep renew 2>/dev/null"
  }


# create check script from template
  file { "/usr/local/sbin/chkcert_${title}.sh":
    mode    => '0755',
    content => template('letsencryptssl/checkcert.sh.erb'),
  }

# create command for renewal of certificate

  $command_start = "certbot --server ${letsencrypt_server} certonly --manual --agree-tos --non-interactive --preferred-chalenges dns --expand --keep-until-expiring --config-dir /etc/letsencrypt --logs-dir /var/log/letsencrypt --work-dir ./ --manual-auth-hook ./auth-hook --manual-cleanup-hook ./cleanup-hook "
  $command_domains = inline_template('-d <%= @letsencrypt_domains.join(" -d ")%>')
  $command = "${command_start}${command_domains}"


#  exec { "letsencrypt renew cert ${title}":
#    command     => $command,
#    path        => ['/usr/local/sbin','/usr/local/bin','/usr/sbin','/usr/bin','/sbin','/bin','/snap/bin',],
#    require     => Package['certbot'],
#    onlyif      => "/usr/local/sbin/chkcert_${title}.sh | grep renew 2>/dev/null"
#  }

# export check so sensu monitoring can make use of it
  @sensu::check { "Check certificate ${title}":
    command => "/usr/local/sbin/chkcert_${title}.sh sensu",
    tag     => 'central_sensu',
}


}

