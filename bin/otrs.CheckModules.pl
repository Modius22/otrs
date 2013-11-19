#!/usr/bin/perl
# --
# bin/otrs.CheckModules.pl - to check needed cpan framework modules
# Copyright (C) 2001-2013 OTRS AG, http://otrs.com/
# --
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU AFFERO General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301 USA
# or see http://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;

use File::Basename;
use FindBin qw($RealBin);
use lib dirname($RealBin);
use lib dirname($RealBin) . '/Kernel/cpan-lib';
use lib dirname($RealBin) . '/Custom';

# on Windows, we only have ANSI support if Win32::Console::ANSI is present
# turn off colors if it is not available
BEGIN {
    if ( $^O eq 'MSWin32' ) {
        ## no critic
        eval 'use Win32::Console::ANSI';
        ## use critic
        $ENV{nocolors} = 1 if $@;
    }
}

use ExtUtils::MakeMaker;
use File::Path;
use Getopt::Long;
use Term::ANSIColor;

use Kernel::Config;
use Kernel::System::Log;
use Kernel::System::Main;
use Kernel::System::DB;
use Kernel::System::Environment;

my $ConfigObject = Kernel::Config->new();
my $EncodeObject = Kernel::System::Encode->new(
    ConfigObject => $ConfigObject,
);
my $LogObject = Kernel::System::Log->new(
    ConfigObject => $ConfigObject,
    EncodeObject => $EncodeObject,
);
my $MainObject = Kernel::System::Main->new(
    ConfigObject => $ConfigObject,
    EncodeObject => $EncodeObject,
    LogObject    => $LogObject,
);
my $DBObject = Kernel::System::DB->new(
    ConfigObject => $ConfigObject,
    EncodeObject => $EncodeObject,
    LogObject    => $LogObject,
    MainObject   => $MainObject,
);
our $EnvironmentObject = Kernel::System::Environment->new(
    EncodeObject => $EncodeObject,
    ConfigObject => $ConfigObject,
    LogObject    => $LogObject,
    MainObject   => $MainObject,
    DBObject     => $DBObject,
);

our %InstTypeToCMD = (
    aptget  => 'apt-get install -y %s',
    ppm     => 'ppm install %s',
    gcpan   => 'g-cpan -i %s',
    yum     => 'yum install "perl(%s)',
    zypper  => 'zypper install "perl(%s)"',
    default => 'cpan %s',
);
#gentoo, solaris, oracle
our %DistToInstType = (
    # apt-get
    debian   => 'aptget',
    ubuntu   => 'aptget',
    # gcpan
    gentoo   => 'gcpan',
    # yum
    fedora   => 'yum',
    rhel     => 'yum',
    redhat   => 'yum',
    # zypper
    suse     => 'zypper',
    # ppm
    win32as  => 'ppm',
);

my %OSData  = $EnvironmentObject->OSInfoGet();
our $OSDist = $OSData{Distribution};
# set win32as if active state perl is installed on windows.
# for windows installations without active state perl we use the default.
if (_CheckActiveStatePerl()) {
    $OSDist = 'win32as';
}

my $AllModules;
GetOptions( all => \$AllModules );

my $Options = shift || '';
my $NoColors;

if ( $ENV{nocolors} || $Options =~ m{\A nocolors}msxi ) {
    $NoColors = 1;
}

# config
my @NeededModules = (
    {
        Module        => 'Crypt::Eksblowfish::Bcrypt',
        Required      => 0,
        Comment       => 'For strong password hashing.',
        InstTypes => {
            aptget => 'libcrypt-eksblowfish-perl',
            gcpan  => 'Crypt::Eksblowfish::Bcrypt',
            ppm    => 'Crypt-Eksblowfish',
            yum    => 'Crypt::Eksblowfish::Bcrypt',
            zypper => 'Crypt::Eksblowfish::Bcrypt',
        },
    },
    {
        Module        => 'Crypt::SSLeay',
        Required      => 0,
        Comment       => 'Required for Generic Interface SOAP SSL connections.',
        InstTypes => {
            aptget => 'libcrypt-ssleay-perl',
            gcpan  => 'Crypt::SSLeay',
            ppm    => 'Crypt-SSLeay',
            yum    => 'Crypt::SSLeay',
            zypper => 'Crypt::SSLeay',
        },
    },
    {
        Module        => 'Date::Format',
        Required      => 1,
        InstTypes => {
            aptget => 'libtimedate-perl',
            gcpan  => 'Date::Format',
            ppm    => 'TimeDate',
            yum    => 'Date::Format',
            zypper => 'Date::Format',
        },
    },
    {
        Module        => 'DBI',
        Required      => 1,
        InstTypes => {
            aptget => 'libdbi-perl',
            gcpan  => 'DBI',
            ppm    => 'DBI',
            yum    => 'DBI',
            zypper => 'DBI',
        },
    },
    {
        Module        => 'DBD::mysql',
        Required      => 0,
        Comment       => 'Required to connect to a MySQL database.',
        InstTypes => {
            aptget => 'libdbi-mysql-perl',
            gcpan  => 'DBD::mysql',
            ppm    => 'DBD-mysql',
            yum    => 'DBD::mysql',
            zypper => 'DBD::mysql',
        },
    },
    {
        Module       => 'DBD::ODBC',
        Required     => 0,
        NotSupported => [
            {
                Version => '1.23',
                Comment =>
                    'This version is broken and not useable! Please upgrade to a higher version.',
            },
        ],
        Comment       => 'Required to connect to a MS-SQL database.',
        InstTypes => {
            aptget => 'libdb-odbc-perl',
            gcpan  => 'DBD::ODBC',
            ppm    => 'DBD-ODBC',
            yum    => 'DBD::ODBC',
            zypper => 'DBD::ODBC',
        },
    },
    {
        Module        => 'DBD::Oracle',
        Required      => 0,
        Comment       => 'Required to connect to a Oracle database.',
        InstTypes => {
            gcpan  => 'DBD::Oracle',
            ppm    => 'DBD-Oracle',
            yum    => 'DBD::Oracle',
            zypper => 'DBD::Oracle',
        },
    },
    {
        Module        => 'DBD::Pg',
        Required      => 0,
        Comment       => 'Required to connect to a PostgreSQL database.',
        InstTypes => {
            aptget => 'libdb-pg-perl',
            gcpan  => 'DBD::Pg',
            ppm    => 'DBD-Pg',
            yum    => 'DBD::Pg',
            zypper => 'DBD::Pg',
        },
    },
    {
        Module        => 'Encode::HanExtra',
        Version       => '0.23',
        Required      => 0,
        Comment       => 'Required to handle mails with several Chinese character sets.',
        InstTypes => {
            aptget => 'libencode-hanextra-perl',
            gcpan  => 'Encode::HanExtra',
            yum    => 'Encode::HanExtra',
            zypper => 'Encode::HanExtra',
        },
    },
    {
        Module        => 'GD',
        Required      => 0,
        Comment       => 'Required for stats.',
        InstTypes => {
            aptget => 'libgd-gd2-perl',
            gcpan  => 'GD',
            ppm    => 'GD',
            yum    => 'GD',
            zypper => 'GD',
        },
        Depends => [
            {
                Module        => 'GD::Text',
                Required      => 0,
                Comment       => 'Required for stats.',
                InstTypes => {
                    aptget => 'libgd-text-perl',
                    gcpan  => 'GD::Text',
                    ppm    => 'GDTextUtil',
                    yum    => 'GD::Text',
                    zypper => 'GD::Text',
                }
            },
            {
                Module        => 'GD::Graph',
                Required      => 0,
                Comment       => 'Required for stats.',
                InstTypes => {
                    aptget => 'libgd-graph-perl',
                    gcpan  => 'GD::Graph',
                    ppm    => 'GDGraph',
                    yum    => 'GD::Graph',
                    zypper => 'GD::Graph',
                },
            },
        ],
    },
    {
        Module        => 'IO::Socket::SSL',
        Required      => 0,
        Comment       => 'Required for SSL connections to web and mail servers.',
        InstTypes => {
            aptget => 'libio-socket-ssl-perl',
            gcpan  => 'IO::Socket::SSL',
            ppm    => 'IO-Socket-SSL',
            yum    => 'IO::Socket::SSL',
            zypper => 'IO::Socket::SSL',
        },
    },
    {
        Module        => 'JSON::XS',
        Required      => 0,
        Comment       => 'Recommended for faster AJAX/JavaScript handling.',
        InstTypes => {
            aptget => 'libjson-xs-perl',
            gcpan  => 'JSON::XS',
            ppm    => 'JSON-XS',
            yum    => 'JSON::XS',
            zypper => 'JSON::XS',
        },
    },
    {
        Module        => 'LWP::UserAgent',
        Required      => 1,
        InstTypes => {
            aptget => 'libwww-perl',
            gcpan  => 'LWP::UserAgent',
            ppm    => 'libwww-perl',
            yum    => 'LWP::UserAgent',
            zypper => 'LWP::UserAgent',
        },
    },
    {
        Module        => 'Mail::IMAPClient',
        Version       => '3.22',
        Comment       => 'Required for IMAP TLS connections.',
        Required      => 0,
        InstTypes => {
            aptget => 'libmail-imapclient-perl',
            gcpan  => 'Mail::IMAPClient',
            ppm    => 'Mail-IMAPClient',
            yum    => 'Mail::IMAPClient',
            zypper => 'Mail::IMAPClient',
        },
        Depends => [
            {
                Module        => 'IO::Socket::SSL',
                Required      => 0,
                Comment       => 'Required for IMAP TLS connections.',
                InstTypes => {
                    aptget => 'libio-socket-ssl-perl',
                    gcpan  => 'IO::Socket::SSL',
                    ppm    => 'IO-Socket-SSL',
                    yum    => 'IO::Socket::SSL',
                    zypper => 'IO::Socket::SSL',
                },
            },
        ],
    },
    {
        Module        => 'ModPerl::Util',
        Required      => 0,
        Comment       => 'Improves Performance on Apache webservers dramatically.',
        InstTypes => {
            aptget => 'libapache2-mod-perl2',
            gcpan  => 'ModPerl::Util',
        },
            yum    => 'ModPerl::Util',
            zypper => 'ModPerl::Util',
    },
    {
        Module       => 'Net::DNS',
        Required     => 1,
        NotSupported => [
            {
                Version => '0.60',
                Comment =>
                    'This version is broken and not useable! Please upgrade to a higher version.',
            },
        ],
        InstTypes => {
            aptget => 'libnet-dns-perl',
            gcpan  => 'Net::DNS',
            ppm    => 'Net-DNS',
            yum    => 'Net::DNS',
            zypper => 'Net::DNS',
        },
    },
    {
        Module        => 'Net::LDAP',
        Required      => 0,
        Comment       => 'Required for directory authentication.',
        InstTypes => {
            aptget => 'libnet-ldap-perl',
            gcpan  => 'Net::LDAP',
            ppm    => 'Net-LDAP',
            yum    => 'Net::LDAP',
            zypper => 'Net::LDAP',
        },
    },
    {
        Module        => 'Net::SSL',
        Required      => 0,
        Comment       => 'Required for Generic Interface SOAP SSL connections.',
        InstTypes => {
            aptget => 'libcrypt-ssleay-perl',
            gcpan  => 'Net::SSL',
            ppm    => 'Crypt-SSLeay',
            yum    => 'Net::SSL',
            zypper => 'Net::SSL',
        },
    },
    {
        Module       => 'PDF::API2',
        Version      => '0.57',
        Required     => 0,
        Comment      => 'Required for PDF output.',
        NotSupported => [
            {
                Version => '0.71.001',
                Comment =>
                    'This version is broken and not useable! Please upgrade to a higher version.',
            },
            {
                Version => '0.72.001',
                Comment =>
                    'This version is broken and not useable! Please upgrade to a higher version.',
            },
            {
                Version => '0.72.002',
                Comment =>
                    'This version is broken and not useable! Please upgrade to a higher version.',
            },
            {
                Version => '0.72.003',
                Comment =>
                    'This version is broken and not useable! Please upgrade to a higher version.',
            },
        ],
        InstTypes => {
            aptget => 'libpdf-api2-perl',
            gcpan  => 'PDF::API2',
            ppm    => 'PDF-API2',
            yum    => 'PDF::API2',
            zypper => 'PDF::API2',
        },
    },
    {
        Module        => 'Text::CSV_XS',
        Required      => 0,
        Comment       => 'Recommended for faster CSV handling.',
        InstTypes => {
            aptget => 'libtext-csv-xs-perl',
            gcpan  => 'Text::CSV_XS',
            ppm    => 'Text-CSV_XS',
            yum    => 'Text::CSV_XS',
            zypper => 'Text::CSV_XS',
        },
    },
    {
        Module        => 'Time::HiRes',
        Required      => 1,
        Comment       => 'Required for high resolution timestamps.',
        InstTypes => {
            aptget => 'perl',
            gcpan  => 'Time::HiRes',
            ppm    => 'Time-HiRes',
            yum    => 'Time::HiRes',
            zypper => 'Time::HiRes',
        },
    },
    {
        Module        => 'XML::Parser',
        Required      => 0,
        Comment       => 'Recommended for faster xml handling.',
        InstTypes => {
            aptget => 'libxml-parser-perl',
            gcpan  => 'XML::Parser',
            ppm    => 'XML-Parser',
            yum    => 'XML::Parser',
            zypper => 'XML::Parser',
        },
    },
    {
        Module        => 'YAML::XS',
        Required      => 1,
        Comment       => 'Very important',
        InstTypes => {
            aptget => 'libyaml-libyaml-perl',
            gcpan  => 'YAML::XS',
            ppm    => 'YAML-XS',
            yum    => 'YAML::XS',
            zypper => 'YAML::XS',
        },
    },
);

