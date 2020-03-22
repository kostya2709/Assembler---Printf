section .bss
STD_OUT equ 1
EXIT 	equ 1 
WRITE 	equ 4
ERR_NO 	equ 0

section .data

	hell: db "Helooooo", 0
	printf_format:
	db "%p pedics %d\n", 0

	printf_test_args:
	db "Number of written arguments: %d\n", 0
section .text

global _start
extern _printf

_start:

	mov rax, 1
	shl rax, 63
	push rax
	push hell
	push printf_format
	call _printf

	push rax
	push printf_test_args
	call _printf
	
.End:

	mov rax, EXIT		; системный вызов "sys_exit"
	mov rbx, ERR_NO		; код ошибки
	int 0x80

	ret