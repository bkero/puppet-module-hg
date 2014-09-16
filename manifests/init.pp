# base class from which other hg hosts are derived. Contains any
# common directives that are needed by all nodes in the hg infra
class hg {

    if defined(Yumrepo['epel']) { realize(Yumrepo['epel']) }
    if defined(Yumrepo['mozilla']) { realize(Yumrepo['mozilla']) }
    if defined(Package['subversion']) { realize(Package['subversion']) }
      else { package { 'subversion': ensure => installed } }

    package {
        [
        'python-pygments',
        'python-simplejson',
        'python-argparse',
        ]:
            ensure  => present;
    }
    if defined(Yumrepo['mozilla']) {
        package { 'mercurial': ensure  => present,
                            require    => Yumrepo['mozilla'];
        }
    }
    else {
        package { 'mercurial':
            ensure   => present,
        }
    }

    file { [
        '/repo',
        '/repo_local',
        '/repo_local/mozilla',
        '/repo_local/mozilla/mozilla',
        '/repo_local/mozilla/libraries',
    ]:
        ensure => directory,
        mode   => '775',
    }

    file { '/repo/hg':
      ensure => link,
      target => '/repo_local/mozilla',
    }

    vcsrepo { 'hg_template':
      path     => '/repo_local/mozilla/hg_templates',
      source   => 'https://hg.mozilla.org/hgcustom/hg_templates',
      provider => hg,
      ensure   => present,
      require  => File['/repo_local/mozilla'],
    }

    vcsrepo { 'pushlog':
      path     => '/repo_local/mozilla/extensions',
      source   => 'https://hg.mozilla.org/hgcustom/pushlog',
      provider => hg,
      ensure   => present,
      require  => File['/repo_local/mozilla'],
    }

    vcsrepo { 'library_overrides':
      path     => '/repo_local/mozilla/library_overrides',
      source   => 'https://hg.mozilla.org/hgcustom/library_overrides',
      provider => hg,
      ensure   => present,
      require  => File['/repo_local/mozilla'],
    }

    vcsrepo { 'version-control-tools':
      path     => '/repo_local/mozilla/version-control-tools',
      source   => 'https://hg.mozilla.org/hgcustom/version-control-tools',
      provider => hg,
      ensure   => present,
      require  => File['/repo_local/mozilla'],
    }

    vcsrepo { 'venkman':
      path     => '/repo_local/mozilla/mozilla/venkman',
      source   => 'https://hg.mozilla.org/venkman',
      provider => hg,
      ensure   => present,
      require  => File['/repo_local/mozilla/mozilla'],
    }

    file { '/repo_local/mozilla/libraries/mozhghooks':
      ensure  => link,
      target  => '/repo_local/mozilla/version-control-tools/hghooks/mozhghooks',
      require => Vcsrepo['version-control-tools'],
    }
}
