# --
# ConfigurationWizard.t - unittests for configuration wizard
# Copyright (C) 2001-2013 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars qw($Self);

use Kernel::System::ConfigurationWizard;

# check needed objects
for my $Object (qw(ConfigObject DBObject LogObject TimeObject MainObject EncodeObject)) {
    die "Got no $Object!" if !$Self->{$Object};
}

my $ConfigurationWizardObject = Kernel::System::ConfigurationWizard->new( %{$Self} );

my %List = $ConfigurationWizardObject->WizardModuleListGet(
    UserID => 1,
);

use Data::Dumper;
warn Dumper( \%List );

my $Count = scalar keys %List;

$Self->Is(
    $Count,
    1,
    'There is one check.'
);

%List = $ConfigurationWizardObject->WizardModuleListGet(
    ActionNeeded => 1,
    UserID       => 1,
);

warn Dumper( \%List );

1;
