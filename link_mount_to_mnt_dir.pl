#!/usr/bin/perl

# this script mounts media. It is used by udev, via a trigger script, so that
# udev does not hang or block: udev calls must finish INSTANTLY.  
# The trigger script is necessary, it is udev_mount_trigger.pl

# Q: what if the filesystem is already mounted, or the mount point is being used?
# 

use common::sense; 
use IO::All;
use Getopt::Long qw(:config no_ignore_case bundling);

my $mountPoint2LinkFile = "/media/linksToMountpoints.lst";
my $temp_mp2ln          = "/tmp/tmpfile_delme";  
my $logfile             = "/var/log/userspace/udev.log";
my @mountpointDirs		= ("/media", "/usbhd");
my @removeTheseDirs		= ( "\$RECYCLE.BIN", "System Volume Information"); 

# --- command line
my $mount_point  = "/dev/null";
GetOptions(	"i:s"		=> \$mount_point,		# -conf 	optional string
		);


# --- make the links
# link a single mountpoint
if ($mount_point !~ /dev\/null/){
	linkOneMountpoint( $mount_point ); 
}
else
# else, link all existing mountpoints 
{
	my @dirs; 	
	foreach my $thisDir (@mountpointDirs){
		if ( -d $thisDir ) { 	
			push @dirs, io->dir($thisDir)->all_dirs; 
		}; 
	}
	foreach my $thisDir (@dirs) {
		my $dirName = $thisDir->name; 
		next if $dirName =~ /\.\./; 
		next if $dirName =~ /\./;
		linkOneMountpoint( "$dirName" ); 
	}
}


sub linkOneMountpoint {
# 3. make links to the mountpoint
#the links to each mountpoint are in the $mountPoint2LinkFile file
# extract the one or two (or N) links involving this mountpoint
# GOTCHA: the directories are swapped:  $2  $1
	my $mount_point = shift;

	my @ln_FromTo = `/bin/grep -v "^#" $mountPoint2LinkFile | /bin/grep "$mount_point" `;
	chomp (@ln_FromTo);
	# skip any dirs that do not have a link listed for them in the mountpoint link file
	return
		if (0 == @ln_FromTo );

	# each line in the file is 
	#		LinkFromPath    LinkToPath
	# this is the one or two (or N) relevant links
	# NOTE: the fromDir will be the symbolic link. It should NOT exist
	# 		the toDir is the mounted device's mount point. It exists.
	foreach my $this_lnFromTo (@ln_FromTo) {
		# --- get the ln from & ln to dir names
		# (my $fromDir, my $toDir) = split / /,$this_lnFromTo; 
		$this_lnFromTo =~ /(\S*)\s+(\S*)\s*/;
		# \S not whitespace
		# \s whitespace
		my $fromDir = $1;  
		my $toDir = $2; 
		# if the link already exists, return
		my $io_obj = io $fromDir;
		if ($io_obj->is_link){
			my $toLinkTarget = $io_obj->readlink; 
			next
				if ($toLinkTarget->name eq $toDir) ; 
		}

		# --- link: make the link
		# Do NOT remove junk at the dir entry where the symbolic link
		# If they 
		# # right, really get rid of any left-over symbolic links
		# `rmdir $fromDir/* 2> /dev/null`; 			# dirs
		# #`unlink @fromAndToDirs[0]/*  2> /dev/null`; #won't work
		# `rmdir $fromDir 2> /dev/null`; 			#links
		`mv $fromDir $fromDir."_weird"` if ( -d $fromDir );  
		`unlink $fromDir/* 	2> /dev/null`;			
		`unlink $fromDir 	2> /dev/null`;			
		
		# make the ln link, from real mounted point to some dirl
		# ln target linkName
		`ln -f  -T -s $toDir  $fromDir `;
		# -f force: move any existing 'link name' directories
		# -T do not detect if the link_name is a pre-existing directory
		`echo \"made the $fromDir $toDir link  \" >> $logfile`;

		#--- clean-ups
		# unlink /media/20g_20GB/20g_20GB  	which is a mistake
		# unlink /mnt/20g/20g  				which is a mistake
		my $io_obj = io $fromDir;
		my $basename = $io_obj->filename; 
		`unlink $fromDir/$basename 2> /dev/null`; 
		my $io_obj = io $toDir;
		`unlink $toDir/$basename 2> /dev/null`; 

		# remove $RECYCLE.BIN and "System Volume Information"
		foreach my $rmThisDir (@removeTheseDirs) {
			`rm -fr \"$toDir/$rmThisDir\" `
				if ( -d "$toDir/$rmThisDir" );
		}
	}
}






