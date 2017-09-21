#!/usr/bin/perl

# all the checks I can think of to quickly detect every problem I can think of
#
#
# TO DO:	track, report on changed IP addresses (mine)
#			600 log messages (say) per minute, poss 200/min over 5 minutes
#			all sudo apps have not changed in size or date 
#			specific messages in syslog and the like
#	
use common::sense;

use autodie;
use charnames   		qw< :full >;
use File::Basename      qw< basename >;
use Carp                qw< carp croak confess cluck >;
use POSIX;
use English 			qw( -no_match_vars ) ;

END { close STDOUT }
$0 = basename($0);  	# shorter messages
$| = 1;					# autoflush: solving perl's stupidities 1 by 1

# --- unicode ---
binmode STDOUT, ":encoding(UTF-8)";
binmode STDERR, ":encoding(UTF-8)";
use Unicode::Normalize  qw< NFD NFC >;
use Encode              qw< encode decode >;
use open        		qw< :std  :utf8     >;


# --- debugging support
# use Data::Dumper;		# for debugging, you never know ...
# use Data::TreeDumper;	# use PrintTree($ref, $var); DumpTree($ref, $var);
# my $sub = sub {} ;		# seems necessary, but why?
# $Data::TreeDumper::Useascii = 1 ;		# uglier, but debugger can handle
# $Data::TreeDumper::Maxdepth = 8 ;
# use Data::TreeDumper::Renderer::GTK;
# my  $Dumper = Data::TreeDumper::Renderer::GTK->new( );

# --- Program constants, globals, settings


# turns on (yes_*) and off (no_*) the tests in this program
my $controlFlagsDir = "/etc/controlFlags" ; 



# --- commandline parametes ---

use Getopt::Long qw(:config no_ignore_case bundling);

#matches removable dirs to their links in the filesystem
my $mountPoint2LinkFile = "/media/linksToMountpoints.lst";
# dirs under wich removeable medis devices are mounted
my @dirsContainingRemovableMountpoints = ['/media']; 
# individual mount points of removable media
my @individualRemovableMountPoints = ['/usbhd']; 

my $showHelp = 0; 
my $okOptions = GetOptions(	
 			"linksFile:s"	            => \$mountPoint2LinkFile, 
			"dirContaingMountpoint:s" => \@dirsContainingRemovableMountpoints,
			"specific_mountpoints:s"	=> \@individualRemovableMountPoints,
            "h"                         => \$showHelp,  
			);

# --- Useage message

my $shortProgName = `basename $PROGRAM_NAME`;  
chomp $shortProgName; 
my $usageMsg = <<USAGE;

Usage:

$shortProgName
	[--linksFile ]             # a file 'mount points' \t 'link to mount point'
	[--specificMountpoint      = /some/dir [ --specificMountpoint ...]]
	[--dirContainingMountpoint = /some/dir [ --dirContainingMountpoint ...]]
    [ -h                       # show this message ]


This program runs a series of checks on the local system to ensure that 
everything is OK. Ideally it will be run every minute, or every 5 minutes, by
cron or anacron. 

USAGE

# --- test the commandline input

if ($showHelp) {
    print $usageMsg;
    exit(0);
}
if (! $okOptions) {
    print $usageMsg;
    exit(0);
}



# ============= utilisty functions =============================

sub get_mountPoint_ln_array {

	my @ln_FromTo = `/bin/egrep -v "^\s*\$\|^#" $mountPoint2LinkFile | /usr/bin/awk \'BEGIN{OFS="\t"}{print \$2OFS\$1}\'    `; 
	chomp (@ln_FromTo); 

	return \@ln_FromTo; 
}


sub get_mounted_devices {
#	/dev/sdc3 on /media/200GB_downloadTorrent type fuseblk (rw,relatime,user_id=0,group_id=0,default_permissions,allow_other,blksize=4096)
# 
	my @mountLines = `/bin/mount`; 
	chomp @mountLines;
	local $" = "\n"; 
	print "\@mountLines:\t@mountLines\n"; 
	my @mountedDevices; 
	foreach (@mountLines) {
		my @parts = split /\s+/, $_ ; 
		next if (@parts[2] !~ /^\/.*/); 			# mount point = dir --> must start with '/' 
		push @mountedDevices, @parts[2]; 
	}
	#my @mountedDevices = splice @mountLines, 2, 1; 
	# my @mountedDevices = @mountLines[2 .. 2];#  
	chomp @mountedDevices; 
	print "\@mountedDevices:\t@mountedDevices\n"; 
	my @sorted = sort  @mountedDevices;
	print "\@sorted:\t@sorted\n"; 
	return \@sorted; 
}


# ======== check functions =================================



# 1. --- checking /media dirs and matching /mnt links to them

checking_media_and_mnts() 
if (  -f "$controlFlagsDir/yes_checking_media_and_mnts" ); 

# this could or should be replaced by the link_.... program

sub checking_media_and_mnts {
# check that every device in the udev_links file, if mounted, has a link
# if not, tell to run 'link_mount_to_mnt_dir -i $that_mount_point`

	my @ln_FromTo = @{ get_mountPoint_ln_array() }; 

	foreach my $this_lnFromTo (@ln_FromTo) {                                                                                     
		$this_lnFromTo =~ /^(.*)\s+(.*)$/; 
		my $mountPoint 	= $1;
		my $lnDir		= $2; 
		# my @fromAndToDirs =~ split /\s+/,$this_lnFromTo;
		# my $mountPoint 	= $fromAndToDirs[0]; 
		# my $lnDir		= $fromAndToDirs[1];

		# mounted dirs (in /media) without links in /mnt
		if (( -x $mountPoint ) and ( ! -x $lnDir )){
			` xmessage \"ERROR: $mountPoint exitst, but $lnDir doesn't link to it\" & `; 
		}

		# dirs in /mnt without a mounted entitiy in /media
		if (( -x $lnDir ) and ( ! -x $mountPoint)) {  
			`xmessage \"ERROR: $lnDir exists, but $mountPoint does not \" &  `; 
		}
	}
}



# 2. --- check that there are no /media/dirA/dirA  linkings (same dir linked inside itself)

# my @checkForRecursiveMountsBaseDirs = ["/media", "/mnt"]; 
#
# use IO:All; 
#
# checking_tnt_tnt_recursively_linked_dirs() 
# 	if (  -f "$controlFlagsDir/yes_checking_tnt_tnt_recursively_linked_dirs " ); 
#
# sub checking_tnt_tnt_recursively_linked_dirs {
# 	foreach $mountDir (@checkForRecursiveMountsBaseDirs) {
# 		my @dirs = io->dir($mountDir)->all_dirs; 
# 		foreach my $subDir (@dirs) {
# 			if ( -x $mountDir/$subDir/$subDir ) {
# 				`unlink $mountDir/$subDir/$subDir `; 
# 			}
# 		}
# 	}
# } 



# 3. ---  check that no mounts are mounted twice: like 2 x /media/20g_20GB

# mount returns lines like this: 
# /dev/sdb1 on /usbhd type fuseblk (rw,relatime,user_id=0,group_id=0,default_permissions,allow_other,blksize=4096)
# /dev/sdb2 on /usbhd type fuseblk (rw,relatime,user_id=0,group_id=0,default_permissions,allow_other,blksize=4096)

# NOTE: one of these two is no longer in /proc/partitons, so it will be killed below
#
# NOTE: can use di or df for this, e.g grep /dev

check_multiple_mounted_devices()
if ( -f "$controlFlagsDir/yes_check_multiple_mounted_devices"); 

sub check_multiple_mounted_devices {

	my @sortedMountedDevices = @{ get_mounted_devices( ) }; 

	foreach my $i (0 .. ($#sortedMountedDevices-1)){
		if ($sortedMountedDevices[$i] eq $sortedMountedDevices[$i + 1]){
			`DISPLAY=:0 xmessage \"ERROR: $sortedMountedDevices[$i] is mounted twice\" & `; 
		}
	}
}




# 4. ---  call the diskfullmonitor

# /dev/sda5  /tmp                      0%      1.8G     1.8G
# /dev/sdb1  /usbhd                   90%     44.8G   465.8G
# /dev/sda2  /usr                     92%      0.4G     4.5G
# /dev/sda6  /var                     36%      2.9G     4.5G
# /dev/sda8  /work                    93%      0.6G     9.0G

check_disksfull()
if ( -f "$controlFlagsDir/yes_diskfullmonitor");  

sub check_disksfull {
	my @di_deviceFullness = `/usr/bin/di -s m -f SM1fb`; 
	chomp @di_deviceFullness;
	foreach my $line (@di_deviceFullness) {
		local $" = " --- "; 
		my @parts = split(/\s+/, $line); 
		sip print "$line\n"; 
		# print "@parts\n"; 
		# print "part\[2\]:\t$parts[2]\n"; 
		if (($parts[2] eq '98%') or ($parts[2] eq '99%') or ($parts[2] eq '100%')) {
			`DISPLAY=:0 xmessage \"ERROR: $parts[1] is full ($parts[2])\" & `; 
		}	
	}
}





# 5. --- check that removeable drives' check files can be accessed, i.e mounted properly 

my $checkDirPath = ".amMountedCheckDir_dontRemove/";
my $checkFile	= "_checkFile_dont_remove_";
my @dirsWithCheckFiles = ( "/mnt/t/", "/usbhd/");

check_removable_drives_checkFiles() 
if ( -f "$controlFlagsDir/yes_check_mounted_removable_devices");  

# IF a removeable filesystem is - or seems to be - mounted, 
# THEN check that the 'mount check file' (.amMountedCheckDir) is there
# 
# if the filesystem become detached, a process can continue to write, even though
# the device is not there
# 
# PROB: mount point dir is there but the underlying check dir is not
# 		(/mnt/tnt is there, but /mnt/tnt/.checkDir/.checkFile is not)
#
#		a device is mounted (re: /bin/mount) but either its /media dir is not there
#
#		there is a dir in /media, but there is nothing mounted (/bin/mount) 
#
#--- the /mnt/xxxx dir, and the /media dir can both be there, with the device
# --- gone

# NOTE: can use di or df for this, e.g grep /dev


# /mnt/20g/.amMountedCheckDir_dontRemove/_checkFile_dont_remove_

sub check_removable_drives_checkFiles {
	for my $checkfileRoot (@dirsWithCheckFiles) {
		my $lostMount =  
		(( -f "$checkfileRoot" ) 
			&& (not -f "$checkfileRoot/$checkDirPath"."$checkFile") );
		if ($lostMount) 
		{
			`DISPLAY=:0 xmessage \"The filesystem $checkfileRoot is not mounted properly.\" & ` ;
		}
	}
}


# NOTE: can use di or df for this, e.g grep /dev



# 6. --- check actually tunted devices c.f.  mount points in /media

check_mountedDevices_and_mountPoints( )
if  ( -f "$controlFlagsDir/yes_check_mountedDevices_and_mountPoints" ); 

sub check_mountedDevices_and_mountPoints {
	# 1. Check that all mounted dirs (re: /bin/mount) have mount points in /media
	# 		IGNORING those not in /media
	# 2. Check that all mountpoint dirs are listed as mounted (/bin/mount)

	my @allPossMountLinks    = @{ get_mountPoint_ln_array() };
	my @currMountedDevices = @{ get_mounted_devices() };

	# 1. Check that all mounted dirs (/bin/mount) have mount points in /media 
	# 	only interested in removeable devices (NOT all in /bin/mount)
	# 	so have to have a separate list of removeable devices to check against
	# 	the mount point dirs (say, /media) 

	# all currently-mounted removable mounted devices (only) 
	# in the mountedDevices list, these will have a 'removableMountPoint' substr
	my @currMountedRemoveableDevices; 
	foreach my $check (@dirsContainingRemovableMountpoints){
		push @currMountedRemoveableDevices, grep(/$check.*/, @currMountedDevices); 
	}

	# all current mountpoints. These change as are auto created & destroyed
	my @currMountpoints;
	foreach my $thisDir (@dirsContainingRemovableMountpoints) {
		# DEBUG: check that these dirs are not added with paths
		my @mountPoints =	io->dir($thisDir)->all_mountPointDirs; 
		foreach my $t (@mountPoints) {
			push @currMountpoints, $thisDir."/".$t; 
		}
	}

	# ERROR: a current mounted removeable device does not have an entry in /media
	foreach my $currMountedDevice (@currMountedRemoveableDevices) {
		if ( not grep (/$currMountedDevice/, @currMountpoints)) {
			`DISPLAY=:0 xmessage \"ERROR: The mounted device $currMountedDevice does not have an entry in @dirsContainingRemovableMountpoints\"	`; 
		}
	}

	# 2. Check that all mountpoint dirs are listed as mounted (/bin/mount) 
	foreach my $thisMountPointDir (@currMountpoints) {
		if ( not grep(/$thisMountPointDir/, @currMountedRemoveableDevices)) {
			`DISPLAY=:0 xmessage "ERROR: The mountpoint $thisMountPointDir does not represent any currently mounted device" `;  
		}
	}
}


# 7. --- only those in /proc/partions are mounted : else kill 
#
# ntfs-3g progs can remain running after a device is no longer 
# in /proc/partitions.  Kill these progs REGARDLESS. They DO 
# NOT EXIST.
#












# ---- chech kern.log and sim for serious errors 
#
#
# [drm:intel_pipe_update_end [i915]] *ERROR* Atomic update failure on pipe A
# any *ERROR* 
# these errors mean instant crash death
# ata1.00: exception 
# ata1.00: error:
#  Unrecovered Read Error (URE) is what indicates the drive is failing. If you get unrecovered write errors, that can be lived with for a while (drive remaps the blocks), but UREs are not OK. 
# [ 1019.726558] sd 0:0:0:0: [sda]  Add. Sense: **Unrecovered read error** - auto reallocate failed
# [ 1019.726602] JBD: **Failed to read block** at offset 462
# 
# Input/output error
#  
# message to reboot NOW (else will crash, soon)

# once a minute:
# 	check for errors
# 		logtail2 /var/syslog | logtool 
#		or
#		same as hourly, with different config (one tech)
#	alert
#
# once an hour
# 	summarize (i.e., compress repeats)
# 		use syslog-summary
# 		use Regexp::Log (its derived classes) to get better summarization
# 		best:	swatch		(perl)
# 				tenshi		same as swatch
# 				for real summarization, filtering, etc
# 	write the summary



# --- internet check
#
# check internet connection
# check that there IS a firewall (if any iceweasel, skype, qbittorrent... are running)






# Different Program: 
#
# --- census
#
# running programs
# errors found above
# top
# 	

# make test_record_every_minute
# run the /usr/local/bin/ram_usage_tester.sh and store results. poss with a ps -aux or s.t. 


































real devices: 

me > ls -1 /sys/class/block/
dm-0
dm-1
dm-2
loop0
loop1
loop2
loop3
loop4
loop5
loop6
loop7
sda
sda1
sda2
sda3
sda5
sdb
sdb1
sde
sde1
sde2
sde3
sr0

sde1 to sde3 really there


me > cat /proc/partitions
major minor  #blocks  name

   8        0   78150744 sda
   8        1    3905536 sda1
   8        2    1952768 sda2
   8        3          1 sda3
   8        5   72290304 sda5
  11        0    1048575 sr0
 254        0   29294592 dm-0
 254        1   14647296 dm-1
 254        2    4882432 dm-2
   8       16  488386584 sdb
   8       17  488386552 sdb1
   8       64  244198584 sde
   8       65    6144000 sde1
   8       66   35862528 sde2
   8       67  202189824 sde3

sde1 to sde3 really there



but
mount: 

tmpfs on /run/user/133 type tmpfs (rw,nosuid,nodev,relatime,size=205956k,mode=700,uid=133,gid=4)
/dev/sdb1 on /media/usbhd type fuseblk (rw,relatime,user_id=0,group_id=0,default_permissions,allow_other,blksize=4096)
/dev/sdc2 on /media/25GB_other type fuseblk (rw,relatime,user_id=0,group_id=0,default_permissions,allow_other,blksize=4096)
/dev/sdc1 on /media/spare_spare_dt type fuseblk (rw,relatime,user_id=0,group_id=0,default_permissions,allow_other,blksize=4096)
/dev/sdc3 on /media/200GB_downloadTorrent type fuseblk (rw,relatime,user_id=0,group_id=0,default_permissions,allow_other,blksize=4096)
/dev/sdd on /media/iPod_rockbox type vfat (rw,noexec,relatime,lazytime,uid=1000,gid=1000,fmask=0002,dmask=0002,allow_utime=0020,codepage=437,iocharset=ascii,shortname=mixed,utf8,errors=continue)


but sdc1 to sdc3 are mounted

