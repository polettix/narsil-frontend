package Narsil::Frontend::battleship;

use strict;
use warnings;
use Carp;
use English qw< -no_match_vars >;
use Narsil::Game::BattleShip::Status;

sub adapt {
   my ($package, $match, $user) = @_;
   my $status = Narsil::Game::BattleShip::Status->new($match->{status});

   $status->field_size_y();
   my %retval = (%$status, match => $match, user => $user);

   ($retval{matchid} = $match->{uri}) =~ s{.*/}{}mxs;
   my @players = map { $_->[0] } @{$match->{participants}};
   push @players, '*undef' while scalar(@players) < 2;
   if (grep { $_ eq $user } @players) {    # user participates
      ($retval{upper}) = grep { $_ ne $user } @players;
      $retval{lower} = $user;
   }
   else {
      @retval{qw< upper lower >} = @players;
   }

   my @movers = map { $_->[0] } @{$match->{movers}};
   $retval{movers} = \@movers;
   $retval{active_player} = $movers[0] if @movers == 1;
   $retval{player_is_active} = grep { $_ eq $user } @movers;
   delete $retval{active_player} if $match->{phase} eq 'terminated';

   $retval{maxx} = $retval{field_size_x} - 1;
   $retval{maxy} = $retval{field_size_y} - 1;

   $retval{expanded_field} = \my %field;
   my %in_last_moves = map { $_ => 1 } @{$retval{last_moves}{moves} // []};
   $retval{in_last_moves} = \%in_last_moves;
   for my $player (@players) {
      push @{$field{$player}},
        [map { {status => 'blank', in_last => 0,} }
           1 .. $retval{field_size_x}]
        for 1 .. $retval{field_size_y};
   } ## end for my $player (@players)
   while (my ($position, $value) = each %{$status->{field}}) {
      my ($player, $x, $y) = split /:/, $position;
      $field{$player}[$y][$x]{status}  = $value;
      $field{$player}[$y][$x]{in_last} = $in_last_moves{$position};
   }
   while (my ($type, $boat) = each %{$status->{boats}}) {
      my ($bid, $orient) = @{$boat}{qw< id orientation >};
      while (my ($position, $partid) = each %{$boat->{intact}}) {
         my ($x, $y) = split /:/, $position;
         $field{$user}[$y][$x]{status} = "boat-$bid-$orient-p$partid";
      }
   } ## end while (my ($type, $boat) ...

   if ($status->is_setup()) {
      my %residual = %{$status->{allowed_boats}};
      delete $residual{$_} for keys %{$status->{boats}};
      my @residual = map {
         ("boat-$_-south", "boat-$_-east")
      } keys %residual;
      $retval{residual} = \@residual;
      return ({string => Dancer::to_json(\%retval), %retval},
         'games/battleship/setup.tt');
   }

   return (\%retval, 'games/battleship/play.tt');
} ## end sub adapt

sub build_move {
   my ($package, $match, $user, $params) = @_;
   my $action = $params->{action};
   my @retval = { action => $action, position => $params->{position}};
   if ($action eq 'add-boat') {
      (undef, @{$retval[0]}{qw< id orientation >}) = split /-/, $params->{boat};
      push @retval, { action => 'setup-complete' };
   }
   return @retval;
}

1;
__END__

