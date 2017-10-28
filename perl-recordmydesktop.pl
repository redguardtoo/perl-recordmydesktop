#!/usr/bin/perl -w

########################################################################
# perl-recordmydesktop.pl ---

# Copyright (C) 2013-2017 Chen Bin

# Author:  Chen Bin <chenbin.sh AT gmail DOT com>

# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 3
# of the License, or (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.


########################################################################

########################################################################
# Documentation

# DESCRIPTION:
# perl-recordmydesktop.pl is the frontend for recordMyDesktop screencast tool
# perl-recordmydesktop.pl converts the recorded video into gif

# USAGE:
# step 1: Run perl-recordmydesktop.pl
# step 2: Click the window to be captured for screencast
# step 3: Press Ctrl-Alt-S and Done. Wait for the notification from the program
# See http://askubuntu.com/questions/107726/how-to-create-animated-gif-images-of-a-screencast for original idea

# REQUIREMENTS:
# - recordmydesktop
# - xwininfo
# - ffmpeg (OPTIONAL if NO GIF is output)
# - notify-send (OPTIONAL)

# BUG REPORT:
# https://github.com/redguardtoo/perl-recordmydesktop

########################################################################

#########
# Set up
#########
# we need install notify-send to send notify message. OPTIONAL.
my $notify_send_exist=-e "/usr/bin/notify-send";
# we need install mplayer to convert video to gif.
my $ffmpeg_exist=-e "/usr/bin/ffmpeg";
# we need install imagemagic to convert video to gif
# where to store temporary files, I use ram disk for performance reason
my $volatile_dir="/dev/shm/screencast-$ENV{'USER'}";
# to store final result out.ogv and screencast.gif
my $output_dir="$ENV{'HOME'}/screencast";
# wait several seconds before screencast starts
my $delay_seconds=5;

##############
# sub-routines
##############
sub pp {
    my $s=shift;
    # print "$s\n";
}

sub notify_user {
    my $msg=shift;
    if($notify_send_exist) {
        pp "msg=$msg";
        system('notify-send -t 1500 "'.$msg.'"');
    }
    print "$msg\n";
}


sub query_window_info {
    my $wininfo=`xwininfo`;
    my @lines=split(/\n/,$wininfo);
    my $id="";
    my $width="";
    my $height="";
    my %result=();

    foreach (@lines) {
        chomp($_);
		if($_ eq ""){next;}
        if($_ =~ /Window id: +([^ ]+)/){
            pp "line=$_";
            $result{"id"}=$1
        } elsif ($_ =~ /Width: +([0-9]+)/){
            $result{"width"}=$1
        } elsif ($_ =~ /Height: +([0-9]+)/){
            $result{"height"}=$1
        } elsif ($_ =~ /Absolute upper-left X: +([0-9]+)/){
            #recordmydesktop don't accept the 0 for origin
            if ($1 eq "0"){
                $result{"offset_x"}="1";
            } else {
                $result{"offset_x"}=$1;
            }
        } elsif ($_ =~ /Absolute upper-left Y: +([0-9]+)/){
            #recordmydesktop don't accept the 0 for origin
            if ($1 eq "0"){
                $result{"offset_y"}="1";
            } else {
                $result{"offset_y"}=$1;
            }
        }
    }
    return \%result;
}

########
# main
########

# get the pointer to the hash
my $wininfo=query_window_info();
# create video file in memory then move it into the actual dir
system("mkdir -p $volatile_dir;rm $volatile_dir/*");
# my $screencast_cmd="mkdir -p $output_dir;recordmydesktop --overwrite --no-sound -o $output_dir/out.ogv --windowid $wininfo->{'id'}";
my $screencast_cmd="mkdir -p $output_dir;recordmydesktop --width $wininfo->{'width'} --height $wininfo->{'height'} -x $wininfo->{'offset_x'} -y $wininfo->{'offset_y'} --overwrite --no-sound -o $volatile_dir/out.ogv ";
notify_user("command to convert screencast to video: $screencast_cmd");
pp "wininfo=$wininfo";


notify_user("wait $delay_seconds seconds before screencast start!");
for (1..$delay_seconds) {
    notify_user($delay_seconds-$_+1);
    sleep 1;
}

notify_user("press Ctrl-Alt-s to finish!");
for (1..$delay_seconds) {
    notify_user($delay_seconds-$_+1);
    sleep 1;
}
system('notify-send -t 1 "screencast begins ..."');
# sleep another a few seconds to make sure the notificaion message is gone
sleep 3;
if(system($screencast_cmd)!=0){
    pp "screencast_cmd failed!";
    exit 1;
}
if( $ffmpeg_exist){

    # put the file in memory
    notify_user("Preparing palette ...");
    system("ffmpeg -i $volatile_dir/out.ogv -vf fps=15,palettegen $volatile_dir/tmp_palette.png");

    notify_user("Producing GIF ...");
    system("ffmpeg -i $volatile_dir/out.ogv -i $volatile_dir/tmp_palette.png -loop 0 -filter_complex 'fps=15,scale=-1:-1:flags=lanczos[x];[x][1:v]paletteuse' $output_dir/screencast.gif");
    system("mv $volatile_dir/out.ogv $output_dir/out.ogv");

    notify_user("DONE! out.ogv and screencast.gif saved in $output_dir");

} else {
    system("mv $volatile_dir/out.ogv $output_dir/out.ogv");
    notify_user("screencast saved into $output_dir/out.ogv");
}
