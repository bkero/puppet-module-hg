#! /usr/bin/python

import sys, subprocess, shlex

def QuoteForPOSIX(string):
    '''quote a string so it can be used as an argument in a  posix shell

    According to: http://www.unix.org/single_unix_specification/
    2.2.1 Escape Character(Backslash)

    A backslash that is not quoted shall preserve the literal value
    of the following character, with the exception of a <newline>.

    2.2.2 Single-Quotes

    Enclosing characters in single-quotes( '' ) shall preserve
    the literal value of each character within the single-quotes.
    A single-quote cannot occur within single-quotes.

    from: http://aspn.activestate.com/ASPN/Cookbook/Python/Recipe/498202
    thank you google!
    '''
    return "\\'".join("'" + p + "'" for p in string.split("'"))

def run_command(command_string, input=None, verbose=False):
    subcommand = None
    output_lines = []
    fixed_command_string = command_string.lstrip().rstrip()
    line_cnt = 0
    if(verbose):
        # Don't do any redirection of stdout/stderr
        out_fd=None
        print "EXEC [%s]" % fixed_command_string
    else:
        # all output goes to /dev/null
        out_fd = open('/dev/null', 'w')
    command_end = fixed_command_string.find("|")
    if command_end > 0:
        subcommand = subprocess.Popen(
            shlex.split(fixed_command_string[:command_end]), 
            stdin=input, stderr=out_fd, stdout=subprocess.PIPE)
        return(run_command(fixed_command_string[command_end + 1:], input = subcommand.stdout))
    else:
        subcommand = subprocess.Popen(shlex.split(fixed_command_string), 
                                      stdin=input, stderr=out_fd, stdout=subprocess.PIPE)
    while True:
        l = subcommand.stdout.readline()
        if not l:
            if verbose:
                print "Breaking after reading %i lines from subprocess" % line_cnt
            break
        if verbose:
            print l,
            output_lines.append(l.rstrip())
    if(not verbose):
        out_fd.close()
    return output_lines

def prompt_user(prompt_string, options):
    index = 0
    print
    print '0) Exit.'
    for option in options:
        index += 1
        print '%s) %s.' %(index, option)
    print
    selection = raw_input(prompt_string + ' ')
    if selection.isdigit():
        selection = int(selection)
        if(selection == 0):
            sys.exit(0)
        if(selection > 0 and selection <= index):
            return options [selection - 1]
        else:
            sys.stderr.write('Please select one of the presented options\n')
    else:
        sys.stderr.write('Please select the number corresponding to the option\n')
    return prompt_user(prompt_string, options)

