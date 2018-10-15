# == Class: letsencryptssl
#
#
# === Authors
#
# Author Name <hugo.vanduijn@naturalis.nl>
#
#
class letsencryptssl (
  Hash $letsencrypt_hash        = { 'puppet4-foreman-prd' => { 'letsencrypt_server' => 'https://acme-v02.api.letsencrypt.org/directory', 'letsencrypt_domains' => ['puppet4-foreman-prd-001.naturalis.nl']}},
  $letsencrypt_email            = 'aut@naturalis.nl',
  $transip_api_url              = 'https://api.transip.nl/downloads',
  $transip_api_file             = 'transapi_transip.nl_v5_8.tar.gz',
  $script_url                   = '/opt/letsencryptssl',
  $certbotvalidator_repo        = 'https://github.com/roy-bongers/certbot-transip-dns-01-validator.git',
  $packages                     = ['git','php','php-soap','php-xml'],
  $transip_login,
  $transip_privatekey,
){

  ensure_packages($packages)

  file { $script_url:
    ensure             => directory,
    mode               => '0700',
  }

  exec { 'download and unpack transip API':
      command        => "/usr/bin/wget ${transip_api_url}/${transip_api_file} -O ${script_url}/${transip_api_file} && /bin/tar -xf ${script_url}/${transip_api_file} -C ${script_url}",
      unless         => "/usr/bin/test -f ${script_url}/${transip_api_file}",
      require        => File[$script_url]
  } ->
  file { "${script_url}/Transip/ApiSettings.php":
    ensure   => file,
    mode     => '0600',
    content  => template('letsencryptssl/apisettings.php.erb'),
    require  => File[$script_url]
  }

  vcsrepo { "${script_url}/certbotvalidator":
      ensure    => present,
      provider  => 'git',
      source    => $certbotvalidator_repo,
      user      => 'root',
      revision  => 'master',
      require   => [Package['git'],File[$script_url]]
  }

  file { "${script_url}/auth-hook":
    ensure      => 'link',
    target      => "${script_url}/certbotvalidator/auth-hook",
    require     => Vcsrepo["${script_url}/certbotvalidator"]
  }

  file { "${script_url}/cleanup-hook":
    ensure      => 'link',
    target      => "${script_url}/certbotvalidator/cleanup-hook",
    require     => Vcsrepo["${script_url}/certbotvalidator"]
  }

 file { "${script_url}/dns.php":
    ensure      => 'link',
    target      => "${script_url}/certbotvalidator/dns.php",
    require     => Vcsrepo["${script_url}/certbotvalidator"]
  }

  file { "${script_url}/hooks.php":
    ensure      => 'link',
    target      => "${script_url}/certbotvalidator/hooks.php",
    require     => Vcsrepo["${script_url}/certbotvalidator"]
  }

  file_line { 'Enable short_open_tag in php':
    ensure            => present,
    path              => '/etc/php/7.0/cli/php.ini',
    line              => 'short_open_tag = On',
    match             => '^short_open_tag = Off',
    require           => Package['php']
  }

  # Install required certbot
  class { 'apt': }
  apt::key { 'certbot':
    id      => '7BF576066ADA65728FC7E70A8C47BE8E75BCA694',
    server  => 'pgp.mit.edu',
    notify  => Exec['apt_update']
  }

  apt::ppa { 'ppa:certbot/certbot': }

  package { 'certbot':
    ensure  => present,
    require => [Class['apt::update'],Apt::Ppa['ppa:certbot/certbot'],Apt::Key['certbot']]
  }

  create_resources('letsencryptssl::lbssl', $letsencrypt_hash,{})

# create cron task to renew certificates every 15 minutes
  cron { 'certbot renew':
    command     => 'certbot --renew',
    user        => root,
    hour        => '*/6',
  }



}