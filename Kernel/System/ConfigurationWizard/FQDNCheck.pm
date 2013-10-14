# --
# Kernel/System/ConfigurationWizard/FQDNCheck.pm - check for default fqdn
# Copyright (C) 2001-2013 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ConfigurationWizard::FQDNCheck;

use strict;
use warnings;

=head1 NAME

Kernel::System::ConfigurationWizard::FQDNCheck - check module for FQDNCheck

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

=item Check()

Returns true if the module requires immediate action.

   my $Result = $FQDNCheckModule->Check();

=cut

sub Check {
    my ( $Self, %Param ) = @_;

    # test if FQDN equals default value
    my $FQDN = $Self->{ConfigObject}->Get('FQDN');
    return 1 if $FQDN eq 'yourhost.example.com';

    return;
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the OTRS project (L<http://otrs.org/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut
