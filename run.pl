#!/usr/bin/perl -w
use strict;
use lib 'lib';
use Java::JVM::Classfile;

my $c = Java::JVM::Classfile->new("HelloWorld.class");
print "Magic: " . $c->magic . "\n";
print "Version: " . $c->version . "\n";
print "Class: " . $c->class . "\n";
print "Superclass: " . $c->superclass . "\n";
print "Constant pool: " . scalar(@{$c->constant_pool}) . "\n";
print "Access flags: " . join(", ", @{$c->access_flags}) . "\n";

print "Interfaces: " . scalar(@{$c->interfaces}) . "\n";
print "Fields: " . scalar(@{$c->fields}) . "\n";

print "Methods: " . scalar(@{$c->methods}) . "\n";
foreach my $method (@{$c->methods}) {
  print "  " . $method->name . " " . $method->descriptor;
  print "\n    ";
  print "is " . join(", ", @{$method->access_flags});
  print "\n    ";
  print "has attributes " . join(", ", map { $_->name } @{$method->attributes});
  print "\n";
}

print "Attributes: " . scalar(@{$c->attributes}) . "\n";

foreach my $attribute (@{$c->attributes}) {
  print "  " . $attribute->name . " = " . $attribute->value . "\n";
}
