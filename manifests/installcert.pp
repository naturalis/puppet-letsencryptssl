# == Class: letsencryptssl::installcert
#
#
# === Authors
#
# Author Name <hugo.vanduijn@naturalis.nl>
#
#
class letsencryptssl::installcert (
  $cert_array               = [],
  $cert_webservice          = 'apache2',
  $docker                   = false,
  $docker_container         = 'app_apache_1',
){

# create dirs
  file { ['/etc/letsencrypt','/etc/letsencrypt/live']:
    ensure         => 'directory'
  }

# loop through cert_array install files on server and notify changes
  $cert_array.each |String $cert| {
    file { "/etc/letsencrypt/$cert":
      source       => "puppet:///modules/letsencryptssl/$cert/",
      purge        => true,
      recurse      => true,
      mode         => '0600',
      recurselimit => 3,
      notify       => Exec['reload webservice'],
    }
    file { "/etc/letsencrypt/live/$cert":
      ensure       => 'link',
      target       => "/etc/letsencrypt/${cert}/live/${cert}",
      force        => true,
      require      => [File["/etc/letsencrypt/$cert"],File['/etc/letsencrypt/live']]
    }
  }

# define reload command based on variables
  if ($docker == true){
    $reloadcommand = "docker exec ${docker_container} service ${cert_webservice} reload"
  }else{
    $reloadcommand = "service ${cert_webservice} reload"
  }

# reload webservice when cert is installed
  exec {'reload webservice':
    command      => $reloadcommand,
    path         => '/usr/bin:/usr/sbin:/bin',
    refreshonly  => true
  }

}

