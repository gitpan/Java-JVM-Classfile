package Java::JVM::Classfile::ConstantPoolEntry;
use Class::Struct;
use overload '""' => \&as_text;
struct(type => '$', #'
       values => '@');
sub as_text {
  my $self = shift;
  return $self->type . '(' . join(", ", @{$self->values}) . ')';
}
sub value {
  my $self = shift;
  return $self->values->[0];
}

package Java::JVM::Classfile::Method;
use Class::Struct;
use overload '""' => \&as_text;
struct(access_flags => '@',
       name => '$',
       descriptor => '$',
       attributes => '$'); #'
sub as_text {
  my $self = shift;
  my $result = "";
  $result .= $self->name . " ";
  $result .= $self->descriptor . " ";
  $result .= "[" . join(", ", @{$self->access_flags}) . "] ";
  $result .="= " . join(", ", @{$self->attributes}) . "] ";
  return $result;
}

package Java::JVM::Classfile::Attribute;
use Class::Struct;
use overload '""' => \&as_text;
struct(name => '$',
       value => '$');
sub as_text {
  my $self = shift;
  my $name = $self->name;
  if ($name eq 'Code') {
    return $name;
  } else {
    return $name . ' (' . $self->value . ')';
  }
}

package Java::JVM::Classfile::Struct;
use Class::Struct;
use overload '""' => \&as_text;
struct(magic => '$',
       version => '$',
       constant_pool => '$',
       access_flags => '@',
       class => '$',
       superclass => '$',
       interfaces => '$',
       fields => '$',
       methods => '$',
       attributes => '$',
); #'
sub as_text {
  my $self = shift;
  my $result;
  $result .= "Magic: " . $self->magic . "\n";
  $result .= "Version: " . $self->version . "\n";
  $result .= "Class: " . $self->class . "\n";
  $result .= "Superclass: " . $self->superclass . "\n";
  $result .= "Constant pool:\n" . $self->constant_pool;
  $result .= "Access flags: " . join(", ", @{$self->access_flags}) . "\n";
  $result .= "Interfaces: " . $self->interfaces . "\n";
  $result .= "Fields: " . $self->fields . "\n";
  $result .= "Methods:\n" . $self->methods . "\n";
  $result .= "Attributes:\n" . $self->attributes . "\n";
  return $result;
}

package Java::JVM::Classfile;

use strict;
use vars qw($VERSION);
use IO::File;
use Carp qw(croak);

use constant Utf8 => 1;
use constant Integer => 3;
use constant Float => 4;
use constant Long => 5;
use constant Double => 6;
use constant Class => 7;
use constant Fieldref => 9;
use constant String => 8;
use constant Methodref => 10;
use constant InterfaceMethodref => 11;
use constant NameAndType => 12;

use constant ACC_PUBLIC       => 0x0001;
use constant ACC_PRIVATE      => 0x0002;
use constant ACC_PROTECTED    => 0x0004;
use constant ACC_STATIC       => 0x0008;

use constant ACC_FINAL        => 0x0010;
use constant ACC_SYNCHRONIZED => 0x0020;
use constant ACC_VOLATILE     => 0x0040;
use constant ACC_TRANSIENT    => 0x0080;

use constant ACC_NATIVE       => 0x0100;
use constant ACC_INTERFACE    => 0x0200;
use constant ACC_ABSTRACT     => 0x0400;
use constant ACC_STRICT       => 0x0800;

# Applies to classes compiled by new compilers only
use constant ACC_SUPER        => 0x0020;
use constant MAX_ACC_FLAG     => ACC_ABSTRACT;
my @CLASSACCESS;
$CLASSACCESS[0] = "public";
$CLASSACCESS[3] = "final";
$CLASSACCESS[5] = "super";
$CLASSACCESS[8] = "interface";
$CLASSACCESS[9] = "abstract";

my @METHODACCESS;
$METHODACCESS[0] = "public";
$METHODACCESS[1] = "private";
$METHODACCESS[2] = "protected";
$METHODACCESS[3] = "static";
$METHODACCESS[4] = "final";
$METHODACCESS[5] = "synchronized";
$METHODACCESS[7] = "native";
$METHODACCESS[9] = "abstract";
$METHODACCESS[10] = "strict";

my @ACCESS = (
    "public", "private", "protected", "static", "final", "synchronized",
    "volatile", "transient", "native", "interface", "abstract");

$VERSION = '0.12';

sub new {
  my $proto = shift;
  my $filename = shift;
  my $class = ref($proto) || $proto;
  my $self = {};
  $self->{FILENAME} = $filename;

  bless($self, $class);
  return $self->_parse;

#  return $self;
}

sub _parse {
  my $self = shift;
  $self->{FH} = IO::File->new($self->{FILENAME}) or croak("Couldn't read class " . $self->{FILENAME} . "!");

  my $magic = $self->check_magic;
  my $version = $self->read_version;
  my $constant_pool = $self->read_constant_pool;
  my($access_flags, $class, $superclass) = $self->read_class_info($constant_pool);
  my $interfaces = $self->read_interfaces;
  my $fields = $self->read_fields;
  my $methods = $self->read_methods($constant_pool);
  my $attributes = $self->read_attributes($constant_pool);

  my $struct = Java::JVM::Classfile::Struct->new(
    magic => $magic,
    version => $version,
    constant_pool => $constant_pool,
    access_flags => $access_flags,
    class => $class,
    superclass => $superclass,
    interfaces => $interfaces,
    fields => $fields,
    methods => $methods,
    attributes => $attributes,
  );

#  print $struct;

  die "Junk at end of file!\n" unless $self->{FH}->eof;
  $self->{FH}->close;
  return $struct;
}

sub check_magic {
  my $self = shift;
  my $magic = $self->readint;
  die "Not Java class file!\n" unless ($magic eq 0xCAFEBABE);
  return $magic;
}

sub read_version {
  my $self = shift;
  my $minor = $self->readus;
  my $major = $self->readus;
#  print "Compiler version: " . $self->{major} . '.' . $self->{minor} . "\n";
  return "$major.$minor";
}

sub read_constant_pool {
  my $self = shift;
  my $count = $self->readus;

  my @constant_pool;

#  print "Constant pool entries: $count \n";
  foreach my $index (1 .. $count - 1) {
#    print "constant pool $index: ";
    my $type = $self->readbyte;
    if ($type == Methodref) {
      my $class_index = $self->readus;
      my $name_and_type_index = $self->readus;
      $constant_pool[$index] = Java::JVM::Classfile::ConstantPoolEntry->new(type =>
        'methodref', values => [$class_index, $name_and_type_index]);
#      print "methodref $class_index, $name_and_type_index\n";
    } elsif ($type == Fieldref) {
      my $class_index = $self->readus;
      my $name_and_type_index = $self->readus;
      $constant_pool[$index] = Java::JVM::Classfile::ConstantPoolEntry->new(type =>
        'fieldref', values => [$class_index, $name_and_type_index]);
#      print "fieldref $class_index, $name_and_type_index\n";
    } elsif ($type == Class) {
      my $name_index = $self->readus;
      $constant_pool[$index] = Java::JVM::Classfile::ConstantPoolEntry->new(type =>
        'class', values => [$name_index]);
#      print "class $name_index\n";
    } elsif ($type == Utf8) {
      my $length = $self->readus;
      my $string;
      $string .= chr($self->readbyte) foreach (1..$length);
      $constant_pool[$index] = Java::JVM::Classfile::ConstantPoolEntry->new(type =>
        'utf8', values => [$string]);
#      print "String: $string\n";
    } elsif ($type == NameAndType) {
      my $name_index = $self->readus;
      my $descriptor_index = $self->readus;
      $constant_pool[$index] = Java::JVM::Classfile::ConstantPoolEntry->new(type =>
        'nameandtype', values => [$name_index, $descriptor_index]);
#      print "nameandtype: $name_index $descriptor_index\n";
    } elsif ($type == String) {
      my $string_index = $self->readus;
      $constant_pool[$index] = Java::JVM::Classfile::ConstantPoolEntry->new(type =>
        'string', values => [$string_index]);
    } else {
      die "unknown constant type $type in pool!\n";
    }
  }

  return \@constant_pool;
}

