# == Class: letsencryptssl
#
#
# === Authors
#
# Author Name <hugo.vanduijn@naturalis.nl>
#
#
class letsencryptssl (
  $letsencrypt_hash        = { 'puppet4-foreman-prd' => { 'letsencrypt_server' => 'https://acme-v02.api.letsencrypt.org/directory', 'letsencrypt_domains' => ['puppet4-foreman-prd-001.naturalis.nl']}},
  $letsencrypt_email            = 'aut@naturalis.nl',
  $transip_api_url              = 'https://api.transip.nl/downloads',
  $transip_api_file             = 'transapi_transip.nl_v5_8.tar.gz',
  $script_url                   = '/opt/letsencryptssl',
  $certbotvalidator_repo        = 'https://github.com/roy-bongers/certbot-transip-dns-01-validator.git',
  $packages                     = ['git','php','php-soap','php-xml'],
  $transip_login,
  $transip_privatekey,
  $certbot_ssh_server_pubkey    = '<PUBLIC KEY>',
){

# ensure required packages are installed
  ensure_packages($packages)

# create script_url ( main working directory)
  file { $script_url:
    ensure             => directory,
    mode               => '0700',
  }

# install and configure TransIP API
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
  } ->
  file_line { 'Add CAA type':
    path     => "${script_url}/Transip/DnsEntry.php",
    line     => "    const TYPE_CAA = 'CAA';",
    after    => "const\ TYPE_SRV\ =\ \'SRV\'\;"
  }

# clone certbotvalidator
  vcsrepo { "${script_url}/certbotvalidator":
      ensure    => present,
      provider  => 'git',
      source    => $certbotvalidator_repo,
      user      => 'root',
      revision  => 'master',
      require   => [Package['git'],File[$script_url]]
  }

# create symlinks for validators into script_dir
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

# customized hooks.php which include making backup of domain.
  file { "${script_url}/hooks.php":
    mode        => '0600',
    content     => template('letsencryptssl/hooks.php.erb'),
    ensure      => 'file',
  }

# rescue DNS script
  file { "${script_url}/rescuedns.php":
    mode        => '0600',
    content     => template('letsencryptssl/rescuedns.php.erb'),
    ensure      => 'file',
  }


# TransIP API uses short_open_tags, those are not enabled by default
  file_line { 'Enable short_open_tag in php':
    ensure            => present,
    path              => '/etc/php/7.0/cli/php.ini',
    line              => 'short_open_tag = On',
    match             => '^short_open_tag = Off',
    require           => Package['php']
  }

# Install certbot using custom apt repository
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

# adding public key for accessing cert store from remote server
  ssh_authorized_key { 'getcerts@root':
    user        => 'root',
    type        => 'ssh-rsa',
    key         => $certbot_ssh_server_pubkey,
  }

# create certificates based on hash
  create_resources('letsencryptssl::createcert', $letsencrypt_hash,{})


}