#! /usr/bin/python

import os, sys, re, ConfigParser
from ldap_helper import ldap_connect, get_ldap_attribute
from sh_helper import run_command, prompt_user
from cgi import escape
from subprocess import Popen, PIPE, STDOUT
import shlex

doc_root = {'hg.mozilla.org': '/repo_local/mozilla',
            'hg.ecmascript.org': '/repo_local/ecma/mozilla'}

verbose_users = [ 'bkero@mozilla.com2', ]

def is_valid_user (mail):
    mail = mail.strip()
    ## If the regex search below fails, comment out the conditional and the return. Then Uncomment the following line to atleat sanitize the input
    mail = mail.replace("(",'').replace(")",'').replace("'",'').replace('"','').replace(';','').replace("\"",'')
    #if not re.search("^[_a-z0-9-]+(\.[_a-z0-9-]+)*@[a-z0-9-]+(\.[a-z0-9-]+)*(\.[a-z]{2,4})$", mail):
    #     return 'Invalid Email Address'
    account_status = get_ldap_attribute (mail, 'hgAccountEnabled', 'ldap://ldap.db.scl3.mozilla.com')
    if account_status == 'TRUE':
	return 1
    elif account_status == 'FALSE':
	return 2
    else:
	return 0

#
# Please be very careful when you relax/change the good_chars regular expression.
# Being lax with it can open us up to all kind of security problems.
#
def check_repo_name (repo_name):
    good_chars = re.compile ('^(\w|-|/|\.\w)+\s*$')
    if not good_chars.search (repo_name):
        sys.stderr.write ('Only alpha-numeric characters, ".", and "-" are allowed in the repository names.\n')
        sys.stderr.write ('Please try again with only those characters.\n')
        sys.exit (1)
    return True

def run_hg_clone (cname, user_repo_dir, repo_name, source_repo_path, verbose=False):
  global doc_root
  userdir = "%s/users/%s" % (doc_root[cname], user_repo_dir)
  dest_dir = "%s/%s" % (userdir, repo_name)
  dest_url = "/users/%s/%s" % (user_repo_dir, repo_name)

  if os.path.exists (dest_dir):
    print 'Sorry, you already have a repo called %s' % repo_name
    print 'If you think this is wrong, please file an IT bug'
    sys.exit (1)
  else:
    if (os.path.exists ('%s/%s' % (doc_root[cname], source_repo_path))) and (check_repo_name (source_repo_path)):
      if not os.path.exists (userdir):
        run_command ('mkdir %s' % userdir)
      print 'Please wait.  Cloning /%s to %s' % (source_repo_path, dest_url)
      if(verbose):
        run_command ('nohup /usr/bin/hg clone --debug --verbose --time --pull -U %s/%s %s' % 
                     (doc_root[cname], source_repo_path, dest_dir),
                     verbose=True)
      else:
        run_command ('nohup /usr/bin/hg clone --pull -U %s/%s %s' % 
                     (doc_root[cname], source_repo_path, dest_dir))
         
      print "Clone complete."
    else:
      print 'Sorry, there is no source repo called %s.' % source_repo_path
      print 'If you think this is wrong, please file an IT bug'
      sys.exit (1)

def make_wsgi_dir (cname, user_repo_dir):
  global doc_root
  wsgi_dir = "/repo_local/mozilla/webroot_wsgi/users/%s" % user_repo_dir
      # Create user's webroot_wsgi folder if it doesn't already exist
  if not os.path.isdir(wsgi_dir):
    os.mkdir(wsgi_dir)

  print "Creating hgweb.config file"
      # Create hgweb.config file if it doesn't already exist
  if not os.path.isfile("%s/hgweb.config" % wsgi_dir):
    #try:
    hgconfig = open("%s/hgweb.config" % wsgi_dir, "w")
    #except:
    #  print("Problem opening hgweb.config file, please file a bug against IT and pastebin this error.")
    hgconfig.write("[web]\n")
    hgconfig.write("baseurl = http://%s/users/%s\n" % (cname, user_repo_dir))
    hgconfig.write("[paths]\n")
    hgconfig.write("/ = %s/users/%s/*\n" % (doc_root[cname], user_repo_dir))
    hgconfig.close()

      # Create hgweb.wsgi file if it doesn't already exist
  if not os.path.isfile("%s/hgweb.wsgi" % wsgi_dir):
    try:
      hgwsgi = open("%s/hgweb.wsgi" % wsgi_dir, "w")
    except:
      print("Problem opening hweb.wsgi file, please file an IT bug with this error.")
    hgwsgi.write("#!/usr/bin/env python\n")
    hgwsgi.write("config = '%s/hgweb.config'\n" % wsgi_dir)
    hgwsgi.write("from mercurial import demandimport; demandimport.enable()\n")
    hgwsgi.write("from mercurial.hgweb import hgweb\n")
    hgwsgi.write("import os\n")
    hgwsgi.write("os.environ['HGENCODING'] = 'UTF-8'\n")
    hgwsgi.write("application = hgweb(config)\n")
    hgwsgi.close()