sub read_class_info {
  my($self, $constant_pool) = @_;


  my @flags;
  my $access_flags = $self->readus;

  if(($access_flags & ACC_INTERFACE) != 0) {
    $access_flags |= ACC_ABSTRACT;
  }

  if((($access_flags & ACC_ABSTRACT) != 0) && 
     (($access_flags & ACC_FINAL)    != 0 )) {
    die("Class can't be both final and abstract");
  }

#  print "Access flags: $access_flags = ";
  my $bits = reverse unpack("B*", pack ("c*" ,$access_flags));
#  print "($bits) is ";
  foreach my $index (0..length($bits)) {
#    print $CLASSACCESS[$index] if substr($bits, $index, 1);
    push @flags, $CLASSACCESS[$index] if substr($bits, $index, 1);
  }
#  print "\n";
  my $class_name_index = $self->readus;
  my $class = $constant_pool->[$class_name_index];
  die "Class name index doesn't point to class!" unless $class->type eq 'class';
  my $class_name = $constant_pool->[$class->value];
  die "Class name class doesn't point to string!" unless $class_name->type eq 'utf8';
  my $myclass_name = $class_name->value;

  my $superclass_name_index = $self->readus;
  $class = $constant_pool->[$superclass_name_index];
  die "Superclass name index doesn't point to class!" unless $class->type eq 'class';
  $class_name = $constant_pool->[$class->value];
  die "Superclass name class doesn't point to string!" unless $class_name->type eq 'utf8';
  my $superclass_name = $class_name->value;

  return \@flags, $myclass_name, $superclass_name;
#  print "Class is $class_name_index, super $superclass_name_index\n";
}

sub read_interfaces {
  my $self = shift;

  my $interfaces_count = $self->readus;
  die "Interfaces not yet supported!" if $interfaces_count;

  return [];
}

sub read_fields {
  my $self = shift;

  my $fields_count = $self->readus;
  die "Interfaces not yet supported!" if $fields_count;

  return [];
}

sub read_methods {
  my($self, $constant_pool) = @_;

  my @methods;

  my $method_count = $self->readus;
#  print "Methods: $method_count\n";

  foreach my $index (0..$method_count-1) {
#    $methods[$_] = $self->readus;

    my $access_flags = $self->readus;
    my @access_flags;

    my $bits = reverse unpack("B*", pack ("c*" ,$access_flags));
    foreach my $index (0..length($bits)) {
      push @access_flags, $METHODACCESS[$index] if substr($bits, $index, 1);
    }

    my $name_index = $self->readus;
    my $name = $constant_pool->[$name_index];
    die "name_index doesn't point to string" unless $name->type eq 'utf8';
    $name = $name->value;
    my $descriptor_index = $self->readus;
    my $descriptor = $constant_pool->[$descriptor_index];
    die "descriptor_index doesn't point to string" unless $descriptor->type eq 'utf8';
    $descriptor = $descriptor->value;

    my $attributes = $self->read_attributes($constant_pool);

    push @methods, Java::JVM::Classfile::Method->new(
      name => $name,
      access_flags => \@access_flags,
      descriptor => $descriptor,
      attributes => $attributes,
    );
  }

  return \@methods;
}

