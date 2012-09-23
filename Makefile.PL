
use strict;
use warnings;

use 5.008_000;

use ExtUtils::MakeMaker 6.30;



my %WriteMakefileArgs = (
  "ABSTRACT" => "[ una breve descrizione del programma ]",
  "AUTHOR" => "Flavio Poletti <polettix\@cpan.org>",
  "BUILD_REQUIRES" => {},
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => "6.30"
  },
  "DISTNAME" => "Narsil-FrontEnd",
  "EXE_FILES" => [
    "bin/app.pl"
  ],
  "LICENSE" => "artistic_2",
  "NAME" => "Narsil-FrontEnd",
  "PREREQ_PM" => {
   'Test::More' => 0,
   'YAML' => 0,
   'Dancer' => 0,
   'Dancer::Plugin::FlashNote' => '1.0.4',
   'Plack::Request' => 0,
   'Template' => 0,
   'JSON' => 0,
   'Redis' => 0,
   'Path::Class' => 0,
   'Digest::MD5' => 0,
   'LWP::UserAgent' => 0,
   'Moo' => 0,
   'Dancer::Session::Storable' => 0,
  },
  "VERSION" => "0.1.0",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.56) } ) {
  my $br = delete $WriteMakefileArgs{BUILD_REQUIRES};
  my $pp = $WriteMakefileArgs{PREREQ_PM};
  for my $mod ( keys %$br ) {
    if ( exists $pp->{$mod} ) {
      $pp->{$mod} = $br->{$mod} if $br->{$mod} > $pp->{$mod};
    }
    else {
      $pp->{$mod} = $br->{$mod};
    }
  }
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