def fix_user_repo_perms (cname, repo_name):
    global doc_root
    user = os.getenv ('USER')
    user_repo_dir = user.replace ('@', '_')
    print "Fixing permissions, don't interrupt."
    try:
        run_command ('chown %s:scm_level_1 %s/users/%s' % (user, doc_root[cname], user_repo_dir))
        run_command ('chmod g+w %s/users/%s' % (doc_root[cname], user_repo_dir))
        run_command ('chmod g+s %s/users/%s' % (doc_root[cname], user_repo_dir))
        run_command ('chown -R %s:scm_level_1 %s/users/%s/%s' % (user, doc_root[cname], user_repo_dir, repo_name))
        run_command ('chmod -R g+w %s/users/%s/%s' % (doc_root[cname], user_repo_dir, repo_name))
        run_command ('find %s/users/%s/%s -depth -type d | xargs chmod g+s' % (doc_root[cname], user_repo_dir, repo_name))
    except Exception, e:
        print "Exception %s" % (e)
    
def make_repo_clone (cname, repo_name, quick_src, verbose=False, source_repo=''):
  global doc_root
  user = os.getenv ('USER')
  user_repo_dir = user.replace ('@', '_')
  dest_url = "/users/%s" % user_repo_dir
  source_repo = ''
  if quick_src:
    if(user in verbose_users):
        verbose=True
        run_hg_clone (cname, user_repo_dir, repo_name, quick_src, True)
    else:
      run_hg_clone (cname, user_repo_dir, repo_name, quick_src)
    fix_user_repo_perms (cname, repo_name)
    sys.exit(0)
  else:
    #make_wsgi_dir(cname, user_repo_dir)
    print "Making repo %s for %s." % (repo_name, user)
    print "This repo will appear as %s/users/%s/%s." % (cname, user_repo_dir, repo_name)
    print 'If you need a top level repo, please quit now and file a bug for IT to create one for you.'
    selection = prompt_user ('Proceed?', ['yes', 'no'])
    if (selection == 'yes'):
      print 'You can clone an existing public repo or a users private repo.'
      print 'You can also create an empty repository.'
      selection = prompt_user ('Source repository:', ['Clone a public repository', 'Clone a private repository', 'Create an empty repository'])
      if (selection == 'Clone a public repository'):
        exec_command = "/usr/bin/find " + doc_root[cname] + " -maxdepth 3 -mindepth 2 -type d -name .hg"
        args = shlex.split(exec_command)
        #repo_list = run_command (exec_command)
        p = Popen(args, stdout=PIPE, stdin=PIPE, stderr=STDOUT)
        repo_list = p.communicate()[0].split("\n")
        if repo_list:
          print "We have the repo_list"
          repo_list = map (lambda x: x.replace (doc_root[cname] + '/', ''), repo_list)
          repo_list = map (lambda x: x.replace ('/.hg', ''), repo_list)
          print 'List of available public repos'
          source_repo = prompt_user ('Pick a source repo:', repo_list)
      elif (selection == 'Clone a private repository'):
        source_user = raw_input ('Please enter the e-mail address of the user owning the repo: ')
	valid_user = is_valid_user(source_user)
        if valid_user == True:
          source_user = source_user.replace ('@', '_')
        elif valid_user == False:
          sys.stderr.write ('Unknown user.\n')
          sys.exit (1)
        elif valid_user == 'Invalid Email Address':
          sys.stderr.write ('Invalid Email Address.\n')
          sys.exit (1)
        source_user_path = run_command ('find ' + doc_root[cname] + '/users/' + source_user + ' -maxdepth 1 -mindepth 1 -type d')
        if not source_user_path:
          print 'That user does not have any private repositories.'
          print 'Check https://' + cname + '/users for a list of valid users.'
          sys.exit (1)
        else:
          user_repo_list = run_command ('find ' + doc_root[cname] + '/users/' + source_user + ' -maxdepth 3 -mindepth 2 -type d -name .hg')
          user_repo_list = map (lambda x: x.replace (doc_root[cname] + '/users/' + source_user, ''), user_repo_list)
          user_repo_list = map (lambda x: x.replace ('/.hg', ''), user_repo_list)
          user_repo_list = map (lambda x: x.strip ('/'), user_repo_list)
          print 'Select the users repo you wish to clone.'
          source_repo = prompt_user ('Pick a source repo:', user_repo_list)
          source_repo = 'users/' + source_user + '/' + source_repo
      elif (selection == 'Create an empty repository'):
        source_repo=''
      else:
          # We should not get here
          source_repo=''
      if source_repo != '':
        print 'About to clone /%s to /users/%s/%s' % (source_repo, user_repo_dir, repo_name)
        response = prompt_user ('Proceed?', ['yes', 'no'])
        if (response == 'yes'):
          print 'Please do not interrupt this operation.'
          run_hg_clone (cname, user_repo_dir, repo_name, source_repo)
      else:
        print "About to create an empty repository at /users/%s/%s" % (user_repo_dir, repo_name)
        response = prompt_user ('Proceed?', ['yes', 'no'])
        if (response == 'yes'):
          if not os.path.exists ('%s/users/%s' % (doc_root[cname], user_repo_dir)):
            try:
              exec_command = '/bin/mkdir %s/users/%s' % (doc_root[cname], user_repo_dir)
              run_command (exec_command)
            except Exception, e:
              print "Exception %s" % (e)

          run_command ('/usr/bin/nohup /usr/bin/hg init %s/users/%s/%s' % (doc_root[cname], user_repo_dir, repo_name))
      fix_user_repo_perms (cname, repo_name)
      sys.exit (0)

