package Java::JVM::Classfile::Perl;

use strict;
use vars qw($VERSION @ISA);
use Java::JVM::Classfile;

$VERSION = '0.12';

sub new {
  my $class = shift;
  my $filename = shift;
  my $self = {};

  my $c = Java::JVM::Classfile->new($filename);
  $self->{_class} = $c;
  bless $self, $class;
  return $self;
}

sub as_perl {
  my $self = shift;
  my $c = $self->{_class};
  my $code;

  $code .= q|
package java::io::PrintStream;
sub new {
  my $class = shift;
  my $self = {};
  return bless $self, $class;
}
sub print {
  my $self = shift;
  print shift();
}
sub println {
  my $self = shift;
  my $arg = shift;
  print $arg if defined $arg;
  print "\n";
}

package java::lang::Integer;
sub parseInt {
  my($class, $s) = @_;
  return $s + 0;
}

package java::lang::System;
sub out {
  return java::io::PrintStream->new();
}

package java::lang::StringBuffer;
sub new {
  my $class = shift;
  my $self = {};
  $self->{value} = "";
  return bless $self, $class;
}
sub append {
  my $self = shift;
  my $text = shift;
  $self->{value} .= $text;
  return $self;
}
sub toString {
  my $self = shift;
  return $self->{value};
}
|;

  $code .= "package " . $c->class . ";\n";

  die "Subclasses not supported!" if $c->superclass ne "java/lang/Object";

  foreach my $method (@{$c->methods}) {
    next if $method->name eq '<init>';
    $code .= "sub " . $method->name . " {\n";
    $code .= "my \@stack;\n";
    $code .= "my \$class = shift();\n";
    $code .= "my \@locals = \@_;\n";
    $code .= "my(\$o, \$p, \$return);\n";
#    $code .= qq|print "locals ";\n|;
#    $code .= qq|print join("# ", \@\$locals[0]) . "\\n";\n|;
    foreach my $att (@{$method->attributes}) {
      my $name = $att->name;
      my $value = $att->value;
      next unless $name eq 'Code';
      foreach my $instruction (@{$value->code}) {
	my $label = $instruction->label;
	my $op = $instruction->op;
	my @args = @{$instruction->args};
	$code .= "$label:\n" if defined $label;
	my $javacode = "\t$op\t" . (join ", ", @{$instruction->args});
	$code .= "# $javacode\n";
#	$code .= qq|print "\@stack / code = $javacode\\n";\n|;
	if ($op eq 'getstatic') {
	  my $class = $args[0];
	  $class =~ s|/|::|g;
	  my $field = $args[1];
	  $code .= "push \@stack, $class->$field;\n";
	} elsif ($op eq 'new') {
	  my $class = $args[0];
	  $class =~ s|/|::|g;
	  $code .= "push \@stack, $class->new();\n";
	} elsif ($op eq 'invokevirtual') {
	  my $class = $args[0];
	  $class =~ s|/|::|g;
	  my $method = $args[1];
	  my $signature = $args[2];
	  my($in, $out) = $signature =~ /^\((.*?)\)(.*?)$/;
	  $out = "" if defined($out) && $out eq 'V';
#	  $code .= "push \@stack, (pop \@stack)->$method(pop \@stack);\n";
	  if ($in) {
	    $code .= qq|\$o = pop \@stack;
\$p = pop \@stack;
\$return = \$p->$method(\$o); # $in / $out\n|;
	  } else {
	    $code .= "\$return = (pop \@stack)->$method(); # $in / $out\n";
	  }
	  $code .= "push \@stack, \$return;\n" if $out;
	} elsif ($op eq 'invokestatic') {
	  my $class = $args[0];
	  $class =~ s|/|::|g;
	  my $method = $args[1];
	  my $signature = $args[2];
	  my($in, $out) = $signature =~ /^\((.*?)\)(.*?)$/;
	  $out = "" if defined($out) && $out eq 'V';
#	  $code .= "push \@stack, (pop \@stack)->$method(pop \@stack);\n";
	  if ($in) {
	    $code .= qq|\$o = pop \@stack;
\$return = $class->$method(\$o); # $in / $out\n|;
	  } else {
	    $code .= "\$return = $class->$method(); # $in / $out\n";
	  }
	  $code .= "push \@stack, \$return;\n" if $out;
	} elsif ($op eq 'invokespecial') {
	  $code .= "pop \@stack;\n";
	} elsif ($op eq 'ldc') {
	  my $arg = $args[0];
	  $code .= "push \@stack, '$arg';\n";
	} elsif ($op eq 'bipush') {
	  my $arg = $args[0];
	  $code .= "push \@stack, $arg;\n";
	} elsif ($op eq 'return') {
	  $code .= "return;\n";
	} elsif ($op eq 'ireturn') {
	  $code .= "return pop(\@stack);\n";
	} elsif ($op =~ /iconst_(\d)/) {
	  $code .= "push \@stack, $1;\n";
	} elsif ($op =~ /istore_(\d)/) {
	  $code .= "\$locals[$1] = pop \@stack;\n";
	} elsif ($op eq 'istore') {
	  my $i = $args[0];
	  $code .= "\$locals[$i] = pop \@stack;\n";
	} elsif ($op =~ /[ai]load_(\d)/) {
	  $code .= "push \@stack, \$locals[$1];\n";
	} elsif ($op =~ /^[ai]load$/) {
	  my $i = $args[0];
	  $code .= "push \@stack, \$locals[$i];\n";
	} elsif ($op eq 'goto') {
	  my $label = $args[0];
	  $code .= "goto $label;\n";
	} elsif ($op eq 'dup') {
	  $code .= "push \@stack, \$stack[-1];\n";
	} elsif ($op eq 'iadd') {
	  $code .= "push \@stack, (pop \@stack) + (pop \@stack);\n";
	} elsif ($op eq 'isub') {
	  $code .= "push \@stack, - (pop \@stack) + (pop \@stack);\n";
	} elsif ($op eq 'aaload') {
	  $code .= qq|\$o = pop \@stack;
my \$array = pop \@stack;
#print join("; ", \@\$array) . "\\n";
push \@stack, \$array->[\$o];\n|;
	} elsif ($op eq 'iinc') {
	  my $i = $args[0];
	  my $n = $args[1];
	  $code .= "\$locals[$i] += $n;\n";
	} elsif ($op eq 'imul') {
	  $code .= "push \@stack, (pop \@stack) * (pop \@stack);\n";
	} elsif ($op eq 'if_icmplt') {
	  my $label = $args[0];
	  $code .= "goto $label if (pop \@stack) > (pop \@stack);\n";
	} elsif ($op eq 'if_icmpge') {
	  my $label = $args[0];
	  $code .= "goto $label if (pop \@stack) <= (pop \@stack);\n";
	} else {
	  $code .= "# ?\n";
	}
      }
      print "\n";
    }
    $code .= "}\n";
  }
#  $code .= qq|print join(", ", \@ARGV) . "\\n";\n|;
  $code .= $c->class . "->main([\@ARGV]);\n";
  return $code;
}

