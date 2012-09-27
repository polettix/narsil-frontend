package Narsil::Frontend;
use JSON qw< encode_json decode_json >;
use Dancer ':syntax';
use Dancer::Plugin::FlashNote qw< flash >;
use 5.012;
use LWP::UserAgent;
use URI;
use Try::Tiny;
use Storable qw< dclone >;

my %layout_name_for = (
   normal => 'main',
   mobile => 'mobile',
);

BEGIN {
   unshift @INC, qw< /home/poletti/sviluppo/perl/narsil/core/lib >;
   #die if exists $ENV{DOTCLOUD_ENVIRONMENT};
   unshift @INC, qw< /home/poletti/sviluppo/perl/narsil/core/lib >
     unless exists $ENV{DOTCLOUD_ENVIRONMENT};
}

use Narsil::Authentication;
setup_authentication(
   authentication_callback => \&authenticate,
   (
      exists($ENV{DOTCLOUD_ENVIRONMENT}) ? () : (
         authorization_callback => sub {
            warning "\n\n\n\n in authorization callback \n\n\n\n";
            session('user') || session(user => {username => 'polettix'});
         }
      )
   ),
);

sub user { return session('user') }

sub agent {
   state $agent = LWP::UserAgent->new(timeout => 5);
   return $agent;
}

sub rest_uri_for {
   my ($path, $params) = @_;
   my $uri = URI->new(config()->{'narsil-ws'});
   $uri->path($path);
   if ($params) {
      $uri->query_form($params);
      $params = undef;
   }
   warning "URI: $uri";
   return $uri;
} ## end sub rest_uri_for

sub rest_call {
   my ($method, $path, $params) = @_;
   my $is_get = uc($method) eq 'GET';
   my $uri = rest_uri_for($path, ($is_get ? $params : undef));
   $params = undef if $is_get;
   my $response = agent()->$method($uri, $params ? $params : ());
   my $retval;
   try {
      $retval = decode_json($response->content());
   }
   catch {
      $retval = {error => $_};
   };
   return $retval;
} ## end sub rest_call

sub authenticate {
   my ($request) = @_;
   my $params = $request->params();
   my ($username, $password) = @{$params}{qw< username password >};
   state %password_for;
   %password_for = (
      polettix => 'ciao',
      silvia   => 'atutti',
      playera  => 'x',
      playerb  => 'x',
   ) unless scalar keys %password_for;
   return {username => $username}
     if exists($password_for{$username})
        && (  ($password_for{$username} eq $password)
           || ($password eq 'x'));
   return;
} ## end sub authenticate

