letsencryptssl
===================

Puppet role definition for requesting ssl certificates using transip dns hooks. 
- letsencryptssl main manifest for requesting certificates
- createcert create certificates, checks and renewal cronjob
- getcerts will fetch all certificates from cert server to puppet server or somewhere else
- install cert will install a certificate on a server

Parameters
-------------
Sensible defaults for Naturalis in init.pp.

```
```


Classes
-------------
- letsencryptssl
- letsencryptssl::getcerts
- letsencryptssl::installcert
- letsencryptssl::createcert

Dependencies
-------------


Puppet code
```
class { letsencryptssl: }
```
Result
-------------

Limitations
-------------
This module has been built on and tested against Puppet 4 and higher.


The module has been tested on:
- Ubuntu 16.04LTS

Authors
-------------
Author Name <hugo.vanduijn@naturalis.nl>

