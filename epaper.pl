#!/usr/bin/perl -w

#use strict;
########################################################################
# Change Log --> File: epaper.pl                                       #
########################################################################
# Date      Who                  What				       #  
# --------- -------------------- ------------------------------------- #
# 03/08/06  James Lakey          This application facilitates the      #
#				 same function as the old NPO feed.    #
#								       #
#				 It works by picking up story xml      #
#				 delivered out by the SCC Archive,     #
#				 processing/massaging the xml and      #
#				 dropping it in a folder for an scc    #
#				 ftp channel to pick up.               #
#                                                                      #
########################################################################

#### this the start of the xml modification part of the code###########
my (
	$myname,
	@data,
	$inputdir,					# the input directory for unparsed xml
	$outputdir,					# the output directory for processed stable xml
	$ftpdir,					# the directory that scc's ftp channel is watching
	$logfile,					# this defines the application's log file
	$time,
	$h1,
	$error_files,
	$h2,
	$h3,
	$outfile,
	@thefiles,
	$t,
	@files,
	$xml_this_run,
	$ff,
	$xml,
	$h3_this_run,
	$h2_this_run,
	$h1_this_run
	);


#######################################################################
#
# Check if we are already running. We don't want multiple instances.
#
#######################################################################
sub runcheck {
$myname = $^X . " " . $0;
if (scalar(grep(/$myname/,`ps -ef`)) > 1)
	{
	print grep(/$myname/,`ps -ef`);
	print "Cannot start $0 because it's already running";
	exit (-1);
	}
}

###### checking the argument footprint #######
#if (scalar(@ARGV) != 1)
#	{
#	print "Usage: epaper.pl {config_file}\n";
#	print "\n";
#	exit(-2);
#	}
	
$\="";
$/="";
$time=localtime;

# miscellaneous values for date stuff
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
$year = 1900 + $year;
$thismonth = ($mon + 1);
$lastmonth = $mon;
if ($thismonth <10) {$thismonth = "0$thismonth";}
if ($lastmonth <10) {$lastmonth = "0$lastmonth";}
if ($mday <10) {$mday = "0$mday";}
$newheaderfile="$thismonth$mday$year$sec";

##########################################################
#  these are quick ways to switch directory structure
##########################################################

sub prod_config {
$inputdir="/dt2scc/DTI2SCC/epaper2/out/";
$outputdir="/dt2scc/DTI2SCC/epaper2/toftp/";
$logfile="/dtbatch/epaper/epaperpl.log";
$ftpdir="/dt2scc/DTI2SCC/epaper2/done/";
$errordir="/dt2scc/DTI2SCC/epaper2/error/";
}

sub config3 {
$inputdir="/Volumes/ajc-fcp-scc2/Deliveries/ePaper/in/";
$outputdir="/Volumes/ajc-fcp-scc2/Deliveries/ePaper/out/";
$logfile="/Volumes/ajc-fcp-scc2/Deliveries/ePaper/epaperpl.log";
$ftpdir="/Volumes/ajc-fcp-scc2/Deliveries/ePaper/toftp/";
}

sub test_config {
$inputdir="/Library/WebServer/Documents/projects/epaper_stfm/input/";
$outputdir="/Library/WebServer/Documents/projects/epaper_stfm/output/";
$ftpdir="/Library/WebServer/Documents/projects/epaper_stfm/ftpdrop/";
$logfile="/Library/WebServer/Documents/projects/epaper_stfm/log/epaperpl.log";
}

sub test_config2 {
$inputdir="/Library/WebServer/Documents/projects/epaper_stfm/input/";
$outputdir="/Library/WebServer/Documents/projects/epaper_stfm/output/";
$logfile="/Library/WebServer/Documents/projects/epaper_stfm/log/test2.log";
$ftpdir="/Library/WebServer/Documents/projects/epaper_stfm/ftpdrop/";
$errordir="/Library/WebServer/Documents/projects/epaper_stfm/error/";

}

##########################################################
# cull_log -> keeps the log file size manageable
##########################################################

sub cull_log {
	# this stuff checks the log file size and will make 
	# a new log if the current one is too big according
	# to $loglimit.
	my $st="";
	my $loglimit=1000000;
	open(LLOG,"$logfile")|| &Error_Message("#cull - Could not open the log file: $logfile");
	while(<LLOG>)
	{
	$st=$st.$_;
	}
	close(LLOG);
	$s = length($st);
	if ($s>$loglimit)
	{
	rename ("$logfile",$logfile."_old_$newheaderfile");
	}
}


