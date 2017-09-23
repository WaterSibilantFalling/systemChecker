# systemChecker

systemChecker is a perl program that checks a collection of file system danger points to ensure that everyting is all OK. If any error is found, a dialog is raised and a log message written.

systemChecker is intended to be run every minute or every 5 minutes, probably from cron or anacron. The errors it looks for should be dealt with instantly as they each represent a system corruption of one type or another.

The writing of this program was driven by the harm caused from continuing to operate on a system that had undergone one of many invisible corruptions. 

systemChecker is written in Perl5 using only standard libraries. 


# Configuration

Basic configuration is done on the commandline. Whether or not each test is actually done is controlled by the presence, or absence, of a \_\_do\_some\_task\_ file in /etc/systemChecker 

```
prompt > ./checker_everyMinute.pl -h

Usage:

checker_everyMinute.pl
        [--linksFile ]             # a file 'mount points'\t'link to mount point'
        [--specificMountpoint      = /some/dir [ --specificMountpoint ...]]
        [--dirContainingMountpoint = /some/dir [ --dirContainingMountpoint ...]]
        [ -h                       # show this message ]

This program runs a series of checks on the local system to ensure that
everything is OK. Ideally it will be run every minute, or every 5 minutes, by
cron or anacron.

```

**--linksFile /media/someListOfLinks.txt**

A link to file listing 
```
	/a_dir/on/remvable/media		\t		/link/to/a_dir
	/c_dir/on/remvable/media		\t		/link/to/c_dir
	/c_dir/on/remvable/media		\t		/another/link/to/c_dir
	/d_dir/on/remvable/media		\t		/link/to/dir_d
		:										:

```
Each of these will be checked. 

**--specificMountpoint /media/mountPoint/**

Each mount point - that should have some device mounted on it - is checked.

**--dirContainingMountpoint	/media**

One or more directories that have mountpoints in them. 


# Checks

Currently eight checks are undertaken.

1.	Does each mounted file system have all of the appropriate symbolic links to it

2.	Check that no file systems are mounted twice, either separately, or over the top of themselves.

3.	Disk Full Monitor. Report if any partition is over 95% full. 

4.	Check that removeable drives' check files can be accessed, i.e these drives are mounted properly

5.	Check that all mounted devices are listed in the list of specificMountPoints, AND visa versa: the specificMountPoints are actually mounted

6.	Only those devices appearing in /proc/partions are actually mounted, i.e. there are no "mounted" devices that do not actually exist on the system. 

7.	Check kern.log and syslog for any errors matching /error/i

8.	If the network has been raised, that connections can be made to remote devices. If the problem is local, automatically fix it. If remote, raise a dialog. 

