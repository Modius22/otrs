# --
# Kernel/System/ConfigurationWizard/RegistrationCheck.pm - check for system registration
# Copyright (C) 2001-2013 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ConfigurationWizard::RegistrationCheck;

use strict;
use warnings;

use Kernel::System::Registration;

=head1 NAME

Kernel::System::ConfigurationWizard::RegistrationCheck - check module for RegistrationCheck

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
        qw(MainObject ConfigObject LogObject EncodeObject TimeObject DBObject)
        )
    {
        $Self->{$Needed} = $Param{$Needed} || die "Got no $Needed!";
    }

    return $Self;
}

=item RunRequiredCheck()

Returns true if the module requires immediate action.

   my $Result = $RegistrationCheckModule->RunRequiredCheck();

=cut

sub RunRequiredCheck {
    my ( $Self, %Param ) = @_;

    # create user object
    my $RegistrationObject = Kernel::System::Registration->new( %{$Self} );

    my %RegistrationData = $RegistrationObject->RegistrationDataGet();

    return if %RegistrationData;

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
