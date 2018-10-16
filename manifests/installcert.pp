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
  Boolean $docker           = false,
  $docker_container         = 'app_apache_1',
){

# loop through cert_array install files on server and notify changes 
  $cert_array.each |String $cert| {
    file { "/etc/letsencrypt/":
      source       => "puppet:///modules/letsencryptssl/$cert",
      purge        => true,
      recurse      => true,
      mode         => '0600',
      recurselimit => 3,
      notify       => Exec['reload webservice'],
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

