use strict;
use Test::More tests => 54;
use lib 'lib';
use Java::JVM::Classfile;
ok(1); # If we made it this far, we're ok.

my $c = Java::JVM::Classfile->new("examples/Fibo.class");
ok(ref($c), "Loaded class");
is($c->magic, 0xCAFEBABE, "Good magic");
is($c->version, '46.0', "Right compiler version");
is($c->class, 'Fibo', "Right class");
is($c->superclass, 'java/lang/Object', "Right superclass");
is(scalar(@{$c->constant_pool}), 31, "Full constant pool");
is_deeply($c->access_flags, ['public', 'super'], "Correct super class access flags");
is(scalar(@{$c->interfaces}), 0, "No interfaces");
is(scalar(@{$c->fields}), 0, "No fields");
is(scalar(@{$c->methods}), 3, "Right number of methods");

my $method = $c->methods->[0];
is($method->name, '<init>', "<init> named");
is($method->descriptor, '()V', "<init> descriptor");
is_deeply($method->access_flags, ['public'], "<init> has is public");
is(scalar(@{$method->attributes}), 1, "<init> has 1 attribute");
is($method->attributes->[0]->name, 'Code', "<init> has Code attribute");
my $code = $method->attributes->[0]->value;
is($code->max_stack, 1, "<init> has 1 max stack");
is($code->max_locals, 1, "<init> has 1 max locals");
my $text;
foreach my $instruction (@{$code->code}) {
  $text .= $instruction->label . ':' if defined $instruction->label;
  $text .= "\t" . $instruction->op . "\t" . (join ", ", @{$instruction->args}) . "\n";
}
is($text, "	aload_0	
	invokespecial	java/lang/Object, <init>, ()V
	return	
", "<init> contains good code");
is(scalar(@{$code->attributes}), 1, "<init> code has 1 attribute");
is($code->attributes->[0]->name, 'LineNumberTable', "<init> code has LineNumberTable attribute");
$text = "";
$text .= "\t" . $_->offset . ", " . $_->line . "\n" foreach (@{$code->attributes->[0]->value});
is($text, "	0, 4\n", "<init> code LineNumberTable correct");

$method = $c->methods->[1];
is($method->name, 'main', "main named");
is($method->descriptor, '([Ljava/lang/String;)V', "main descriptor");
is(scalar(@{$method->access_flags}), 2, "main has two access flags");
is(scalar(grep { $_ eq 'public' } @{$method->access_flags}), 1, "main has access flags public");
is(scalar(grep { $_ eq 'static' } @{$method->access_flags}), 1, "main has access flags static");
is(scalar(@{$method->attributes}), 1, "main has 1 attribute");
is($method->attributes->[0]->name, 'Code', "main has Code attribute");
$code = $method->attributes->[0]->value;
is($code->max_stack, 2, "main has 2 max stack");
is($code->max_locals, 2, "main has 2 max locals");
$text = "";
foreach my $instruction (@{$code->code}) {
  $text .= $instruction->label . ':' if defined $instruction->label;
  $text .= "\t" . $instruction->op . "\t" . (join ", ", @{$instruction->args}) . "\n";
}
is($text, q|	bipush	10
	istore_1	
	getstatic	java/lang/System, out, Ljava/io/PrintStream;
	iload_1	
	invokestatic	Fibo, fib, (I)I
	invokevirtual	java/io/PrintStream, println, (I)V
	return	
|, "main contains good code");
is(scalar(@{$code->attributes}), 1, "main code has 1 attribute");
is($code->attributes->[0]->name, 'LineNumberTable', "main code has LineNumberTable attribute");
$text = "";
$text .= "\t" . $_->offset . ", " . $_->line . "\n" foreach (@{$code->attributes->[0]->value});
is($text, "	0, 6
	3, 7
	13, 8
", "main code LineNumberTable correct");

is(scalar(@{$c->attributes}), 1, "Right number of attributes");
is($c->attributes->[0]->name, 'SourceFile', "SourceFile attribute present");
is($c->attributes->[0]->value, 'Fibo.java', "SourceFile attribute value correct");


$method = $c->methods->[2];
is($method->name, 'fib', "fib named");
is($method->descriptor, '(I)I', "descriptor");
is(scalar(@{$method->access_flags}), 2, "two access flags");
is(scalar(grep { $_ eq 'public' } @{$method->access_flags}), 1, "access flags public");
is(scalar(grep { $_ eq 'static' } @{$method->access_flags}), 1, "access flags static");
is(scalar(@{$method->attributes}), 1, "1 attribute");
is($method->attributes->[0]->name, 'Code', "Code attribute");
$code = $method->attributes->[0]->value;
is($code->max_stack, 3, "3 max stack");
is($code->max_locals, 1, "1 max locals");
$text = "";
foreach my $instruction (@{$code->code}) {
  $text .= $instruction->label . ':' if defined $instruction->label;
  $text .= "\t" . $instruction->op . "\t" . (join ", ", @{$instruction->args}) . "\n";
}
is($text, q|	iload_0	
	iconst_2	
	if_icmpge	L7
	iconst_1	
	ireturn	
L7:	iload_0	
	iconst_2	
	isub	
	invokestatic	Fibo, fib, (I)I
	iload_0	
	iconst_1	
	isub	
	invokestatic	Fibo, fib, (I)I
	iadd	
	ireturn	
|, "main contains good code");
is(scalar(@{$code->attributes}), 1, "main code has 1 attribute");
is($code->attributes->[0]->name, 'LineNumberTable', "main code has LineNumberTable attribute");
$text = "";
$text .= "\t" . $_->offset . ", " . $_->line . "\n" foreach (@{$code->attributes->[0]->value});
is($text, "	0, 10
	7, 11
", "main code LineNumberTable correct");

is(scalar(@{$c->attributes}), 1, "Right number of attributes");
is($c->attributes->[0]->name, 'SourceFile', "SourceFile attribute present");
is($c->attributes->[0]->value, 'Fibo.java', "SourceFile attribute value correct");

exit;

