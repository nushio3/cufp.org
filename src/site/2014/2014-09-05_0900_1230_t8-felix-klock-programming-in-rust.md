- type: tutorial
- title: T8: Programming in Rust
- speakers: Felix Klock, Lars Bergstorm
- affiliations: Mozilla, Mozilla

## Abstract
Rust is a new programming language for developing reliable and
efficient systems. It is designed to support concurrency and
parallelism in building platforms that take full advantage of modern
hardware. Its static type system is safe and expressive and it
provides strong guarantees about isolation, concurrency, execution,
and memory safety.

Rust combines powerful and flexible modern programming constructs with
a clear performance model to make program efficiency predictable and
manageable. One important way it achieves this is by allowing
fine-grained control over memory allocation through contiguous records
and stack allocation. This control is balanced with the absolute
requirement of safety: Rust’s type system and runtime guarantee the
absence of data races, buffer overflow, stack overflow, or access to
uninitialized or deallocated memory.

## Tutorial objectives
This tutorial introduces Rust with a focus on the advanced type system
features. We begin by installing Rust, and then work through a variety
of examples, beginning with simple type definitions and proceeding
through Rust's approach to affine and region types.  These examples
show a collection of programming patterns which tie into Rust language
features, such as user-defined destructors, controlled memory
aliasing, and lifetime-bounding parameters.

## Target audience
Systems programmers who desire predictable performance and safe memory
usage without a garbage collector.

Participants need Linux or OSX.

## Felix Klock
<!--<img align="right" src="img/felix-kock.jpg" alt="Felix Klock"></img>-->
Felix Klock is a Researcher at Mozilla.  He works on the Rust compiler
and runtime libraries, and obtained his PhD in Computer Science from
Northeastern University.  He previously worked on the ActionScript
Virtual Machine for the Adobe Flash Runtime.

## Lars Bergstrom.
<!--<img align="right" src="img/lars-bergstorm.jpg" alt="Lars Bergstorm"></img>-->
Lars Bergstrom is a Researcher at Mozilla. He works
on the Servo web browser engine and obtained his PhD in Computer
Science from the University of Chicago. He previously worked on
Developer Tools at Microsoft.