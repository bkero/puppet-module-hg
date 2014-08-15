# == Class: hg:ssh
#
# Hg subclass for SSH properties
#
# === Parameters
#
# $ldap_binddn: binddn to use for OpenSSH LDAP auth (default to heira lookup)
# $ldap_bindpw: bindpw to use for OpenSSH LDAP auth (default to hiera lookup)

class hg::ssh($ldap_binddn=hiera('secrets_openldap_moco_bindhg_username'),
              $ldap_bindpw=hiera('secrets_openldap_moco_bindhg_password')){
    include openldap::client
    realize(Package['python-ldap'])

    cron { 'make_user_wsgi_dirs':
        require => File['make_user_wsgi_dirs'],
        command => '/usr/local/bin/make_user_wsgi_dirs.sh',
        user    => 'root',
        minute  => '*/2';
    }

    User['hg'] {
        groups => undef,
    }

    class {
        'openssh_lpk':
            ldap_server   => $::ldapvip,
            uid           => 'mail',
            userdn        => 'dc=mozilla',
            binddn        => $hg::ssh::ldap_binddn,
            bindpw        => $hg::ssh::ldap_bindpw,
            homeDirectory => 'fakeHome',
    }

    sshd_config {
        ForceCommand: value => '/usr/local/bin/pash.py';
        Port: value         => "22\nPort 222";
    }

    file {

        # Scripts and configuration files

        'hgrc':
            ensure => present,
            path   => '/etc/mercurial/hgrc',
            source => 'puppet:///modules/hg/ssh/hgrc';
        'pash':
            ensure  => present,
            path    => '/usr/local/bin/',
            purge   => false,
            recurse => true,
            source  => 'puppet:///modules/hg/ssh/pash';
        'ldap_helper.py':
            ensure  => present,
            path    => '/usr/local/bin/ldap_helper.py',
            owner   => 'root',
            group   => 'root',
            mode    => '0755',
            content => template('hg/ldap_helper.py.erb');
        'make_user_wsgi_dirs':
            ensure => present,
            path   => '/usr/local/bin/make_user_wsgi_dirs.sh',
            mode   => '0755',
            source => 'puppet:///modules/hg/ssh/make_user_wsgi_dirs.sh';

        # SSH Host Keys

        '/etc/ssh/ssh_host_dsa_key':
            notify => Service['sshd'],
            mode   => '0600',
            source => 'puppet:///modules/secrets/hg_new/ssh/ssh_host_dsa_key';

        '/etc/ssh/ssh_host_dsa_key.pub':
            notify => Service['sshd'],
            mode   => '0600',
            source => 'puppet:///modules/secrets/hg_new/ssh/ssh_host_dsa_key.pub';

        '/etc/ssh/ssh_host_key':
            notify => Service['sshd'],
            mode   => '0600',
            source => 'puppet:///modules/secrets/hg_new/ssh/ssh_host_key';

        '/etc/ssh/ssh_host_key.pub':
            notify => Service['sshd'],
            mode   => '0600',
            source => 'puppet:///modules/secrets/hg_new/ssh/ssh_host_key.pub';

        '/etc/ssh/ssh_host_rsa_key':
            notify => Service['sshd'],
            mode   => '0600',
            source => 'puppet:///modules/secrets/hg_new/ssh/ssh_host_rsa_key';

        '/etc/ssh/ssh_host_rsa_key.pub':
            notify => Service['sshd'],
            mode   => '0600',
            source => 'puppet:///modules/secrets/hg_new/ssh/ssh_host_rsa_key.pub';

        # SSH Mirror key (used to mirror to webheads)

        '/etc/mercurial/mirror':
            ensure => present,
            mode   => '0600',
            source => 'puppet:///modules/secrets/hg_new/ssh/mirror';

        '/etc/mercurial/mirror.pub':
            ensure => present,
            mode   => '0600',
            source => 'puppet:///modules/secrets/hg_new/ssh/mirror.pub';

        # List of webhead mirrors

        '/etc/mercurial/mirrors':
            ensure => present,
            mode   => '0600',
            source => 'puppet:///modules/hg/ssh/mirrors';
    }
}
