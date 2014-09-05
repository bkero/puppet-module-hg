# Configures a Puppet environment that's similar enough to Mozilla's Puppet
# environment to facilitate testing.

class hg::fakemozilla {
  # Pull in Mozilla's package repository.
  yumrepo { 'mozilla':
    name     => 'Mozilla Package Repo - $basearch',
    baseurl  => 'https://mrepo.mozilla.org/mrepo/$releasever-$basearch/RPMS.mozilla',
    gpgcheck => 0,
    notify   => Exec['yum-check-update'],
  }

  exec { 'yum-check-update':
    command     => '/usr/bin/yum check-update',
    refreshonly => true,
    returns     => [0, 100],
  }

  # Collectd is used for metrics collection.
  package { 'collectd':
    ensure        => present,
    allow_virtual => false,
    require       => Exec['yum-check-update'],
  }

  # Create a user for Mercurial. The actual uid and gid varies from the real
  # world, but that's OK.
  user { 'hg':
    uid     => 5500,
    gid     => 'hg',
    comment => 'Hg user',
    shell   => '/bin/bash',
  }
  group { 'hg':
    gid => 5500,
  }

}