{
   my $template_sub = \&template;
   no strict 'refs';
   no warnings 'redefine';
   *{'template'} = sub {
      push @_, {} while @_ < 3;
      $_[2]->{layout} = session('layout') // 'mobile'
         unless exists($_[2]->{layout});
      my $layout = $_[2]->{layout};

      my $te = engine 'template';
      my $candidate = "$layout/$_[0]";
      my $path = $te->view($candidate);
      warning "candidate: $candidate";
      warning "path: " . ($path // 'undef');
      splice @_, 0, 1, $candidate if defined($path) && -r $path;

      goto $template_sub;
   };
}


hook before_template => sub {
   my $tokens = shift;
   $tokens->{development} = !exists $ENV{DOTCLOUD_ENVIRONMENT};
};

get '/' => sub {
   my $matches = get_matches_for(user(), 'active');
   my ($waiting, $availables) = get_gathering_matches(user());
   my $games = get_games();
   my $users = get_users();
   return template 'index',
     {
      matches    => $matches,
      availables => $availables,
      waiting    => $waiting,
      string     => to_json($waiting),
      games      => $games,
      users      => $users
     };
};

get '/matches/:phase' => sub {
   my $stuff = get_matches_for(user(), param('phase'));
   template 'matches', {string => encode_json($stuff), matches => $stuff};
};

sub get_users {
   return rest_call(get => '/users');
}

sub get_games {
   return rest_call(get => '/games');
}

sub get_gathering_matches_old {
   return rest_call(get => '/matches/gathering');
}

sub get_available_matches {
   my ($user) = @_;
   my $userid = $user->{username};
   my $stuff  = rest_call(
      get => "/matches/gathering",
      {user => $userid,}
   );
   for my $match (@{$stuff->{matches}}) {
      ($match->{id} = $match->{uri}) =~ s{.*/}{}mxs;
      $match->{opponents} =
        [grep { $_->[0] ne $userid } @{$match->{participants}}];
   }
   return $stuff;
} ## end sub get_available_matches

sub get_gathering_matches {
   my ($user) = @_;
   my $userid = $user->{username};
   my $stuff  = rest_call(
      get => "/matches/gathering",
      {user => $userid,}
   );
   my $matches   = delete $stuff->{matches};
   my $waiting   = dclone($stuff);
   my $available = dclone($stuff);
   for my $match (@$matches) {
      ($match->{id} = $match->{uri}) =~ s{.*/}{}mxs;
      if (grep { defined($userid) && ($_->[0] eq $userid) }
         @{$match->{participants}})
      {
         $match->{is_participant} = 1;
         push @{$waiting->{matches}}, $match;
      } ## end if (grep { defined($userid...
      else {
         $match->{opponents} =
           [grep { !(defined($userid) && ($_->[0] eq $userid)) }
              @{$match->{participants}}];
         $match->{is_participant} = 0;
         push @{$available->{matches}}, $match;
      } ## end else [ if (grep { defined($userid...
   } ## end for my $match (@$matches)
   return ($waiting, $available);
} ## end sub get_gathering_matches

sub get_matches_for {
   my ($user, $phase) = @_;
   return {} unless defined $user;
   my $userid = $user->{username};
   $phase //= 'active';
   my $stuff = rest_call(
      get => "/user/matches/$userid",
      {
         phase => $phase,
         user  => $userid,
      }
   );
   for my $match (@{$stuff->{matches}}) {
      ($match->{id} = $match->{uri}) =~ s{.*/}{}mxs;
      $match->{opponents} =
        [grep { $_->[0] ne $userid } @{$match->{participants}}];
      $match->{movers} = [map { $_->[0] } @{$match->{movers}}];
   } ## end for my $match (@{$stuff...
   return $stuff;
} ## end sub get_matches_for

get '/match/:id' => sub {
   my $userid  = user()->{username};
   my $matchid = param('id');
   my $match   = rest_call(
      get => "/match/$matchid",
      {user => $userid},
   );
   (my $game = $match->{game}) =~ s{.*/}{}mxs;
   my $template = "games/$game";
   try {
      my $class = "Narsil::Frontend::$game";
      (my $package = $class . '.pm') =~ s{(?: :: | ')}{/}gmxs;
      require $package;
      ($match, $template) = $class->adapt($match, $userid);
   } ## end try
   catch {
      warning $_;
   };
   template match => {string => to_json($match), subtemplate => $template , %$match};
};

post '/match' => sub {
   my $gameid = param('game');
   my $match  = rest_call(
      post => '/match',
      {
         user => user()->{username},
         game => rest_uri_for("/game/$gameid"),
      },
   );
   (my $id = $match->{uri}) =~ s{.*/}{}mxs;
   try {
      forward "/match/joins/$id";
   }
   catch {
      warning "caught error during forward: $_";
   };
   return redirect request . uri_for('/');
};

post '/match/joins/:id' => sub {
   my $userid  = user()->{username};
   my $matchid = param('id');
   my $join    = rest_call(
      post => "/match/joins/$matchid",
      {user => $userid},
   );
   if ($join->{phase} eq 'rejected') {
      flash error => join_rejected => $join->{message};
   }
   elsif ($join->{phase} eq 'accepted') {
      flash info => 'join_accepted';
   }
   else {
      flash warning => 'join_pending';
   }
   return redirect '/';
};

post '/move' => sub {
   my $matchid = param('match');
   my $userid  = user()->{username};
   my $match   = rest_call(
      get => "/match/$matchid",
      {user => $userid},
   );

   my $move;
   try {
      (my $game = $match->{game}) =~ s{.*/}{}mxs;
      my $class = "Narsil::Frontend::$game";
      (my $package = $class . '.pm') =~ s{(?: :: | ')}{/}gmxs;
      require $package;
      my @instructions =
        $class->build_move($match, $userid, scalar params());
      for my $instruction (@instructions) {
         my $move = rest_call(
            post => "/match/moves/$matchid",
            {
               user => $userid,
               move => encode_json($instruction),
            },
         );
      } ## end for my $instruction (@instructions)
   } ## end try
   catch {
      warning ">>>>>> $_";
   };

   #flash info => debug => to_json($move);
   return redirect "/match/$matchid";
};

get '/game/:id' => sub {
   my $gameid = param('id');
};

get '/games' => sub {
   my $games = get_games();
   return template 'games', {games => $games,};

};

post '/layout' => sub {
   session layout => $layout_name_for{param('layout')} // 'main';
   flash info => 'layout_set';
   return redirect request()->referer();
};

true;