def edit_repo_description (cname, repo_name):
    global doc_root
    user = os.getenv ('USER')
    user_repo_dir = user.replace ('@', '_')
    print 'You are about to edit the description for hg.mozilla.org/users/%s/%s.' % (user_repo_dir, repo_name)
    print 'If you need to edit the description for a top level repo, please quit now and file an IT bug for it.'
    selection = prompt_user ('Proceed?', ['yes', 'no'])
    if (selection == 'yes'):
	if os.path.exists ('%s/users/%s/%s' % (doc_root[cname], user_repo_dir, repo_name)):
            repo_description =  raw_input ('Enter a one line descripton for the repository: ')
            if (repo_description != ''):
		repo_description = escape (repo_description)
                repo_config = ConfigParser.RawConfigParser ()
                repo_config_file = '%s/users/%s/%s' % (doc_root[cname], user_repo_dir, repo_name) + '/.hg/hgrc'
                if not os.path.isfile (repo_config_file):
                    run_command ('touch ' + repo_config_file)
                    run_command ('chown ' + user + ':scm_level_1 ' + repo_config_file)
                if repo_config.read (repo_config_file):
                    repo_config_file = open (repo_config_file, 'w+')
                else:
                    sys.stderr.write ('Could not read the hgrc file for /users/%s/%s.\n' % (user_repo_dir, repo_name))
                    sys.stderr.write ('Please file an IT bug to troubleshoot this.')
                    sys.exit (1)
                if not repo_config.has_section ('web'):
                    repo_config.add_section ('web')
                repo_config.set ('web', 'description', repo_description)
                repo_config.write (repo_config_file)
                repo_config_file.close ()
        else:
            sys.stderr.write ('Could not find the repository at /users/%s/%s.\n' % (user_repo_dir, repo_name))
            sys.exit (1)

def do_delete(cname, repo_dir, repo_name, verbose=False):
    global doc_root
    if verbose:
        print "Deleting..."
    run_command ('rm -rf %s/users/%s/%s' % (doc_root[cname], repo_dir, repo_name))
    if verbose:
        print "Finished deleting"
    purge_log = open ('/tmp/pushlog_purge.%s' % os.getpid(), "a")
    purge_log.write ('echo users/%s/%s\n' % (repo_dir, repo_name))
    purge_log.close()

