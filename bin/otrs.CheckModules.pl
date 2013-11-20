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

use Kernel::System::VariableCheck qw(:all);

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
    # [InstType] => {
    #    CMD       => '[cmd to install module]',
    #    UseModule => 1/0,
    # }
    # Set UseModule to 1 if you want to use the
    # cpan module name of the package as replace string.
    # e.g. yum install "perl(Date::Format)"
    # If you set it 0 it will use the name
    # for the InstType of the module
    # e.g. apt-get install -y libtimedate-perl
    # and as fallback the default cpan install command
    # e.g. cpan DBD::Oracle
    aptget => {
        CMD       => 'apt-get install -y %s',
        UseModule => 0,
    },
    ppm => {
        CMD       => 'ppm install %s',
        UseModule => 0,
    },
    gcpan => {
        CMD       => 'g-cpan -i %s',
        UseModule => 1,
    },
    yum => {
        CMD       => 'yum install "perl(%s)"',
        UseModule => 1,
    },
    zypper => {
        CMD       => 'zypper install "perl(%s)"',
        UseModule => 1,
    },
    default => {
        CMD => 'cpan %s',
    },
);

#gentoo, solaris, oracle
our %DistToInstType = (

    # apt-get
    debian => 'aptget',
    ubuntu => 'aptget',

    # gcpan
    gentoo => 'gcpan',

    # yum
    centos => 'yum',
    fedora => 'yum',
    rhel   => 'yum',
    redhat => 'yum',

    # zypper
    suse => 'zypper',

    # ppm
    win32as => 'ppm',
);

my %OSData = $EnvironmentObject->OSInfoGet();
our $OSDist = $OSData{Distribution};

# set win32as if active state perl is installed on windows.
# for windows installations without active state perl we use the default.
if ( _CheckActiveStatePerl() ) {
    $OSDist = 'win32as';
}

my $AllModules;
my $PackageList;
GetOptions( all => \$AllModules, list => \$PackageList );

my $Options = shift || '';
my $NoColors;

if ( $ENV{nocolors} || $Options =~ m{\A nocolors}msxi ) {
    $NoColors = 1;
}

