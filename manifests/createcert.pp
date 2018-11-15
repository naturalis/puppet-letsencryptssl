# == Class: role_lamp::ssl
#
# ssl code for enabline ssl with or without letsencrypt
#
# Author Name <hugo.vanduijn@naturalis.nl>
#
#
define letsencryptssl::createcert (
  $letsencrypt_domains,
  $letsencrypt_server   = 'https://acme-staging-v02.api.letsencrypt.org/directory',
  $cert_file            = "/etc/letsencrypt/${letsencrypt_domains[0]}/live/${letsencrypt_domains[0]}/cert.pem",
  $cert_name            = $title,
  $cert_renew_days      = '30', # don't set this higher than 30 due to --keep-until-renewal option
  $cert_warning_days    = '14',
  $cert_critical_days   = '7',
)
{

# create request certificate script from template
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

# create random weekly renewal cronjob
  cron { "certbot ${title} renewal job":
    command     => "certbot renew --config-dir /etc/letsencrypt/${letsencrypt_domains[0]}",
    weekday     => fqdn_rand(6,$title),
    hour        => fqdn_rand(23,$title),
    minute      => fqdn_rand(59,$title),
  }

# create check script from template
  file { "/usr/local/sbin/chkcert_${title}.sh":
    mode    => '0755',
    content => template('letsencryptssl/checkcert.sh.erb'),
  }

# create add CAA dns records script from template
  file { "/opt/letsencryptssl/create_CAA_${title}.php":
    mode    => '0755',
    content => template('letsencryptssl/create_CAA.php.erb'),
    notify  => Exec["Add CAA records for ${title}"]
  }

# run CAA script only when script is created or changed.
  exec { "Add CAA records for ${title}":
    refreshonly => true,
    cwd         => "/opt/letsencryptssl",
    command     => "php /opt/letsencryptssl/create_CAA_${title}.php",
    path        => ['/usr/local/sbin','/usr/local/bin','/usr/sbin','/usr/bin','/sbin','/bin','/snap/bin',],
  }


# Add sudoers lines
  $sudoers_array = ["sensu ALL = (root) NOPASSWD : /usr/local/sbin/chkcert_${title}.sh"]
  $sudoers_array.each |String $sudoers_line| {
    file_line {$sudoers_line:
      path   => '/etc/sudoers',
      line   => $sudoers_line
    }
  }

# export check so sensu monitoring can make use of it
  @sensu::check { "Check certificate ${title}":
    command => "sudo /usr/local/sbin/chkcert_${title}.sh",
    tag     => 'central_sensu',
  }

}

