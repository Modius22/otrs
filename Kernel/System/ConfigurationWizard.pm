# --
# Kernel/System/ConfigurationWizard.pm - implements wizard functions
# Copyright (C) 2001-2013 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ConfigurationWizard;

use strict;
use warnings;

use Kernel::System::Group;

=head1 NAME

Kernel::System::ConfigurationWizard - wizard module lib

=head1 SYNOPSIS

All wizard module backend functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object

    use Kernel::Config;
    use Kernel::System::Log;
    use Kernel::System::Main;
    use Kernel::System::DB;
    use Kernel::System::ConfigurationWizard;

    my $ConfigObject = Kernel::Config->new();
    my $LogObject = Kernel::System::Log->new(
        ConfigObject => $ConfigObject,
    );
    my $MainObject = Kernel::System::Main->new(
        ConfigObject => $ConfigObject,
        LogObject    => $LogObject,
    );
    my $DBObject = Kernel::System::DB->new(
        ConfigObject => $ConfigObject,
        LogObject    => $LogObject,
        MainObject   => $MainObject,
    );
    my $ConfigurationWizardObject = Kernel::System::ConfigurationWizard->new(
        ConfigObject => $ConfigObject,
        LogObject    => $LogObject,
        DBObject     => $DBObject,
    );

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Object (qw(DBObject ConfigObject LogObject MainObject TimeObject EncodeObject)) {
        $Self->{$Object} = $Param{$Object} || die "Got no $Object!";
    }

    $Self->{GroupObject} = Kernel::System::Group->new( %{$Self} );

    return $Self;
}

=item WizardModuleListGet()

this function returns a list of all modules that are available
for the current user.

If you pass the parameter ActionNeeded, it will return only
modules that are availble AND have an action pending

    my %WizardModules = $ConfigurationWizardObject->WizardModuleListGet(
        UserID => 1,
    );

    my %WizardModules = $ConfigurationWizardObject->WizardModuleListGet(
        ActionNeeded => 1,
        UserID       => 1,
    );

=cut

sub WizardModuleListGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{UserID} ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => 'Need UserID!',
        );
        return;
    }

    my $Config = $Self->{ConfigObject}->Get('ConfigurationWizard');
    if ( !$Config ) {
        return ();
    }

    # get groups of user
    my %UserGroups = reverse $Self->{GroupObject}->GroupMemberList(
        UserID => $Param{UserID},
        Type   => 'rw',
        Result => 'HASH',
    );

    my %Backends;
    BACKEND:
    for my $Name ( sort keys %{$Config} ) {

        # all backends without group should be added
        if ( !$Config->{$Name}->{Groups} ) {
            $Backends{$Name} = 1;
            next BACKEND;
        }

        # check if user is in one of the permission groups
        GROUP:
        for my $Group ( @{ $Config->{$Name}->{Groups} } ) {

            # if user does not have this group, skip
            next GROUP if !$UserGroups{$Group};

            # otherwise, allow backend
            $Backends{$Name} = 1;
            next BACKEND;
        }
    }

    # if requested, check if the module requires immediate action
    if ( $Param{ActionNeeded} ) {

        ACTIONCHECK:
        for my $ActionCheck ( sort keys %Backends ) {

            # create wizard object
            my $GenericModule = $Config->{$ActionCheck}->{Module};
            if ( !$Self->{MainObject}->Require($GenericModule) ) {
                $Self->{LogObject}->Log(
                    Priority => 'error',
                    Message  => "Can't load wizard module '$GenericModule'!",
                );
                delete $Backends{$ActionCheck};
                next ACTIONCHECK;
            }

            # test if action is needed
            $Self->{BackendObject} = $GenericModule->new( %{$Self} );
            my $ActionNeeded = $Self->{BackendObject}->Check();

            # keep check if action is needed
            next ACTIONCHECK if $ActionNeeded;

            delete $Backends{$ActionCheck};
        }
    }

    return %Backends;
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the OTRS project (L<http://otrs.org/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut
