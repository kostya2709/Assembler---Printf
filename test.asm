%include "printf.asm"
%include "my_text.asm"

section .bss
EXIT 	equ 1 
ERR_NO 	equ 0

section .data

	hell: db "Helooooo", 0
	printf_format:
	db "%p heh %d\n", 0

	division:
	db "\n\n\n", 0

	printf_test_args:
	db "Number of written arguments: %d\n\n\n", 0
section .text

global _start

_start:

	call _unitest_c
	call _unitest_sl
	call _unitest_d
	call _unitest_l
	call _unitest_bin
	call _big_text

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

	format_example:
	db "I %s %x %d%%%c%b",0xa, 0

	love:
	db "love", 0
_unitest_c:

	printf format_c
	printf format_test_c, 'I', 'a', ' ', '!'
	printf printf_test_args, rax
	printf format_example, love, 3802, 100, '!', 127

ret

_fun:
ret
section .data

	format_slash:
	db "------------UNITEST FOR slashes----------\n\n", 0
	format_tab: 
	db "'\\t': I can make tab: '\t'\n", 0
	format_slashn: 
	db "'\\n': I can make new line: '\n'\n", 0
	format_slashv: 
	db "'\\v': I can make vertical tabulation: '\v'\n", 0
	format_slash0:
	db "'\\0': I can break the sentence right in the mi\0ddle!", 0
	var:
	db 0
_unitest_sl:

	printf format_slash
	printf format_tab
	printf format_slashn
	printf format_slashv
	printf format_slash0
	printf division
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

section .data

	format_l:
	db "\n\n\n------------UNITEST FOR '%%l' AND '%%v'----------\nP.S.:%%l is equivalent of %%ll in C, %%v - of %%llu\n\n\n", 0
	format_l1: 
	db "%d: 1 in ll and llu: '%l', '%v'\n", 0
	format_l2: 
	db "%d: -1 in ll and llu: '%l', '%v'\n", 0
	format_l3: 
	db "%d: (1 << 63)-1 = max_long= '%l', '%v'\n", 0
	format_l4: 
	db "%d: (1 << 63) '%l', '%v'\n", 0

	format_l5:
	db "%d: (1 << 64)-1 '%l', '%v'\n", 0

_unitest_l:

	printf format_l

	printf format_l1, 1, 1, 1

	printf format_l2, 2, -1, -1

	mov rax, 1
	shl rax, 63
	dec rax
	printf format_l3, 3, rax, rax


	mov rax, 1
	shl rax, 63
	printf format_l4, 4, rax, rax

	mov rax, 0
	not rax
	printf format_l5, 5, rax, rax

ret

section .data

	format_bin:
	db "\n\n\n------------UNITEST FOR DEGREES OF TWO----------\n\n", 0
	format_bin1: 
	db "2:\t%b\n4:\t%q\n8:\t%o\n16:\t%x\n16_p:\t%p\n32:\t%f\n64:\t%i\n\n\n", 0
	format_bin2: 
	db "2:\t%b\n4:\t%q\n8:\t%o\n16:\t%x\n16_c:\t%h\n16_p:\t%p\n32:\t%f\n64:\t%i\n\n", 0

section .text
_unitest_bin:

	printf format_bin

	mov rax, 27
	;printf format_bin1, rax, rax, rax, rax, rax, rax, rax

	mov rax, -1d
	printf format_bin2, rax, rax, rax, rax, rax, rax, rax, rax, rax

ret

_big_text:

	printf onegin

ret