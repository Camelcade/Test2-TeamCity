requires "Exporter" => "0";
requires "File::Temp" => "0";
requires "List::Util" => "1.33";
requires "Path::Class" => "0";
requires "TeamCity::Message" => "0.02";
requires "Term::ANSIColor" => "0";
requires "Test2" => "1.302085";
requires "Test2::API" => "1.302085";
requires "Test2::Event" => "0";
requires "Test2::Formatter" => "0";
requires "Test2::Util::HashBase" => "0";
requires "autodie" => "0";
requires "parent" => "0";
requires "strict" => "0";
requires "warnings" => "0";

on 'test' => sub {
  requires "App::Yath" => "0";
  requires "ExtUtils::MakeMaker" => "0";
  requires "File::Basename" => "0";
  requires "File::Spec" => "0";
  requires "File::Spec::Functions" => "0";
  requires "FindBin" => "0";
  requires "IPC::Run3" => "0";
  requires "Path::Class::Rule" => "0";
  requires "Test2::Bundle::Extended" => "0";
  requires "Test2::Require::Module" => "0";
  requires "Test::Class::Moose" => "0.80";
  requires "Test::Exception" => "0.43";
  requires "Test::More" => "1.302015";
  requires "Time::HiRes" => "0";
  requires "base" => "0";
  requires "lib" => "0";
};

on 'test' => sub {
  recommends "CPAN::Meta" => "2.120900";
};

on 'configure' => sub {
  requires "ExtUtils::MakeMaker" => "0";
};

on 'develop' => sub {
  requires "Code::TidyAll::Plugin::Test::Vars" => "0.02";
  requires "File::Spec" => "0";
  requires "IO::Handle" => "0";
  requires "IPC::Open3" => "0";
  requires "Parallel::ForkManager" => "1.19";
  requires "Perl::Critic" => "1.126";
  requires "Perl::Tidy" => "20160302";
  requires "Pod::Coverage::TrustPod" => "0";
  requires "Pod::Wordlist" => "0";
  requires "Test::CPAN::Changes" => "0.19";
  requires "Test::CPAN::Meta::JSON" => "0.16";
  requires "Test::Code::TidyAll" => "0.50";
  requires "Test::EOL" => "0";
  requires "Test::Mojibake" => "0";
  requires "Test::More" => "0.96";
  requires "Test::NoTabs" => "0";
  requires "Test::Pod" => "1.41";
  requires "Test::Pod::Coverage" => "1.08";
  requires "Test::Portability::Files" => "0";
  requires "Test::Spelling" => "0.12";
  requires "Test::Synopsis" => "0";
  requires "Test::Vars" => "0.009";
  requires "Test::Version" => "2.05";
  requires "blib" => "1.01";
  requires "perl" => "5.006";
};
