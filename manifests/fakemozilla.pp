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

  # The scm_ groups are used to control write permissions to repositories.
  # These groups come from LDAP. We hard-code them here.
  group { 'scm_level_1':
    gid => 650,
  }
  group { 'scm_level_2':
    gid => 651,
  }
  group { 'scm_level_3':
    gid => 652,
  }
  group { 'scm_l10n':
    gid => 653,
  }
  group { 'scm_l10n_infra':
    gid => 654,
  }
  group { 'scm_sec_sensitive':
    gid => 655,
  }
  group { 'scm_ecmascript':
    gid => 656,
  }

}
