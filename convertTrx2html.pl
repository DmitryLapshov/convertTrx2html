#!/usr/bin/env perl

# Author:	Dmitry Lapshov
# Purpose:	a simple conversion of VS2012 trx file into html properly displayed by gmail web interfaces

use Modern::Perl;
use XML::XPath;
use XML::XPath::XMLParser;
use Date::Parse;
use POSIX qw(strftime);

my $filename = $ARGV[0];

die 'Usage: convertTrx2html.pl abc.trx' unless defined $filename;

my $xp = XML::XPath -> new(filename => $filename);

my @times = $xp -> findnodes('/TestRun/Times');
my $start = str2time($times[0] -> getAttribute('start'));
my $finish = str2time($times[0] -> getAttribute('finish'));
my $summary_duration = strftime("%H:%M:%S", gmtime($finish - $start));

my @table = ();
for my $test ($xp -> findnodes('/TestRun/TestDefinitions/UnitTest')){
	my @executions = $test -> findnodes('./Execution');
	my $executionID = $executions[0] -> getAttribute('id');
	my @testMethods = $test -> findnodes('./TestMethod');
	my @testResults = $xp -> findnodes('/TestRun/Results/UnitTestResult[@executionId = "'.$executionID.'"]');
	my @messages = $testResults[0] -> findnodes('./Output/ErrorInfo/Message');
	my @stackTraces = $testResults[0] -> findnodes('./Output/ErrorInfo/StackTrace');
	
	my $row = {
		className => $testMethods[0] -> getAttribute('className'),
		testMethod => $testMethods[0] -> getAttribute('name'),
		outcome => $testResults[0] -> getAttribute('outcome'),
		message => scalar @messages ? $messages[0] -> string_value : '',
		stackTrace => scalar @stackTraces ? $stackTraces[0] -> string_value : '',
		duration => $testResults[0] -> getAttribute('duration')
	};
	
	push @table, $row;
}

my $summary_total = scalar @table;
my $summary_passed = scalar grep{$_ -> {outcome} eq 'Passed'} @table;
my $summary_failed = scalar grep{$_ -> {outcome} eq 'Failed'} @table;
my $summary_ignored = $summary_total - $summary_passed - $summary_failed;
my $summary_percent = sprintf("%.2f", $summary_passed / $summary_total * 100);

my %failedClasses = map{$_ -> {className} => 1} grep{$_ -> {outcome} eq 'Failed'} @table;

my @table_by_duration = sort{$a -> {duration} cmp $b -> {duration}} @table;

##################################################################################################################################################
my $html = qq(
<html>
	<head>
		<title>Nightly Build and Test</title>
	</head>
	<body style="font-family:Arial,Helvetica,sans-serif;font-size:12px;">
		<table id="Summary" style="width:1200px;border:1px solid black;border-collapse:collapse;font-family:Arial,Helvetica,sans-serif;font-size:12px;">
			<caption style="padding:5px;text-align:left;"><a name="Summary"><b>Summary</b></a></caption>
			<tr>
				<th style="width:5%;border:1px solid black;border-collapse:collapse;background-color:#555555;color:white;padding:5px;">Percent</th>
				<th style="width:45%;border:1px solid black;border-collapse:collapse;background-color:#555555;color:white;padding:5px;">Status</th> 
				<th style="width:5%;border:1px solid black;border-collapse:collapse;background-color:#555555;color:white;padding:5px;">Total</th>
				<th style="width:5%;border:1px solid black;border-collapse:collapse;background-color:#555555;color:white;padding:5px;">Passed</th>
				<th style="width:5%;border:1px solid black;border-collapse:collapse;background-color:#555555;color:white;padding:5px;">Failed</th>
				<th style="width:5%;border:1px solid black;border-collapse:collapse;background-color:#555555;color:white;padding:5px;">Ignored</th>
				<th style="width:10%;border:1px solid black;border-collapse:collapse;background-color:#555555;color:white;padding:5px;">Duration</th>
			</tr>
);

my $status;
if(int($summary_percent) == 100){
	$status = qq(
		<tr><td style="width:100%;height:7px;background-color:green;"></td></tr>
	);
}
elsif(int($summary_percent) == 0){
	$status = qq(
		<tr><td style="width:100%;height:7px;background-color:red;"></td></tr>
	);
}
else{
	$status = qq(
		<tr><td style="width:$summary_percent%;height:7px;background-color:green;"></td><td style="background-color:red;height:7px;"></td></tr>
	);
}