sub read_attributes {
  my($self, $constant_pool) = @_;

  my $attributes_count = $self->readus;
  my @attributes;
  foreach (0..$attributes_count-1) {
    my $attribute_name_index = $self->readus;
    my $attribute_name = $constant_pool->[$attribute_name_index];
    die "attribute_name_index doesn't point to string" unless $attribute_name->type eq 'utf8';
    $attribute_name = $attribute_name->value;
    my $attribute_length = $self->readint;
    my $info;
    if ($attribute_name eq 'Code') {
      $info = "";
      $info .= chr($self->readbyte) foreach (0..$attribute_length-1);
    } elsif ($attribute_name eq 'SourceFile') {
      die "length not 2" if $attribute_length != 2;
      my $sourcefile_index = $self->readus;
      my $sourcefile = $constant_pool->[$sourcefile_index];
      die "sourcefile_index doesn't point to string" unless $sourcefile->type eq 'utf8';
      $info = $sourcefile->value;
    }
#    print "info: $info<--\n" if $attribute_name ne 'Code';
    push @attributes, Java::JVM::Classfile::Attribute->new(name => $attribute_name, value => $info);
  }
  return \@attributes;
}

sub read_attributes_off {
  my $self = shift;

  my $attributes_count = $self->readus;
#  print "Attributes: $attributes_count\n";
  my @attributes;
  foreach (0..$attributes_count-1) {
#    print "Attributes $_:\n";
#    $methods[$_] = $self->readus;
      my $attribute_name_index = $self->readus;
      my $attribute_length = $self->readint;
      my $info = "";
#      print "  name: $attribute_name_index\n";
#      print "  info length: $attribute_length\n";
      $info .= chr($self->readbyte) foreach (0..$attribute_length-1);
#      print "  info: $info\n";
  }
}

sub readint {
  my $self = shift;
  my $fh = $self->{FH};
  local $/ = \4;
  my $int = unpack('N', <$fh>);
  return $int;
}

sub readus {
  my $self = shift;
  my $fh = $self->{FH};
  local $/ = \1;
  my $int = unpack('C', <$fh>);
  $int *= 256;
  $int += unpack('C', <$fh>);
  return $int;
}

sub readbyte {
  my $self = shift;
  my $fh = $self->{FH};
  local $/ = \1;
  my $int = unpack('C', <$fh>);
  return $int;
}


1;

__END__

=head1 NAME

Java::JVM::Classfile - Parse JVM Classfiles

=head1 SYNOPSIS

  use Java::JVM::Classfile;

  my $c = Java::JVM::Classfile->new("HelloWorld.class");
  print "Class: " . $c->class . "\n";
  print "Methods: " . scalar(@{$c->methods}) . "\n";

=head1 DESCRIPTION

