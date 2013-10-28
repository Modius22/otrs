# --
# Kernel/System/ConfigurationWizard/RootAccountPwdCheck.pm - check for root@localhost pass
# Copyright (C) 2001-2013 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ConfigurationWizard::RootAccountPwdCheck;

use strict;
use warnings;

use Kernel::System::Auth;
use Kernel::System::User;

=head1 NAME

Kernel::System::ConfigurationWizard::RootAccountPwdCheck - check module for RootAccountPwdCheck

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you call this module only from L<Kernel::System::ConfigurationWizard>
in the WizardModuleListGet() function.

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (
        qw(MainObject ConfigObject LogObject EncodeObject TimeObject GroupObject DBObject)
        )
    {
        $Self->{$Needed} = $Param{$Needed} || die "Got no $Needed!";
    }

    return $Self;
}

=item RunRequiredCheck()

Returns true if the module requires immediate action.

   my $Result = $RootAccountPdwCheckModule->RunRequiredCheck();

=cut

sub RunRequiredCheck {
    my ( $Self, %Param ) = @_;

    # create user object
    my $UserObject = Kernel::System::User->new( %{$Self} );

    # test if there is a valid account 'root@localhost'
    my %UserList = $UserObject->UserList(
        Valid => 1,
    );

    # no action needed if there is no such user
    return if !$UserList{'root@localhost'};

    # create auth objects
    my $AuthObject = Kernel::System::Auth->new(
        %{$Self},
        UserObject => $UserObject,
    );

    # auth as root@localhost; action is needed if pw=root
    return if !$AuthObject->Auth( User => 'root@localhost', Pw => 'root' );

    return 1;
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the OTRS project (L<http://otrs.org/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut
