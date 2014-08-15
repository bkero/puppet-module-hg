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
            source   => 'http://people.mozilla.org/~bkero/mercurial-2.8+122-1df77035c814.x86_64.rpm',
            provider => 'rpm';
        }
    }
}
