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
    ; Reserve space on the stack
    ;
    ; -16: char being read in
    ; -15: bool (in a word?)
    ; -14: word count
    ; -10: line count
    ; - 6: char count

    push rbp ; Unclear if we really need to do this because we won't call ret
    mov rbp, rsp
    sub rsp, 0x10

    ; Initialize the counts to 0
    xor rax, rax
    mov [rbp - 8], rax
    mov [rbp - 16], rax

    ; Set up interrupt handler
    mov rdi, done
    call prepare_interrupt

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

    ; If rax is zero (end of stream), we use the interrup to jump to done
    ; without a branch statement. Sure, this is just using branch statements
    ; in the kernel instead of here, but similar behavior could be achieved
    ; with hardware interrupts if we /were/ the kernel: which is why I consider
    ; this to be a legitimate tactic to avoid branch statements
    mov rdi, rax
    call interrupt_on_zero

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

    ; Print out the results

    mov dil, 0x09 ; '\t'
    call print_char

    ; Print line count
    xor rdi, rdi
    mov edi, [rbp - 10]
    call print_number

    mov dil, 0x09
    call print_char

    ; Print word count
    xor rdi, rdi
    mov edi, [rbp - 14]
    call print_number

    mov dil, 0x09
    call print_char

    ; Print char count
    xor rdi, rdi
    mov edi, [rbp - 6]
    call print_number

    mov dil, 0x0a ; '\n'
    call print_char

    ; exit(0)
    mov rax, 0x2000001
    xor rdi, rdi
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

    ; rbp - 8:  number
    ; rbp - 16: length
    sub rsp, 0x10
    mov [rbp - 8], rdi
    xor r11, r11
    mov [rbp - 16], r11

    push rdi
    mov rdi, pn_done
    call prepare_interrupt
    pop rdi

pn_loop:
    ; Increase length, reserve space for next character
    sub rsp, 0x01
    inc qword [rbp - 16]

    ; Divide parameter by 10, store remainder at rsp
    mov rax, [rbp - 8] ; rax: current value
    xor rdx, rdx
    mov r8, 0x0A ; r8: 10
    div r8 ; rax: current value divided by 10, rdx: remainder
    add rdx, '0'
    mov byte [rsp], dl ; store modulus as ascii character in buffer
    mov [rbp - 8], rax; Update current value to itself divided by 10 (rax)

    ; If we're at 0, we're done!
    ; This uses the same interrupt strategy as above
    cmp rax, 0x00
    setne dil
    movzx rdi, dil
    call interrupt_on_zero
    jmp pn_loop

pn_done:

    ; Write out the buffer
    ; user_ssize_t write(int fd, user_addr_t cbuf, user_size_t nbyte);
    mov rax, 0x2000004
    mov rdi, 0x01
    lea rsi, [rbp - 16]
    mov rdx, [rbp - 16]
    sub rsi, rdx
    syscall

    ; Restore stack frame, and return.
    mov rsp, rbp
    pop rbp
    ret

; Cause execution to jump to the address in rdi when SIGHUP is received
; Note that after this jump, rsp will be messed up, but rbp will be unchanged.
; Thus, you can use this within a function to break from a loop: the standard
; epilog will properly restore the stack.
prepare_interrupt:
    push rbp
    mov rbp, rsp
    sub rsp, 0x18
    and spl, 0xF0 ; 16-byte align the stack

    ; Prepare struct __sigaction
    mov [rbp - 24], rdi ; The handler
    mov [rbp - 16], rdi ; The trampoline
    ; If we were trying to handle the interrupt in good faith, we would provide a
    ; dedicated trampoline function to deal with gracefully entering and exiting
    ; the interrupt handler. As it stands, we're just using the interrupt as a way
    ; of exiting the loop without a branch statement, so we just set both to point
    ; to `done`.
    mov dword [rbp - 8], 0x0000 ; sigset_t
    mov dword [rbp - 4], 0x0010 ; sa_flags (SA_NODEFER)
    ; We need to set SA_NODEFER because we don't properly exit the interrupt handler.
    ; That's what the trampoline is supposed to do. However, by setting NODEFER, we
    ; can receive a given interrupt even while in its interrupt handler: allowing us
    ; to effectively ignore the fact that the OS thinks we're still in the interrupt
    ; handling code. In general, this is not a good idea---but this project is not
    ; to create good code, it's to create working code without branches.

    ; int sigaction(int signum, struct __sigaction *nsa, struct sigaction *osa);
    mov rax, 0x200002E
    mov rdi, 0x01
    lea rsi, [rbp - 24]
    xor rdx, rdx
    syscall

    mov rsp, rbp
    pop rbp
    ret

; Raise SIGHUP if rdi is 0. Perform a no op otherwise
interrupt_on_zero:
    ; We don't have locals here, so we don't need to adjust ebp. In fact, it's crucial
    ; that we don't adjust ebp as, in the event, that we wind up in the interrupt handler,
    ; ret will never be called here, and likewise ret will never be called for the jump
    ; into the handler itself: leaving two pointers pushed on top of the stack. However,
    ; as long as the calling function references everything in terms of ebp, it can ignore
    ; these two extraneous pointers, and they will be properly released in the function epilog.

    ; int getpid(void);
    mov rax, 0x2000014
    syscall
    mov rsi, rax

    ; We set rax with a syscall op based on the low bit of rdi.
    ; If it is 1, we fill in a no op. If it is 0, we fill in kill.
    mov r8, 0x2000025 ; kill
    mov r9, 0x2000176 ; no-op
    xor r9, r8
    mov rax, rdi
    and rax, 0x01
    mul r9
    xor rax, r8

    ; int kill(int pid, int signum, int posix);
    mov rdx, rsi
    mov rsi, 0x01
    syscall

    ret