The Java Virtual Machine (JVM) is an abstract machine which processes
JVM classfiles. Such classfiles contain, broadly speaking,
representations of the Java methods and member fields forming the
definition of a single class, information to support the exception
mechanism and a system for representing additional class
attributes. The JVM itself exists primarily to load and link
classfiles into the running machine on demand (performed by the Class
Loader), represent those classes internally by means of a number of
runtime data structures and facilitate execution (a role shared
between the Execution Engine (which is responsible for execution of
JVM instructions) and the Native Method Interface which allows a Java
program to execute non-Java code, generally ANSI C/C++.

This Perl module reveals the information in a highly-compressed JVM
classfile by representing the information as a series of objects. It
is hoped that this module will eventually lead to a JVM implementation
in Perl (or Parrot), or possibly a way-ahead-of-time (WAT) to Perl (or
Parrot) compiler for Java.

It is important to remember that the Java classfile is
highly-compressed. Classfiles are intended to be as small as possible
as they are often sent across the network. This may explain the
slightly odd object tree. One of the most important things to consider
is the idea of a constant pool. All constants (constant strings,
method names and signatures etc.) are clustered in the constant pool
at the start of the classfile, and sprinkled throughout the file are
references to the constant pool. The module attempts to hide this
optimisation as much as possible from the user, however.

It is probably important to at least have briefly read "The JavaTM
Virtual Machine Specification", http://java.sun.com/docs/books/vmspec/

=head1 METHODS

=head2 new

This is the constructor, it takes the filename of the classfile to
parse and returns an object:

  my $c = Java::JVM::Classfile->new("HelloWorld.class");

=head2 magic

This method returns the magic number for the classfile. All valid
classfiles should have the magic number 0xCAFEBABE:

  my $magic = $c->magic;

=head2 version

This method returns the version of the classfile. The version consists
of a major number and a minor number. For example, "45.3" has major
number 45 and minor number 3:

  my $version = $c->version;

=head2 class

This method returns the name of the class that this classfile
corresponds to:

  my $class = $c->class;

=head2 superclass

This method returns the name of the superclass of the class that this
classfile corresponds to:

  my $superclass = $c->superclass;

=head2 constant_pool

This method returns the constant pool entries as an array
reference. Each entry is an object. Currently undocumented.

  my $constant_pool = $c->constant_pool;

=head2 access_flags

This method returns the access flags for the class as an array
reference. Possible flags are:

=over 4

=item abstract

Declared abstract; may not be instantiated

=item final

Declared final; no subclasses allowed

=item interface

Is an interface, not a class

=item public

Declared public; may be accessed from outside its package

=item super

Treat superclass methods specially when invoked by the invokespecial instruction

=back

  print "Flags: " . join(", ", @{$c->access_flags}) . "\n";

=head2 interfaces

This method returns an array reference of the interfaces defined in
the classfile. Currently unimplemented:

  my $interfaces = $c->interfaces;

=head2 fields

This method returns an array reference of the fields defined in
the classfile. Currently unimplemented:

  my $fields = $c->fields;

=head2 methods

This method returns an array reference of the methods defined in
the classfile:

  my $methods = $c->methods;

Each Java method is represented by an object which has the following
methods: name, descriptor, access_flags and attributes. name and
descriptor return the method name and descriptor. Possible access
flags are:

=over 4

=item abstract

Declared abstract; no implementation is provided

=item final

Declared final; may not be overridden

=item native

Declared native; implemented in a language other than Java

=item private

Declared private; accessible only within the defining class

=item protected

Declared protected; may be accessed within subclasses

=item public

Declared public; may be accessed from outside its package

=item static

Declared static

=item strict

Declared strictfp; floating-point mode is FP-strict

=item synchronized

Declared synchronized; invocation is wrapped in a monitor lock

=back

Various attributes are possible, the most common being the Code
attribute, where the value holds the Java bytecode for the method. At
this moment disassembling the bytecode is not currently possible, but
it is planned.

  foreach my $method (@{$c->methods}) {
    print "  " . $method->name . " " . $method->descriptor;
    print "\n    ";
    print "is " . join(", ", @{$method->access_flags});
    print "\n    ";
    print "has attributes " . join(", ", map { $_->name } @{$method->attributes});
    print "\n";
  }

=head2 attributes

This method returns an array reference of the attributes defined in
the classfile. Attributes are common in many places in the classfile -
here in particular we have the classfile attributes.

  my $attributes = $c->attributes;

Attributes are represented by an object that has name and value methods:

  foreach my $attribute (@{$c->attributes}) {
    print "  " . $attribute->name . " = " . $attribute->value . "\n";
  }

Possible attributes include the SourceFile attribute, the value of
which is the source file that was compiled into this classfile.

=head1 BUGS

A number of classfile features are not currently supported. This will
be fixed real soon now.

Not enough test programs.

=head1 AUTHOR

Leon Brocard E<lt>F<acme@astray.com>E<gt>

=head1 COPYRIGHT

Copyright (C) 2001, Leon Brocard

This module is free software; you can redistribute it or modify it
under the same terms as Perl itself.

=cut

