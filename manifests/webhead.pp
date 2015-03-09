# == Class: hg::webhead
#
# === Parameters
#
# hg_user_uid: UID of the managed hg user (default: 500)
# hg_user_gid: GID of the managed hg user (default: $hg_user_uid)
# vhost: default vhost hostname to use (default: hg.mozilla.org)
# logrotate: Tell logrotate to rotate httpd logs? (default: true)
# mirror_priv_key_path: path to private mirror key (default: see below)
# mirror_pub_key_path: path to public mirror key (default: see below)
# mirror_user_name: user name to use for mirrors (default: vcs-sync@mozilla.com)
# mirror_source: hostname of master server (default: hg.mozilla.org)
# repo_root_path: root path of repositories (default: /repo_local/mozilla)
# repo_serve_path: path of serving dir (default: /repo_local/mozilla/mozilla)
# wsgi_path: path to wsgi files (default: /repo_local/mozilla/webroot_wsgi)
# template_path: path to hgweb templates (default: /repo_local/mozilla/hg_templates)
# hgweb_style: which hgweb template to use (default: gitweb_mozilla)
# extension_path: path to hg extensions (default: /repo_local/mozilla/extensions)
# python_lib_path: path to python libraries (default: /repo_local/mozilla/libraries)
# python_lib_override_path: path to python lib overrides (default: /repo_local/mozilla/library_overrides)
# use_moz_data: Prepopulate with mozilla data (default: true)

class hg::webhead($hg_user_uid='500',
                        $hg_user_gid=$hg_user_uid,
                        $vhost='hg.mozilla.org',
                        $logrotate=true,
                        $mirror_priv_key_path='/etc/mercurial/mirror',
                        $mirror_pub_key_path='/etc/mercurial/mirror.pub',
                        $mirror_user_name='vcs-sync@mozilla.com',
                        $mirror_source='hg.mozilla.org',
                        $repo_root_path='/repo_local/mozilla',
                        $repo_serve_path='/repo_local/mozilla/mozilla',
                        $wsgi_path='/repo_local/mozilla/webroot_wsgi',
                        $template_path='/repo_local/mozilla/hg_templates',
                        $hgweb_style='gitweb_mozilla',
                        $extension_path='/repo_local/mozilla/extensions',
                        $python_lib_path='/repo_local/mozilla/libraries',
                        $python_lib_override_path='/repo_local/mozilla/library_overrides',
                        $use_moz_data=true) {

        # START of Mozilla-specific definitions. You can safely ignore these
    if defined(Yumrepo['epel']) { realize(Yumrepo['epel']) }
    if defined(Yumrepo['mozilla']) { realize(Yumrepo['mozilla']) }
    if defined(Package['subversion']) { realize(Package['subversion']) }
      else { package { 'subversion': ensure => installed } }

        # Mozilla's apache module
    if defined(Class['apache']) { include apache }
        else {
            package { 'httpd': ensure   => installed; }
            service { 'httpd': ensure   => running,
                               enabled  => true,
                                require => Package['httpd'] }
        }
    if defined(Package['mod_wsgi']) { realize(Package['mod_wsgi']) }
      else { package { 'mod_wsgi': ensure => installed } }

    if defined(Yumrepo['mozilla']) {
        package { 'mercurial':
            ensure  => present,
            require => Yumrepo['mozilla'];
        }
    }
    else {
        package { 'mercurial':
            ensure   => present,
            source   =>
            'http://people.mozilla.org/~bkero/mercurial-3.3.2-0.x86_64.rpm',
            provider => 'rpm';
        }
    }
    if defined(Collectd::Plugin['apache']) {
        realize Collectd::Plugin['apache']
    }
    if defined(Collectd::Plugin['hg']) {
        realize Collectd::Plugin['hg']
    }

        #### END of Mozilla-specific definitions

    package { [ 'lockfile-progs',
                'python-pygments',
                'python-simplejson',
                'python-argparse']:
        ensure => present;
        }

    user { 'hg':
        ensure     => present,
        name       => 'hg',
        uid        => $hg::webhead::hg_user_id,
        shell      => '/bin/bash',
        managehome => true,
        comment    => 'Hg user';
    }

    file {

        # Apache
        '/etc/httpd/conf/httpd.conf':
            ensure  => present,
            source  => 'puppet:///modules/hg/webhead/httpd.conf',
            require => Package['httpd'];

        '/etc/httpd/conf.d/hg-vhost.conf':
            ensure  => present,
            path    => '/etc/httpd/conf.d/hg-vhost.conf',
            content => template('hg/httpd-hg-vhost.conf.erb'),
            notify  => Service['httpd'];
        'mod_wsgi.conf':
            ensure  => present,
            path    => '/etc/httpd/conf.d/wsgi.conf',
            content => 'LoadModule wsgi_module modules/mod_wsgi.so',
            require => Package['mod_wsgi'],
            notify  => Service['httpd'];


        # Apache logging

        "/var/log/httpd/$vhost":
            ensure  => directory,
            require => Package['httpd'],
            notify  => Service['httpd'];

        # Source directories

        $hg::webhead::repo_root_path:
            ensure => directory,
            owner  => 'hg',
            group  => 'hg',
            mode   => '0755';
        [ $hg::webhead::repo_serve_path,
          $hg::webhead::wsgi_path,
          $hg::webhead::template_path,
          $hg::webhead::extension_path,
          $hg::webhead::python_lib_path,
          $hg::webhead::python_lib_override_path]:
            ensure  => directory,
            owner   => 'hg',
            group   => 'hg',
            mode    => '0755',
            require => File[$hg::webhead::repo_root_path];

        # Configuration files and scripts

        '/etc/mercurial/hgrc':
            ensure  => present,
            content => template('hg/hgrc-webhead.erb'),
            require => Package['mercurial'];
        '/usr/local/bin/mirror-pull':
            ensure  => present,
            mode    => '0755',
            content => template('hg/mirror-pull.erb');

        '/usr/local/bin/repo-group':
            ensure => present,
            mode   => '0755',
            source => 'puppet:///modules/hg/webhead/repo-group';
        '/usr/local/bin/lockfile':
            ensure => present,
            mode   => '0755',
            source => 'puppet:///modules/hg/webhead/lockfile';

        '/home/hg/.ssh':
            ensure  => directory,
            mode    => '0700',
            owner   => 'hg',
            group   => 'hg',
            require => User['hg'];
        '/home/hg/.ssh/config':
            ensure  => present,
            source  => 'puppet:///modules/hg/webhead/ssh-config',
            owner   => 'hg',
            group   => 'hg',
            mode    => '0600',
            require => File['/home/hg/.ssh'];

    }

    if ($logrotate == true) {
        file { '/etc/logrotate.d/hg-httpd-logrotate':
            ensure  => present,
            source  => 'puppet:///modules/hg/webhead/hg-httpd-logrotate',
            notify  => Service['httpd'];
        }
    }
}
