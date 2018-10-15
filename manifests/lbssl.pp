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

# create script from template
  file { "/usr/local/sbin/create_cert_${title}.sh":
    mode    => '0755',
    content => template('letsencryptssl/create_cert.sh.erb'),
    notify  => Exec["letsencrypt install cert ${title}"]
  }

# install letsencrypt certs only and crontab with adjusted timeout of 1800 (300 is default and may be too short) 
  exec { "letsencrypt install cert ${title}":
    refreshonly => true,
    command     => "/usr/local/sbin/create_cert_${title}.sh",
    path        => ['/usr/local/sbin','/usr/local/bin','/usr/sbin','/usr/bin','/sbin','/bin','/snap/bin',],
    require     => Package['certbot'],
    timeout     => 1800,
  }

# create check script from template
  file { "/usr/local/sbin/chkcert_${title}.sh":
    mode    => '0755',
    content => template('letsencryptssl/checkcert.sh.erb'),
  }

# export check so sensu monitoring can make use of it
  @sensu::check { "Check certificate ${title}":
    command => "/usr/local/sbin/chkcert_${title}.sh sensu",
    tag     => 'central_sensu',
}


}

