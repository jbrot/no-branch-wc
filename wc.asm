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

    ; Set character count to 0
    xor eax, eax
    mov [rbp - 4], eax

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
    ; TODO This is an indirect branch. We can eliminate it with self-modifying code.
    ; However, memory protections will get in the way. I need to figure out how to
    ; disable said protections.
    jmp rax

continue:

    ; Process the input. For now, just count characters.

    ; Increase character count
    mov eax, [rbp - 4]
    inc eax
    mov [rbp - 4], eax

    ; Repeat
    jmp loop

done:

    ; print character count
    xor rsi, rsi
    mov esi, [rbp - 4]
    call print_number

    ; exit(0)
    mov rax, 0x2000001
    mov rdi, [rbp - 4]
    syscall

; Print the number in rsi out to the console.
print_number:
    push rbp
    mov rbp, rsp

    ; r9: current value
    ; r11: length
    mov r9, rsi
    xor r11, r11

pn_loop:
    ; Increase length, reserve space for next character
    sub rsp, 0x01
    inc r11


    ; Divide parameter by 10, store remainder at esp
    mov rax, r9 ; rax: current value
    mov r8, 0x0A ; r8: 10
    div r8
    mov r10, rax ; r10: current value divided by 10
    mul r8
    sub r9, rax ; r9: modulus
    add r9, '0'
    mov byte [rsp], r9b ; store modulus as ascii character in buffer
    mov r9, r10 ; Set current value (r9) to itself divided by 10 (r10)

    ; If we're at 0, we're done!
    ; TODO: Avoid branching here using whatever solution we come up with above.
    cmp r9, 0x00
    jne pn_loop

    ; Write out the buffer
    ; user_ssize_t write(int fd, user_addr_t cbuf, user_size_t nbyte);
    mov rax, 0x2000004
    mov rdi, 0x01
    lea rsi, [rsp]
    mov rdx, r11
    syscall

    ; Restore stack frame, and return.
    mov rsp, rbp
    pop rbp
    ret
