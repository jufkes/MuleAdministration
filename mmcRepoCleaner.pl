#!/usr/bin/perl
# change the MMCUSER to the username used for the admin account of your mmc instance
# change the MMCPASS to the password for the admin account
# change the URL to the base URL of your mmc
# any issues read through the MMC API docs as there's a good chance the URL is incorrect of the JSON might have changed
# NOTE...this is not threaded and can take some time pending the size of the repo
# WARNING: it will remove all but the current deployed version

use strict;
use warnings;
use JSON;


my $mmcUser = "MMCUSER";
my $mmcPass = "USERPASS";
my $mmcUrl = "http://mmc.url.string:port/mmc/";

open LOG, ">>", "mmcRepoCleaner.log" || die "Shit: $!";
my $installed_ids_ra = InstalledApps();
my $repoed_ids_rh = RepoApps();
my $final_rh = FinalList($installed_ids_ra, $repoed_ids_rh); 
foreach my $key (keys %{ $final_rh }) {
	print LOG "Deleting $key using a post to $mmcUrl/$key/delete\n";
	system("curl -X POST --basic -u $mmcUser:$mmcPass $mmcUrl/repository$key/delete");
}

close LOG;
#----------------
# SUBs
#----------------

sub InstalledApps {
	print LOG "Getting JSON payload from $mmcUrl/deployments...\n";
	system("curl --basic -u $mmcUser:$mmcPass $mmcUrl/deployments >> Deployments.json");
        open FILE, "<", "Deployments.json" || die "Could not open file: $!";
        my $installedAppsJSON = <FILE>;
        close FILE;
        my $json = new JSON;
        my $j = $json->allow_nonref->utf8->relaxed->escape_slash->loose->allow_singlequote->allow_barekey->decode($installedAppsJSON);
        my @ids = ();

        foreach my $data (@{$j->{'data'}}) {
		push (@ids, $data->{'applications'}->[0]);		
        }
	print LOG "Deployed IDs:\n";
	foreach my $id(@ids) {
		print LOG $id . "\n";
	}
	print LOG "Number of Apps: " . scalar @ids . "\n";
        return \@ids; 
}

sub RepoApps {
	print LOG "Getting JSON payload from $mmcUrl/repository...\n";
	system("curl --basic -u $mmcUser:$mmcPass $mmcUrl/repository >> /Repo.json");
        open FILE, "<", "Repo.json" || die "Could not open file: $!";
        my $repoAppsJSON = <FILE>;
        close FILE;
        my $json = new JSON;
        my $j = $json->allow_nonref->utf8->relaxed->escape_slash->loose->allow_singlequote->allow_barekey->decode($repoAppsJSON);
        my $ids_rh = {}; 

        foreach my $data (@{$j->{'data'}}) {
		foreach my $version (@{$data->{'versions'}}) {
			$ids_rh->{$version->{'id'}}=undef;
		}
        }
	print LOG "Number of packages in repo: " . keys (%$ids_rh) . "\n";
        return $ids_rh;
}

sub FinalList {
        my ($inst_ids_ra, $repo_ids_rh) = @_;
	print LOG "BEFORE merge: " . scalar ( keys %{$repo_ids_rh} ) . "\n";
	delete $repo_ids_rh->{$_} for (@{$inst_ids_ra});
	print LOG "AFTER merge: " . scalar ( keys %{$repo_ids_rh} ) . "\n";
        return $repo_ids_rh;
}
