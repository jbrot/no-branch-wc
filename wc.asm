;
;    no-branch-wc: a wc clone with no branch instructions
;    Copyright (C) 2020 Joshua Brot
;
;    This program is free software: you can redistribute it and/or modify
;    it under the terms of the GNU General Public License as published by
;    the Free Software Foundation, either version 3 of the License, or
;    (at your option) any later version.
;
;    This program is distributed in the hope that it will be useful,
;    but WITHOUT ANY WARRANTY; without even the implied warranty of
;    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;    GNU General Public License for more details.
;
;    You should have received a copy of the GNU General Public License
;    along with this program.  If not, see <https://www.gnu.org/licenses/>.
;

global _main

section .text

_main:
    ; Allocate 8 bytes on the stack.
    push rbp ; Unclear if we really need to do this because we won't call ret
    mov rbp, rsp
    sub rsp, 0x08

loop:
    ; Read one char into rbp - 8
    ;
    ; Arguments are passed via rdi, rsi, rdx, r10, r8, r9
    ; user_ssize_t read(int fd, user_addr_t cbuf, user_size_t nbyte);
    mov rax, 0x2000003
    mov rdi, 0x00
    lea rsi, [rbp - 8]
    mov rdx, 0x01
    syscall

    ; Go to done eax is 0 or continue if eax is 1
    ; That is, if we're at the end of the input we go to done, otherwise we go to continue
    mov r8, done
    mov r9, continue
    xor r9, r8
    mul r9
    xor rax, r8
    jmp rax

continue:

    ; Process the input. For now, just echo to stdout.

    ; user_ssize_t write(int fd, user_addr_t cbuf, user_size_t nbyte);
    mov rax, 0x2000004
    mov rdi, 0x01
    lea rsi, [rbp - 8]
    mov rdx, 0x01
    syscall

    ; Repeat
    jmp loop

done:

    ; exit(0)
    mov rax, 0x2000001
    mov rdi, 0x00
    syscall