#######################
#  main routines
#######################
#&runcheck;
#&prod_config;
&test_config2;
#&cull_log;

open(LOG,">>$logfile")|| &Error_Message("#1 Could not open the log file: $logfile");
print LOG "-------------------------------------------------------------------------------------------------\n";
print LOG " Epaper XML Processor is starting at $time...  \n";
print LOG "--[filenames]-------------------------------[  h1 ]-[  h2 ]-[  h3 ]------------------------------\n";
&run;
&move;
print LOG "-------------------------------------------------------------------------------------------------\n";
print LOG "\n";
close(LOG);


###########################################################
# this runs the process over all the valid directory files
###########################################################
sub run 
{
	undef @data;
	$xml_this_run=0;
	$h1_this_run=0;
	$h2_this_run=0;
	$h3_this_run=0;
	&dirwork;
	
if (scalar @thefiles)
{
	foreach $ff(@thefiles)
	{
	$xmltext="";
	open (XML, "$inputdir$ff") || &Error_Message("#2 Could not read this xml file: $inputdir$ff");
	while (<XML>){
		$xmltext=$xmltext.$_;
	}
	close(XML);
	#&xmlform($ff,$xmltext);
	&xml_node_check($ff,$xmltext);
	}

#select(LOG);
#$~=TOTALS;
#write;
#print LOG $error_files;

} else {
#print LOG "No files to process at this time...\n";
#print LOG $error_files;
}

}

##########################################################
# this reads the directory for xml files. it leaves ones
# with ( or ) in the filename.
##########################################################
sub dirwork
{
	undef @badfiles;
	undef @thefiles;
	opendir(DIR,"$inputdir") || &Error_Message("#3 Could not open this directory: $inputdir");
	@files= grep{/\.xml$/} readdir(DIR);
	close(DIR);
	
	foreach $t(@files)
	{
#	print LOG "$t\n";
	if ($t!~m/\050|\051/)
		{
	#	print LOG "something into thefiles\n";
		push(@thefiles,$t);
		}
	else {
	#	print LOG "something into badfiles\n";
		push(@badfiles,$t);
		}
		
	}
	$error_files="";
#	print LOG "error file eq $error_files\n";
	if (scalar @badfiles >= 1){
		$error_files.="\n--[bad file report]-----------------------------------------------------------\n";
		$error_files.="The following files had bad filenames and will be moved to the error directory:\n";
		foreach $d(@badfiles){
		$error_files.=$d."\n";
		system("mv \"$inputdir$d\" $errordir");
		}		
	}
	return @thefiles;
}

####################################################
# movefile -> moves files from in to target dir       
####################################################
sub movefile
{
	my ($FileName) = @_;
	$FileName =~ s?\$?\\\$?g;
	$FileName =~ s?\140?\\\140?g;
	$FileName =~ s?\042?\\\042?g;
	$FileName =~ s?\047?\\\047?g;
	if ($outputdir eq "NULL")
	{
		unlink "$outputdir$FileName";
	}
	else
	{
		system("mv \"$outputdir$FileName\" $ftpdir");
	}
}

####################################################
# move -> facilitates the final move 
####################################################
sub move
{
my $s;
my $f;
	foreach $s(@thefiles)
		{
		&movefile($s);
		}
#	print LOG "The above files were moved to the ftp folder at $time.\n";
	foreach $f(@thefiles)
		{
#		unlink "$inputdir$f";
		}
}

####################################################
# Error_Message -> handles error messages
####################################################
sub Error_Message {
local($_) =@_;
print LOG " ",$_,"\n";
print " ",$_,"\n";
print LOG "-------------------------------------\n";
print "-------------------------------------\n";
exit(0);
}

##################################################################
#  xml_node_check
##################################################################