# if we're on Windows we need some additional modules
if ( $^O eq 'MSWin32' ) {

    my @WindowsModules = (
        {
            Module        => 'Win32::Daemon',
            Required      => 1,
            Comment       => 'For running the OTRS Scheduler Service.',
            InstTypes => {
                ppm => 'Win32-Daemon',
            },
        },
        {
            Module        => 'Win32::Service',
            Required      => 1,
            Comment       => 'For running the OTRS Scheduler Service.',
            InstTypes => {
                ppm => 'Win32-Service',
            },
        },
    );
    push @NeededModules, @WindowsModules;
}

# try to determine module version number
my $Depends = 0;

for my $Module (@NeededModules) {
    _Check( $Module, $Depends, $NoColors );
}

if ($AllModules) {
    print "\nBundled modules:\n\n";

    my %PerlInfo = $EnvironmentObject->PerlInfoGet( BundledModules => 1, );

    for my $Module ( sort keys %{ $PerlInfo{Modules} } ) {
        _Check( { Module => $Module, Required => 1, }, $Depends, $NoColors );
    }
}

exit;

sub _Check {
    my ( $Module, $Depends, $NoColors ) = @_;

    # if we're on Windows we don't need to see Apache + mod_perl modules
    if ( $^O eq 'MSWin32' ) {
        return if $Module->{Module} =~ m{\A Apache }xms;
        return if $Module->{Module} =~ m{\A ModPerl }xms;
    }

    print '  ' x ( $Depends + 1 );
    print "o $Module->{Module}";
    my $Length = 33 - ( length( $Module->{Module} ) + ( $Depends * 2 ) );
    print '.' x $Length;

    my $Version = $EnvironmentObject->ModuleVersionGet( Module => $Module->{Module} );
    if ($Version) {

        # cleanup version number
        my $CleanedVersion = _VersionClean(
            Version => $Version,
        );

        my $ErrorMessage;

        # test if all module dependencies are installed by requiring the module
        ## no critic
        if ( !eval "require $Module->{Module}" ) {
            $ErrorMessage .= 'Not all prerequisites for this module correctly installed. ';
        }
        ## use critic

        if ( $Module->{NotSupported} ) {

            my $NotSupported = 0;
            ITEM:
            for my $Item ( @{ $Module->{NotSupported} } ) {

                # cleanup item version number
                my $ItemVersion = _VersionClean(
                    Version => $Item->{Version},
                );

                if ( $CleanedVersion == $ItemVersion ) {
                    $NotSupported = $Item->{Comment};
                    last ITEM;
                }
            }

            if ($NotSupported) {
                $ErrorMessage .= "Version $Version not supported! $NotSupported ";
            }
        }

        if ( $Module->{Version} ) {

            # cleanup item version number
            my $RequiredModuleVersion = _VersionClean(
                Version => $Module->{Version},
            );

            if ( $CleanedVersion < $RequiredModuleVersion ) {
                $ErrorMessage
                    .= "Version $Version installed but $Module->{Version} or higher is required! ";
            }
        }

        if ($ErrorMessage) {
            if ($NoColors) {
                print "FAILED! $ErrorMessage\n";
            }
            else {
                print color('red') . 'FAILED!' . color('reset') . " $ErrorMessage\n";
            }
        }
        else {
            if ($NoColors) {
                print "ok (v$Version)\n";
            }
            else {
                print color('green') . 'ok' . color('reset') . " (v$Version)\n";
            }
        }
    }
    else {
        my $Comment     = $Module->{Comment} ? ' - ' . $Module->{Comment} : '';
        my $Required    = $Module->{Required};
        my $Color       = 'yellow';

        # OS Install Command
        my $Install;
        my $PackageName;

        # returns the installation type e.g. ppm
        my $InstType = $DistToInstType{$OSDist};

        if ($InstType) {
            # gets the install command for installation type
            # e.g. ppm install %s
            # default is the cpan install command
            # e.g. cpan %s
            $Install = $InstTypeToCMD{ $InstType };
            # gets the target package
            # default is the cpan module name
            $PackageName = $Module->{InstTypes}->{ $InstType };
        }
        if (!$Install || !$PackageName) {
            $Install = $InstTypeToCMD{default};
            $PackageName = $Module->{Module};
        }

        # create example installation string for module
        $Install = "Use: '" . sprintf ($Install, $PackageName) . "'";

        if ($Required) {
            $Required = 'required';
            $Color    = 'red';
        }
        else {
            $Required = 'optional';
        }
        if ($NoColors) {
            print "Not installed! ($Required $Comment)\n";
        }
        else {
            print color($Color) . 'Not installed!' . color('reset') . " $Install ($Required$Comment)\n";
        }
    }

    if ( $Module->{Depends} ) {
        for my $ModuleSub ( @{ $Module->{Depends} } ) {
            _Check( $ModuleSub, $Depends + 1, $NoColors );
        }
    }

    return 1;
}

sub _VersionClean {
    my (%Param) = @_;

    return 0 if !$Param{Version};

    # replace all special characters with an dot
    $Param{Version} =~ s{ [_-] }{.}xmsg;

    my @VersionParts = split q{\.}, $Param{Version};

    my $CleanedVersion = '';
    for my $Count ( 0 .. 4 ) {
        $VersionParts[$Count] ||= 0;
        $CleanedVersion .= sprintf "%04d", $VersionParts[$Count];
    }

    return int $CleanedVersion;
}

sub _CheckActiveStatePerl {
    # checks if active state perl on windows is activated
    my $as = eval 'use Win32; return Win32::BuildNumber();';

    return $as ? 1 : 0;
}

exit 0;