# config
my @NeededModules = (
    {
        Module    => 'Crypt::Eksblowfish::Bcrypt',
        Required  => 0,
        Comment   => 'For strong password hashing.',
        InstTypes => {
            aptget => 'libcrypt-eksblowfish-perl',
            ppm    => 'Crypt-Eksblowfish',
            zypper => undef,
        },
    },
    {
        Module    => 'Crypt::SSLeay',
        Required  => 0,
        Comment   => 'Required for Generic Interface SOAP SSL connections.',
        InstTypes => {
            aptget => 'libcrypt-ssleay-perl',
            ppm    => 'Crypt-SSLeay',
        },
    },
    {
        Module    => 'Date::Format',
        Required  => 1,
        InstTypes => {
            aptget => 'libtimedate-perl',
            ppm    => 'TimeDate',
        },
    },
    {
        Module    => 'DBI',
        Required  => 1,
        InstTypes => {
            aptget => 'libdbi-perl',
            ppm    => 'DBI',
        },
    },
    {
        Module    => 'DBD::mysql',
        Required  => 0,
        Comment   => 'Required to connect to a MySQL database.',
        InstTypes => {
            aptget => 'libdbi-mysql-perl',
            ppm    => 'DBD-mysql',
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
        Comment   => 'Required to connect to a MS-SQL database.',
        InstTypes => {
            aptget => 'libdb-odbc-perl',
            ppm    => 'DBD-ODBC',
            yum    => undef,
        },
    },
    {
        Module    => 'DBD::Oracle',
        Required  => 0,
        Comment   => 'Required to connect to a Oracle database.',
        InstTypes => {
            aptget => 'libdb-odbc-perl',
            ppm    => 'DBD-Oracle',
            yum    => undef,
        },
    },
    {
        Module    => 'DBD::Pg',
        Required  => 0,
        Comment   => 'Required to connect to a PostgreSQL database.',
        InstTypes => {
            aptget => 'libdb-pg-perl',
            ppm    => 'DBD-Pg',
        },
    },
    {
        Module    => 'Encode::HanExtra',
        Version   => '0.23',
        Required  => 0,
        Comment   => 'Required to handle mails with several Chinese character sets.',
        InstTypes => {
            aptget => 'libencode-hanextra-perl',
        },
    },
    {
        Module    => 'GD',
        Required  => 0,
        Comment   => 'Required for stats.',
        InstTypes => {
            aptget => 'libgd-gd2-perl',
            ppm    => 'GD',
        },
        Depends => [
            {
                Module    => 'GD::Text',
                Required  => 0,
                Comment   => 'Required for stats.',
                InstTypes => {
                    aptget => 'libgd-text-perl',
                    ppm    => 'GDTextUtil',
                    }
            },
            {
                Module    => 'GD::Graph',
                Required  => 0,
                Comment   => 'Required for stats.',
                InstTypes => {
                    aptget => 'libgd-graph-perl',
                    ppm    => 'GDGraph',
                },
            },
        ],
    },
    {
        Module    => 'IO::Socket::SSL',
        Required  => 0,
        Comment   => 'Required for SSL connections to web and mail servers.',
        InstTypes => {
            aptget => 'libio-socket-ssl-perl',
            ppm    => 'IO-Socket-SSL',
        },
    },
    {
        Module    => 'JSON::XS',
        Required  => 0,
        Comment   => 'Recommended for faster AJAX/JavaScript handling.',
        InstTypes => {
            aptget => 'libjson-xs-perl',
            ppm    => 'JSON-XS',
        },
    },
    {
        Module    => 'LWP::UserAgent',
        Required  => 1,
        InstTypes => {
            aptget => 'libwww-perl',
            ppm    => 'libwww-perl',
        },
    },
    {
        Module    => 'Mail::IMAPClient',
        Version   => '3.22',
        Comment   => 'Required for IMAP TLS connections.',
        Required  => 0,
        InstTypes => {
            aptget => 'libmail-imapclient-perl',
            ppm    => 'Mail-IMAPClient',
        },
        Depends => [
            {
                Module    => 'IO::Socket::SSL',
                Required  => 0,
                Comment   => 'Required for IMAP TLS connections.',
                InstTypes => {
                    aptget => 'libio-socket-ssl-perl',
                    ppm    => 'IO-Socket-SSL',
                },
            },
        ],
    },
    {
        Module    => 'ModPerl::Util',
        Required  => 0,
        Comment   => 'Improves Performance on Apache webservers dramatically.',
        InstTypes => {
            aptget => 'libapache2-mod-perl2',
        },
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
            ppm    => 'Net-DNS',
        },
    },
    {
        Module    => 'Net::LDAP',
        Required  => 0,
        Comment   => 'Required for directory authentication.',
        InstTypes => {
            aptget => 'libnet-ldap-perl',
            ppm    => 'Net-LDAP',
        },
    },
    {
        Module    => 'Net::SSL',
        Required  => 0,
        Comment   => 'Required for Generic Interface SOAP SSL connections.',
        InstTypes => {
            aptget => 'libcrypt-ssleay-perl',
            ppm    => 'Crypt-SSLeay',
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
            ppm    => 'PDF-API2',
        },
    },
    {
        Module    => 'Text::CSV_XS',
        Required  => 0,
        Comment   => 'Recommended for faster CSV handling.',
        InstTypes => {
            aptget => 'libtext-csv-xs-perl',
            ppm    => 'Text-CSV_XS',
        },
    },
    {
        Module    => 'Time::HiRes',
        Required  => 1,
        Comment   => 'Required for high resolution timestamps.',
        InstTypes => {
            aptget => 'perl',
            ppm    => 'Time-HiRes',
        },
    },
    {
        Module    => 'XML::Parser',
        Required  => 0,
        Comment   => 'Recommended for faster xml handling.',
        InstTypes => {
            aptget => 'libxml-parser-perl',
            ppm    => 'XML-Parser',
        },
    },
    {
        Module    => 'YAML::XS',
        Required  => 1,
        Comment   => 'Very important',
        InstTypes => {
            aptget => 'libyaml-libyaml-perl',
            ppm    => 'YAML-XS',
        },
    },
);