$html .= qq(
			<tr>
				<td style="border:1px solid black;border-collapse:collapse;padding:5px;">$summary_percent%</td>
				<td style="border:1px solid black;border-collapse:collapse;padding:5px;">
					<table style="width:100%;border:0px;border-collapse:collapse;">
						$status
					</table>
				</td> 
				<td style="border:1px solid black;border-collapse:collapse;padding:5px;">$summary_total</td>
				<td style="border:1px solid black;border-collapse:collapse;padding:5px;">$summary_passed</td>
				<td style="border:1px solid black;border-collapse:collapse;padding:5px;">$summary_failed</td>
				<td style="border:1px solid black;border-collapse:collapse;padding:5px;">$summary_ignored</td>
				<td style="border:1px solid black;border-collapse:collapse;padding:5px;text-align:center;">$summary_duration</td>
			</tr>
		</table>
		<br />
		<table style="width:1200px;border:1px solid black;border-collapse:collapse;font-family:Arial,Helvetica,sans-serif;font-size:12px;">
			<caption style="padding:5px;text-align:left;"><b>Failed Test Classes</b></caption>
			<tr>
				<th style="width:50%;border:1px solid black;border-collapse:collapse;background-color:#555555;color:white;padding:5px;">Class Name</th>
				<th style="width:5%;border:1px solid black;border-collapse:collapse;background-color:#555555;color:white;padding:5px;">Percent</th> 
				<th style="width:10%;border:1px solid black;border-collapse:collapse;background-color:#555555;color:white;padding:5px;">Status</th>
				<th style="width:5%;border:1px solid black;border-collapse:collapse;background-color:#555555;color:white;padding:5px;">Total</th>
				<th style="width:5%;border:1px solid black;border-collapse:collapse;background-color:#555555;color:white;padding:5px;">Passed</th>
				<th style="width:5%;border:1px solid black;border-collapse:collapse;background-color:#555555;color:white;padding:5px;">Failed</th>
				<th style="width:5%;border:1px solid black;border-collapse:collapse;background-color:#555555;color:white;padding:5px;">Ignored</th>
			</tr>
);

my $e = 0;
for my $class (sort keys %failedClasses){
	my $bg = $e % 2 ? '#fff' : '#eee';
	my @methods = grep{$_ -> {className} eq $class} @table;
	my $total = scalar @methods;
	my $passed = scalar grep{$_ -> {className} eq $class && $_ -> {outcome} eq 'Passed'} @methods;
	my $failed = scalar grep{$_ -> {className} eq $class && $_ -> {outcome} eq 'Failed'} @methods;
	my $ignored = $total - $passed - $failed;
	my $percent = sprintf("%.2f", $passed / $total * 100);
	if(int($percent) == 100){
		$status = qq(
			<tr><td style="width:100%;height:7px;background-color:green;"></td></tr>
		);
	}
	elsif(int($percent) == 0){
		$status = qq(
			<tr><td style="width:100%;height:7px;background-color:red;"></td></tr>
		);
	}
	else{
		$status = qq(
			<tr><td style="width:$percent%;height:7px;background-color:green;"></td><td style="background-color:red;height:7px;"></td></tr>
		);
	}
	$html .= qq(
			<tr style="background-color:$bg;">
				<td style="border:1px solid black;border-collapse:collapse;padding:5px;"><a href="#$class">$class</a></td>
				<td style="border:1px solid black;border-collapse:collapse;padding:5px;">$percent%</td> 
				<td style="border:1px solid black;border-collapse:collapse;padding:5px;">
					<table style="width:100%;border:0px;border-collapse:collapse;">
						<tr>
							$status
						</tr>
					</table></td>
				<td style="border:1px solid black;border-collapse:collapse;padding:5px;">$total</td>
				<td style="border:1px solid black;border-collapse:collapse;padding:5px;">$passed</td>
				<td style="border:1px solid black;border-collapse:collapse;padding:5px;">$failed</td>
				<td style="border:1px solid black;border-collapse:collapse;padding:5px;">$ignored</td>
			</tr>
	);
	$e++;
}

$html .= qq(
		</table>
		<br />
		<table style="width:1200px;border:1px solid black;border-collapse:collapse;font-family:Arial,Helvetica,sans-serif;font-size:12px;">
			<caption style="padding:5px;text-align:left;"><b>TOP 5 Slower Methods</b></caption>
			<tr>
				<th style="width:80%;border:1px solid black;border-collapse:collapse;background-color:#555555;color:white;padding:5px;">Test Method</th>
				<th style="width:5%;border:1px solid black;border-collapse:collapse;background-color:#555555;color:white;padding:5px;">Status</th>
				<th style="width:15%;border:1px solid black;border-collapse:collapse;background-color:#555555;color:white;padding:5px;">Duration</th>
			</tr>
);

