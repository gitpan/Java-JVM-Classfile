#!/usr/bin/perl -w

use strict;
use lib 'lib';
use Java::JVM::Classfile::Perl;

my $c = Java::JVM::Classfile::Perl->new(shift || "HelloWorld.class");

#print $c->as_perl();
eval $c->as_perl();