def delete_repo (cname, repo_name, do_quick_delete, verbose=False):
  global doc_root
  user = os.getenv ('USER')
  if(user in verbose_users):
      verbose = True
  user_repo_dir = user.replace ('@', '_')
  url_path = "/users/%s" % user_repo_dir
  if os.path.exists ('%s/users/%s/%s' % (doc_root[cname], user_repo_dir, repo_name)):
    if do_quick_delete:
      do_delete (cname, user_repo_dir, repo_name, verbose)
    else:
      print '\nAre you sure you want to delete /users/%s/%s?' % (user_repo_dir, repo_name)
      print '\nThis action is IRREVERSIBLE.'
      selection = prompt_user ('Proceed?', ['yes', 'no'])
      if (selection == 'yes'):
        do_delete (cname, user_repo_dir, repo_name, verbose)
  else:
    sys.stderr.write ('Could not find the repository at /users/%s/%s.\n' % (user_repo_dir, repo_name))
    sys.stderr.write ('Please check the list at https://%s/users/%s\n' % (cname, user_repo_dir))
    sys.exit (1)
  sys.exit(0)

def edit_repo (cname, repo_name, do_quick_delete):
    if do_quick_delete:
        delete_repo (cname, repo_name, do_quick_delete)
    else:
      action = prompt_user ('What would you like to do?', ['Delete the repository', 'Edit the description'])
      if action == 'Edit the description':
        edit_repo_description (cname, repo_name)
      elif action == 'Delete the repository':
        delete_repo (cname, repo_name, False) 
    return

def serve (cname):
    global doc_root
    ssh_command = os.getenv ('SSH_ORIGINAL_COMMAND')
    if not ssh_command:
        sys.stderr.write ('No interactive shells allowed here!\n') 
        sys.exit (1)
    elif ssh_command.startswith ('hg'):
        repo_expr = re.compile ('(.*)\s+-R\s+([^\s]+\s+)(.*)')
        if (repo_expr.search (ssh_command)):
            [(hg_path, repo_path, hg_command)] = repo_expr.findall (ssh_command)
            if (hg_command == 'serve --stdio') and (check_repo_name (repo_path)):
                hg_arg_string = '/usr/bin/hg -R ' + doc_root[cname] + '/' + repo_path + hg_command
                hg_args = hg_arg_string.split ()
                os.execv ('/usr/bin/hg', hg_args)
            else:
                sys.stderr.write ("Thank you dchen! but.. I don't think so!\n")
                sys.exit (1)
    elif ssh_command.startswith ('clone ') and (cname != 'hg.ecmascript.org'):
        args = ssh_command.replace ('clone', '').split()
        if check_repo_name (args[0]):
            if len(args) == 1:
                make_repo_clone (cname, args[0], None)
            elif len(args) == 2:
                if os.path.isdir ('%s/%s/.hg' % (doc_root[cname], args[1])):
                    make_repo_clone (cname, args[0], args[1])
            sys.exit (0)
        sys.stderr.write ('clone usage: ssh hg.mozilla.org clone newrepo [srcrepo]\n')
        sys.exit (1)
    elif ssh_command.startswith ('edit ') and (cname != 'hg.ecmascript.org'):
        args = ssh_command.replace ('edit', '',  1).split()
        if check_repo_name (args[0]):
            if len(args) == 1:
                edit_repo (cname, args[0], False)
            elif len(args) == 3 and args[1] == 'delete' and args[2] == 'YES':
                edit_repo (cname, args[0], True)
            else:
                sys.stderr.write ('edit usage: ssh hg.mozilla.org edit [userrepo delete] - WARNING: will not prompt!\n')
                sys.exit (1)
    elif ssh_command.startswith ('pushlog ') and (cname != 'hg.ecmascript.org'):
        args = ssh_command.replace ('pushlog', '').split()
        if check_repo_name (args[0]):
            fh = open("/repo_local/mozilla/%s/.hg/pushlog2.db" % (args[0]))
            print(fh.read())
            fh.close()
    else:
        sys.stderr.write ('No interactive commands allowed here!\n') 
        sys.exit (1)

if __name__ == '__main__':
#    if is_valid_user (os.getenv ('USER')):
    if is_valid_user ('bkero@mozilla.com'):
        serve ("hg.mozilla.org")
    else:
        sys.stderr.write ('You are not welcome here, go away!\n') 
        sys.exit (1)