sub xml_node_check {
my ($m,$n)=@_;
my $byline="";
my $virtloc="";
my @virtloc_rows;
my @byline_rows;
my $u=0;
my $e=0;
my $by1="";
$h1=0;
$h2=0;
$h3=0;


#print LOG "inside xml node check\n";

# all this normailizes the xml file output somewhat for the transformation
	$n=~s/\r|\n//g;
	$n=~s/\015+//g;
	$n=~s/&(?!amp;|lt;|gt;)/&amp;/g;
# this removes an extra comma placed in this field by scc if its there [h1]
	if ($n=~s/keyword key=\",/keyword key=\"/g) {$h1=1;++$h1_this_run;}
	$n=~s/\"\/>|\"\/>\r\n/\"\/>\015/g;
	$n=~s/\"\?>/\"\?>\015/g;
	$n=~s/<nitf>/\015<nitf>\015/g;
	$n=~s/<head>/<head>\015/g;
	$n=~s/<key-list><!\[CDATA\[/<key-list>/g;
	$n=~s/\]\]><\/key-list>/<\/key-list>/g;
	$n=~s/<\/(.*?)>(.*?)/<\/$1>\015/g;
	$n=~s/\015+<dateline>(.*)?<\/dateline>/<dateline>$1<\/dateline>/g;
	$n=~s/<body.content>(.*?)/<body.content>\015/g;	
	$n=~s/<byline><person>/<byline>\015<person>/g;
	$n=~s/<\/byline><dateline>/<\/byline>\015/g;

# this matches the byline node and then does some stuff 
if ($n=~/<byline>\015<person>(.*?)<\/person>\015<byttl><\/byttl>\015<virtloc>(.*?)<\/virtloc>\015<\/byline>/) {
#########################################################################################################
# the following if statements represent 4 different data scenerios involving the byline node
#########################################################################################################

# empty byline - empty email
if ((!$1) && (!$2)) {}

# full byline - empty email
if (($1) && (!$2)) {	
	$byline = $1;
	@byline_rows = split(/,/,$byline);
	$e=(scalar @byline_rows);

	if ($e eq 1) {
			$tempxml="";
			$by1="";
			$by1=&fixcase($1);
			$tempxml.="<byline>\015";
			$tempxml.="<person>$by1</person>\015";
			$tempxml.="<byttl></byttl>\015";
			$tempxml.="<virtloc></virtloc>\015";
			$tempxml.="</byline>";
			}

# if we have gotten this far we are assuming that $e > 1 and there is a byline name array
	else {
		$tempxml="";
		for ($k=0;$k<$e;$k++){
			$by1="";
			$by1=&fixcase($byline_rows[$k]);
			$tempxml.="<byline>\015";
			$tempxml.="<person>$by1</person>\015";
			$tempxml.="<byttl></byttl>\015";
			$tempxml.="<virtloc></virtloc>\015";
			$tempxml.="</byline>";
			}
	}
	# this will write out whatever is in $tempxml
	$n=~s/<byline>\015<person>(.*?)<\/person>\015<byttl><\/byttl>\015<virtloc>(.*?)<\/virtloc>\015<\/byline>/$tempxml/g;
}

# empty byline - full email
if ((!$1) && ($2)) {
	$virtloc = $1;
	@virtloc_rows = split(/,/,$byline);
	$u=(scalar @virtloc_rows);

	if ($u eq 1) {
			$tempxml="";
			$tempxml.="<byline>\015";
			$tempxml.="<person>$1</person>\015";
			$tempxml.="<byttl></byttl>\015";
			$tempxml.="<virtloc>$1</virtloc>";
			$tempxml.="</byline>\015";
			}

# if we have gotten this far we are assuming that $u > 1 and there is an email array
	else {
		$tempxml="";
		for ($k=0;$k<$u;$k++){
			$tempxml.="<byline>\015";
			$tempxml.="<person>$virtloc_rows[$k]</person>\015";
			$tempxml.="<byttl></byttl>\015";
			$tempxml.="<virtloc>$virtloc_rows[$k]</virtloc>";
			$tempxml.="</byline>\015";
			}
	}
	# this will write out whatever is in $tempxml
	$n=~s/<byline>\015<person>(.*?)<\/person>\015<byttl><\/byttl>\015<virtloc>(.*?)<\/virtloc>\015<\/byline>/$tempxml/g;
}

# full byline - full email
if (($1) && ($2)) {

	$byline = $1;
	$virtloc = $2;
	
	@byline_rows = split(/,/,$byline);
	@virtloc_rows = split(/,/,$virtloc);
	$e=(scalar @byline_rows);
	$u=(scalar @virtloc_rows);

	if (($e eq 1) && ($u eq 1)) {
			$tempxml="";
			$by1="";
			$by1=&fixcase($1);
			$tempxml.="<byline>\015";
			$tempxml.="<person>$by1</person>\015";
			$tempxml.="<byttl></byttl>\015";
			$tempxml.="<virtloc>$virtloc</virtloc>\015";
			$tempxml.="</byline>";
			}

# if we have gotten this far we are assuming that $u > 1 and there is an email array
	else {
		$tempxml="";
		for ($k=0;$k<$e;$k++){
			$by1="";
			$by1=&fixcase($byline_rows[$k]);
			$tempxml.="<byline>\015";
			$tempxml.="<person>$by1</person>\015";
			$tempxml.="<byttl></byttl>\015";
			$tempxml.="<virtloc>$virtloc_rows[$k]</virtloc>\015";
			$tempxml.="</byline>";
			}
	}
	
	$n=~s/<byline>\015<person>(.*?)<\/person>\015<byttl><\/byttl>\015<virtloc>(.*?)<\/virtloc>\015<\/byline>/$tempxml/g;
	{$h3=1;++$h3_this_run;}
} #end of if 

}


if ($n=~s/<p><\/p>//g) {$h2=1;++$h2_this_run;}

###################
# this finally writes out the xml document variable $x to the $file
	open (OUT, ">$outputdir$m") || &Error_Message("#4 Could not write the output xml file: $outputdir$m");
	print OUT $n;
	close(OUT);
# this takes care of the file's permissions	
	system("chmod 777 $outputdir$m");
# this adds 1 to the xml doc count	
	++$xml_this_run;

# this formats the log output into a nice column format. messes with strict because of the BAREWORDS
format HACKBITS=
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<    [ @|]	 [ @|]	 [ @|]
$m,$h1,$h2,$h3
.

format TOTALS=
-------------------------------------------------------------------------------------------------
Total Files Processed in this run:   @<<<<
$xml_this_run
Total hack #1 in this run:		     @<<<<
$h1_this_run
Total hack #2 in this run:		     @<<<<
$h2_this_run
Total hack #3 in this run:		     @<<<<
$h3_this_run
.

select(LOG);
$~=HACKBITS;
write;

}


###################################################
# fixcase -> fixes the byline case
###################################################
sub fixcase {
my ($name) = @_;
my @byline_wrds = split(/ /, $name);
my $tmp_byline = "";

# this is code from Vikrant Satam (Coxnet) 
# that fixes the bylines case in the produced xml

foreach my $byline_word (@byline_wrds) {
	if (!($byline_word eq "III")) {
		$byline_word = ucfirst(lc($byline_word));
	}

	#for single quotes
	if ($byline_word =~ m/'/) {
		my @by_chars = split(/'/, $byline_word);
		$byline_word = '';
		foreach my $by_char (@by_chars) {
			if ($byline_word) {
				$byline_word .= '\'';
			}
			$byline_word .= ucfirst(lc($by_char));
		}
	}

	#for hyphens
	if ($byline_word =~ m/-/) {
		my @by_chars = split(/-/, $byline_word);
		$byline_word = '';
		foreach my $by_char (@by_chars) {
			if ($byline_word) {
				$byline_word .= '-';
			}
			$byline_word .= ucfirst(lc($by_char));
		}
	}

	#for periods
	if ($byline_word =~ m/\./) {
		my @by_chars = split(/\./, $byline_word);
		$byline_word = '';
		foreach my $by_char (@by_chars) {
			if ($byline_word) {
				$byline_word .= '.';
			}
			$byline_word .= ucfirst(lc($by_char));
		}
		if (($byline_word =~ m/[A-Z]$/) || ($byline_word eq "Jr") || ($byline_word eq "Sr")) {
			$byline_word .= '.';
		}
	}

	#Scottish names
	if ($byline_word =~ m/Mc/) {
		my @scottish_names = split (/Mc/ , $byline_word);
		$byline_word = "";
		foreach my $scott (@scottish_names) {
			if ($byline_word eq '') {
				$byline_word .= "Mc" ;
			}
			else {
				$byline_word .= ucfirst(lc($scott));
				#$byline_word .= $scott;
			}

		}
	}
$tmp_byline = $tmp_byline . " " . $byline_word;
}
$tmp_byline=~s/^\s+//;
$tmp_byline=~s/\s+$//;
return $tmp_byline;
}