%include "printf.asm"

section .bss
EXIT 	equ 1 
ERR_NO 	equ 0

section .data

	hell: db "Helooooo", 0
	printf_format:
	db "%p heh %d\n", 0

	printf_test_args:
	db "Number of written arguments: %d\n\n\n", 0
section .text

global _start

_start:
	call _unitest_c
	call _unitest_sl
	call _unitest_d

.End:

	mov rax, EXIT		; системный вызов "sys_exit"
	mov rbx, ERR_NO		; код ошибки
	int 0x80

	ret

section .data

	format_c:
	db "\n\n\n-------------UNITEST FOR '%%c'-------------\n\n", 0
	format_test_c: 
	db "%c c%cn insert%csymbols%c\vAnd do not forget about %%\n", 0
_unitest_c:

	printf format_c

	printf format_test_c, 'I', 'a', ' ', '!'

	printf printf_test_args, rax

ret

section .data

	format_slash:
	db "------------UNITEST FOR slashes----------\n\n", 0
	format_tab: 
	db "I can make tab: '\t'\n", 0
	format_slashn: 
	db "I can make new line: '\n'\n", 0
	format_slashv: 
	db "I can make vertical tabulation: '\v'\n", 0
_unitest_sl:

	printf format_slash

	printf format_tab

	printf format_slashn

	printf format_slashv

ret

section .data

	format_d:
	db "------------UNITEST FOR '%%d' AND '%%u'----------\n\n", 0
	format_d1: 
	db "%d: 1 in d and u: '%d', '%u'\n", 0
	format_d2: 
	db "%d: -1 in d and u: '%d', '%u'\n", 0
	format_d3: 
	db "%d: (1 << 31)-1 = max_int= '%d', '%u'\n", 0
	format_d4: 
	db "%d: (1 << 31) '%d', '%u'\n", 0

	format_d5:
	db "%d: (1 << 32)-1 '%d', '%u'\n", 0

	format_d6:
	db "%d: (1 << 32) '%d', '%u'\n", 1h, 0

_unitest_d:

	printf format_d

	printf format_d1, 1, 1, 1

	printf format_d2, 2, -1, -1

	mov rax, 1
	shl rax, 31
	dec rax
	printf format_d3, 3, rax, rax


	mov rax, 1
	shl rax, 31
	printf format_d4, 4, rax, rax

	mov rax, 1
	shl rax, 32
	dec rax
	printf format_d5, 5, rax, rax


	mov rax, 1
	shl rax, 32
	printf format_d6, 6, rax, rax

ret
