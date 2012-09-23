package Narsil::Authentication;
use Exporter qw< import >;
use Dancer ':syntax';
use Dancer::Plugin::FlashNote qw< flash >;

our @EXPORT = qw< setup_authentication simple_authorization >;

sub setup_authentication {
   my %defaults = (
      authentication_callback => sub { return 1 },
      authorization_callback => \&simple_authorization,
      logout_callback => sub { return 0  },
      home_route => '/',
      login_route => '/login',
      postlogin_default_route => '/',
      logout_route => '/logout',
      postlogout_default_route => '/',
   );
   my %args = (%defaults, @_);

   hook before => sub {
      my $authorization =
         $args{authorization_callback}->(request(), session('user'));
      if ((! $authorization) || ($authorization eq 'needs_authentication')) {
         my $path = request()->path_info();
         flash warning => needs_authentication => $path;
         session requested_path => $path;
         request()->path_info($args{home_route});
      }
      elsif ($authorization eq 'unauthorized') {
         flash error => unauthorized => request()->path_info();
         request()->path_info($args{home_route});
      }
      return;
   };

   post $args{login_route} => sub {
      Dancer::warning "here I go in the login route";
      my $user = $args{authentication_callback}->(request());
      session user => $user;
      flash $user ? (qw< info login >) : (qw< error invalid_login >);

      my $path = param('uri') // session('requested_path');
      session requested_path => undef;
      Dancer::warning "redirecting to $path";
      return redirect $path // $args{postlogin_default_route};
   };

   any [qw< get post >] => $args{logout_route} => sub {
      $args{logout_callback}->();
      session user => undef;
      flash info => 'logout';
      return redirect $args{postlogout_default_route};
   };
}

sub simple_authorization {
   my ($request, $user) = @_;
   my $path = $request->path_info();
   return 'public'
      if $path =~ m{(?mxs: ^ (?: /? | /public/.* | /login | /logout) $)}mxs;
   return 'authorized'
      if session 'user';
   return 'needs_authentication';
}

true;