# if we're on Windows we need some additional modules
if ( $^O eq 'MSWin32' ) {

    my @WindowsModules = (
        {
            Module    => 'Win32::Daemon',
            Required  => 1,
            Comment   => 'For running the OTRS Scheduler Service.',
            InstTypes => {
                ppm => 'Win32-Daemon',
            },
        },
        {
            Module    => 'Win32::Service',
            Required  => 1,
            Comment   => 'For running the OTRS Scheduler Service.',
            InstTypes => {
                ppm => 'Win32-Service',
            },
        },
    );
    push @NeededModules, @WindowsModules;
}


if ($PackageList) {
    my %PackageList = _PackageList(\@NeededModules);

    if ( IsArrayRefWithData( $PackageList{Packages} ) ) {
        printf join(' ', @{ $PackageList{Packages} } ) . "\n";
    }
}
else {
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
}

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
        my $Comment  = $Module->{Comment} ? ' - ' . $Module->{Comment} : '';
        my $Required = $Module->{Required};
        my $Color    = 'yellow';

        # OS Install Command
        my %InstallCommand = _GetInstallCommand($Module);

        # create example installation string for module
        my $InstallText;
        if ( IsHashRefWithData(\%InstallCommand) ) {
            $InstallText = " Use: '" . sprintf( $InstallCommand{CMD}, $InstallCommand{Package} ) . "'";
        }

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
            print color($Color)
                . 'Not installed!'
                . color('reset')
                . "$InstallText ($Required$Comment)\n";
        }
    }

    if ( $Module->{Depends} ) {
        for my $ModuleSub ( @{ $Module->{Depends} } ) {
            _Check( $ModuleSub, $Depends + 1, $NoColors );
        }
    }

    return 1;
}

sub _PackageList {
    my ( $PackageList ) = @_;

    my $CMD;
    my @Packages;

    # if we're on Windows we don't need to see Apache + mod_perl modules
    for my $Module ( @{$PackageList} ) {
        if ( $^O eq 'MSWin32' ) {
            return if $Module->{Module} =~ m{\A Apache }xms;
            return if $Module->{Module} =~ m{\A ModPerl }xms;
        }

        my $Version = $EnvironmentObject->ModuleVersionGet( Module => $Module->{Module} );
        if (!$Version) {
            my %InstallCommand = _GetInstallCommand($Module);

            if ( $Module->{Depends} ) {
                for my $ModuleSub ( @{ $Module->{Depends} } ) {
                    my %InstallCommandSub = _GetInstallCommand( $ModuleSub );
                    push @Packages, $InstallCommandSub{Package};
                }
            }

            $CMD = $InstallCommand{CMD};
            push @Packages, $InstallCommand{Package};
        }
    }

    return (
        CMD      => $CMD,
        Packages => \@Packages,
    );
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

sub _GetInstallCommand {
    my ($Module) = @_;
    my $CMD;
    my $Package;

    # returns the installation type e.g. ppm
    my $InstType = $DistToInstType{$OSDist};
    my $OuputInstall = 1;

    if ($InstType) {

        # gets the install command for installation type
        # e.g. ppm install %s
        # default is the cpan install command
        # e.g. cpan %s
        $CMD = $InstTypeToCMD{$InstType}->{CMD};

        # gets the target package
        if ( exists $Module->{InstTypes}->{$InstType} && !defined $Module->{InstTypes}->{$InstType} ) {
            # if we a hash key for the installation type but a undefined value
            # then we prevent the output for the installation command
            $OuputInstall = 0;
        }
        elsif ( $InstTypeToCMD{$InstType}->{UseModule} ) {
            # default is the cpan module name
            $Package = $Module->{Module};
        }
        else {
            # if the package name is defined for the installation type
            # e.g. ppm then we use this as package name
            $Package = $Module->{InstTypes}->{$InstType};
        }
    }

    return if !$OuputInstall;

    if ( !$CMD || !$Package ) {
        $CMD     = $InstTypeToCMD{default}->{CMD};
        $Package = $Module->{Module};
    }

    return (
        'CMD'     => $CMD,
        'Package' => $Package,
    );
}

sub _CheckActiveStatePerl {

    # checks if active state perl on windows is activated
    ## no critic
    my $ActiveStatePerl = eval 'use Win32; return Win32::BuildNumber();';
    ## use critic

    return $ActiveStatePerl ? 1 : 0;
}

exit 0;
