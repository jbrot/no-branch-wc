# no-branch-wc

This program was made in response to [this post](https://dlang.org/blog/2020/01/28/wc-in-d-712-characters-without-a-single-branch/) by Robert Schadek.
Schadek claims to have made wc "without a single branch," when in fact he merely used no explicit if statements.
The goal of this project was to actually create a wc program without any branching instructions.
This turned out to be a bit more challenging than I expected.

Rewriting the core logic of wc without branches was relatively straightforward.
Rather than conditionally adding to the various counters, the program unconditionally computes the change in word-, line-, and character-count.
Then, these deltas are unconditionally added to the actual counters.

However, there are two loops in the program: one for processing the input, and one for printing out the numbers.
Creating a terminating loop without a branching statement turned out to be quite tricky.

Originally, I sought to accomplish this with self-modifying code, but modern versions of macOS only let you write self-modifying code in the stack, which I decided was more effort than it was worth.
As a stop-gap measure, I used indirect branches (i.e., jumping to an address in a register) which was not a very satisfying solution, but deemed "good enough" as at least there weren't any conditional branches.

However, after discussing this project with my friend Tommy Cohn, he suggested that I could use interrupts to end the loops without branches.
Since this program is meant to be run in userspace, I couldn't actually use a real hardware interrupt, but I was able to use the next best thing: POSIX signals.
For each loop, the program sets the code to run after the loop ends as the signal handler for `SIGHUP`.
Then, each cycle, the program invokes a syscall.
When the loop is ready to be ended, the kill syscall gets invoked, triggering `SIGHUP` and causing the signal handler to run.
Otherwise, the program just invokes a no-op syscall.
This way, the loop can be terminated without any branching instructions.

Of course, signals are absolutely not meant to be used in this way---and due to the nature of macOS's `sigaction` syscall, my methodology is particularly egregious.
Namely, macOS requires you to provide a [trampoline function](https://github.com/kernigh/ack/blob/kernigh-osx/plat/osx386/libsys/sigaction.s#L34) with your signal handler.
The trampoline function is supposed to set up and tear down properly for the handler.
Here, though, I directly use the continuation code as the trampoline function---leaving the stack in a rather decrepit state, and the OS believing that the program never actualy leaves the signal handler.
However, I find that this just adds to the charm of the whole approach.

Having successfully implemented this signals hack, I now consider the project to be an unmitigated success!
It turns out you really don't need any branch instructions to implement wc, just a willingness to bend the rules of the architecture a bit.

# Requirements

This program will only run on macOS, as it uses the macOS syscalls directly.
It should probably run on any version of the OS, though, since it only depends on said syscalls.
I would be happy to accept any PRs providing version that work on other OSes, but I have no intention of creating such implementations myself.

# Usage

To compile the program, run `make` in the root directory.
The program requries `nasm` for assembly and `ld` to link, both of which should come pre-installed with macOS.

The program will only process input on `stdin`, so you will want to pipe in the input.
For instance, to run the program on this file, you would run `cat README.md | ./no-branch-wc`.

# License

This program is released under the GPL v3.