for(1..5){
	if(my $method = $table_by_duration[-$_]){
		my $method_name = $method -> {className}.'.'.$method -> {testMethod};
		my $bg = $_ % 2 ? '#fff' : '#eee';
		my $color = $method -> {outcome} eq 'Passed' ? 'green' : 'red';
		my $duration = $method -> {duration};
		$html .= qq(
			<tr style="background-color:$bg;">
				<td style="border:1px solid black;border-collapse:collapse;padding:5px;">$method_name</td>
				<td style="border:1px solid black;border-collapse:collapse;padding:5px;">
					<table style="width:100%;border:0px;border-collapse:collapse;">
						<tr>
							<td style="border:0px;border-collapse:collapse;width:100%;background-color:$color;height:7px;"></td>
						</tr>
					</table>
				</td> 
				<td style="border:1px solid black;border-collapse:collapse;padding:5px;text-align:center;">$duration</td>
			</tr>	
		);
	}
}
$html .= qq(
		</table>
		<br />
);

for my $class (sort keys %failedClasses){
	$html .= qq(
		<table id="$class" style="width:1200px;border:1px solid black;border-collapse:collapse;font-family:Arial,Helvetica,sans-serif;font-size:12px;">
			<caption style="padding:5px;text-align:left;"><a name="$class"><b>$class</b></a></caption>
			<tr>
				<th style="width:35%;border:1px solid black;border-collapse:collapse;background-color:#555555;color:white;padding:5px;">Test Method</th>
				<th style="width:55%;border:1px solid black;border-collapse:collapse;background-color:#555555;color:white;padding:5px;">Output</th>
				<th style="width:10%;border:1px solid black;border-collapse:collapse;background-color:#555555;color:white;padding:5px;">Duration</th>
			</tr>		
	);
	my @methods = sort{$a -> {testMethod} cmp $b -> {testMethod}} grep{$_ -> {className} eq $class && $_ -> {outcome} eq 'Failed'} @table;
	my $e = 0;
	for my $method (@methods){
		my $bg = $e % 2 ? '#fff' : '#eee';
		my $test_method = $method -> {testMethod};
		my $message = $method -> {message};
		my $stackTrace = $method -> {stackTrace};
		my $duration = $method -> {duration};
		$html .= qq(
			<tr style="background-color:$bg;">
				<td style="border:1px solid black;border-collapse:collapse;padding:5px;">$test_method</td>
				<td style="border:1px solid black;border-collapse:collapse;padding:5px;">
					<table style="width:100%;border:0px;border-collapse:collapse;font-family:Arial,Helvetica,sans-serif;font-size:12px;">
						<tr style="background-color:#fff;">
							<td style="border:0px;border-collapse:collapse;padding:5px;">$message</td>
						</tr>
						<tr style="background-color:#eee;">
							<td style="border:0px;border-collapse:collapse;padding:5px;">$stackTrace</td>
						</tr>
					</table>
				</td> 
				<td style="border:1px solid black;border-collapse:collapse;padding:5px;text-align:center;">$duration</td>
			</tr>
		);
		$e++;
	}
	$html .= qq(
		</table>
		<a href="#Summary">Top</a>
		<br />
	);
}

my $built = strftime("%Y-%m-%d %H:%M:%S", localtime);

$html .= qq(
		<table style="width:1200px;border:0px;border-collapse:collapse;font-family:Arial,Helvetica,sans-serif;font-size:10px;">
			<tr style="background-color:#eee;">
				<td style="border:0px;border-collapse:collapse;padding:5px;text-align:left;"><b>Date:</b></td>
				<td style="border:0px;border-collapse:collapse;padding:5px;text-align:left;">$built</td>
			</tr>
			<tr style="background-color:#eee;">
				<td style="border:0px;border-collapse:collapse;padding:5px;text-align:left;"><b>File:</b></td>
				<td style="border:0px;border-collapse:collapse;padding:5px;text-align:left;">$filename</td>
			</tr>
			<tr style="background-color:#eee;">
				<td style="border:0px;border-collapse:collapse;padding:5px;text-align:left;"><b>Author:</b></td>
				<td style="border:0px;border-collapse:collapse;padding:5px;text-align:left">Dmitry Lapshov</td>
			</tr>
		</table>
	</body>
</html>
);

#########################################################
say $html;