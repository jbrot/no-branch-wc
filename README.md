# no-branch-wc

This is made in response to [this post](https://dlang.org/blog/2020/01/28/wc-in-d-712-characters-without-a-single-branch/).
The author there claims to have made wc without any branches, when in fact there are merely no explicit if statements.

The goal of this project is to create a wc program without a single branching instruction in the entire binary.
Unfortunately, there are two loops essential to the program (one to loop through the input, and one to print out numbers---although this second one could be dispensed of at the expense of the output's legibility).
There is no real way to have a terminating loop without branching of some fashion, although it can be obfuscated pretty effectively.
I currently use no conditionaly branches (`je`, `jne`, etc.), which I think is sufficient to consider this project a success.
I tried to use self-modifying code to truly avoid executing a branching instruction, but macOS makes this incredibly difficult (namely, it won't let you use `mprotect` to enable writing to the program code, so I would have to execute portions of the program on the stack. Since the self-modifying solution is only marginally more indirect than the current solution I've written, I decided this was more effort that it was worth).

# Requirements

This program will only run on macOS, as it uses the macOS syscalls directly.
It should probably run on any version of the OS, though, since it only depends on said syscalls.
It is possible the code will work on certain BSDs do the shared syscalls, but I have not tested this and have no interest.
To get this program to run on Linux requires rewriting these syscalls, which is relatively trivial.
I would be happy to accept a PR that provides such a Linux version.

# Usage

To compile the program, simply run `make` in the root directory.
The program requries `nasm` for assembly and `ld` to link, both of which should come pre-installed with macOS.

The program will only process input on `stdin`, so you will want to pipe in the input.
For instance, to run the program on this file, you would run `cat README.md | ./no-branch-wc`.

# License

This program is released under the GPL v3.
