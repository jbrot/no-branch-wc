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
    ; Allocate 16 bytes on the stack.
    ; -16: char being read in
    ; -15: bool (in a word?)
    ; -14: word count
    ; -10: line count
    ; - 6: char count
    push rbp ; Unclear if we really need to do this because we won't call ret
    mov rbp, rsp
    sub rsp, 0x10

    ; 0 the stack
    xor rax, rax
    mov [rbp - 8], rax
    mov [rbp - 16], rax

loop:
    ; Read one char into rbp - 16
    ;
    ; Arguments are passed via rdi, rsi, rdx, r10, r8, r9
    ; user_ssize_t read(int fd, user_addr_t cbuf, user_size_t nbyte);
    mov rax, 0x2000003
    mov rdi, 0x00
    lea rsi, [rbp - 16]
    mov rdx, 0x01
    syscall

    ; Go to done rax is 0 or continue if eax is 1
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

    ; Process the input.

    ; Increase character count
    inc dword [rbp - 6]

    mov r8b,  [rbp - 16] ; char just read

    ; Increase line count
    cmp r8b, 0x0A ; Compare with '\n'
    sete al
    movzx eax, al
    add [rbp - 10], eax ; Increment line count by 1 or 0 if '\n' or not resp.

    ; Update in-a-word state, put current state in al and previous in r9b.
    mov dil, r8b
    call is_not_space ; al: 1 if read char is not a space, 0: otherwise; r9b has been overwritten
    mov r9b,  [rbp - 15] ; old in-a-word state
    mov [rbp - 15], al

    ; A transition from 0 to 1 indicates the start of a new word.
    cmp al, r9b
    setne al ; al = 1: transition, 0: no transition
    cmp r9b, 0x00
    sete r9b ; r9b = 1: used to be 0, 0: used to be 1
    and al, r9b ; al = 1: start of new word, 0: otherwise
    movzx eax, al
    add [rbp - 14], eax ; Increment word count appropriately

    ; Repeat
    jmp loop

done:

    mov dil, 0x09
    call print_char

    ; print line count
    xor rdi, rdi
    mov edi, [rbp - 10]
    call print_number

    mov dil, 0x09
    call print_char

    ; print word count
    xor rdi, rdi
    mov edi, [rbp - 14]
    call print_number

    mov dil, 0x09
    call print_char

    ; print char count
    xor rdi, rdi
    mov edi, [rbp - 6]
    call print_number

    mov dil, 0x0a
    call print_char

    ; exit(0)
    mov rax, 0x2000001
    mov rdi, [rbp - 4]
    syscall

; Set al to 0 if dil is a space (0x20), form feed (0x0c), line feed (0x0a), carriage return (0x0d),
; horizontal tab (0x09) or vertical tab (0x0b). Otherwise, sets al to 1.
is_not_space:
    ; We don't need locals, so we can ommit the prolog and its converse

    cmp dil, 0x20
    setne al

    cmp dil, 0x0c
    setne r9b
    and al, r9b

    cmp dil, 0x0a
    setne r9b
    and al, r9b

    cmp dil, 0x0d
    setne r9b
    and al, r9b

    cmp dil, 0x09
    setne r9b
    and al, r9b

    cmp dil, 0x0b
    setne r9b
    and al, r9b

    ret

; Prints the char in dil
print_char:
    push rbp
    mov rbp, rsp
    sub rsp, 0x01

    mov [rbp - 1],dil

    ; user_ssize_t write(int fd, user_addr_t cbuf, user_size_t nbyte);
    mov rax, 0x2000004
    mov rdi, 0x01
    lea rsi, [rbp - 1]
    mov rdx, 0x01
    syscall

    mov rsp, rbp
    pop rbp
    ret

; Print the number in rdi out to the console.
print_number:
    push rbp
    mov rbp, rsp

    ; r9: current value
    ; r11: length
    mov r9, rdi
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
