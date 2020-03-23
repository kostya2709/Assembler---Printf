
section .bss
STD_OUT equ 1
WRITE 	equ 4


section .text

	global _printf

	
section .data
	buffer_ptr: dq $
	printf_buffer: times 128d db 0 

section .text 
	
;╔════════════════════════════════════════════════════════════════════════╗
;║		This macros makes function _printf more convenient to use.        ║
;║	                                                                      ║
;║    	This macros expects the word 'printf', then the pointer to the    ║
;║	format line, and then arguments of the function in the order like     ║
;║	in the format line.                                                   ║
;║                                                                        ║
;║	Some features:                                                        ║
;║		%0 - number of arguments that macros received                     ║
;║		%rep (n)- repeats the commands before %endrep (n) times           ║
;║		%rotate - moves numbers of the received elements: %1 ⇒ %2 etc.    ║
;║                                                                        ║
;║		All arguments are pushed in the stack with size 8. RSP-register   ║
;║	is moved backwards, so the pushed registers become trash.             ║
;║                                                                        ║
;╚════════════════════════════════════════════════════════════════════════╝
%macro printf 1-*
	%rep %0
		%rotate -1
		push %1
	%endrep
	call _printf
	add rsp, 8 * %0
%endmacro

;╔═══════════════════════════════════_PRINTF══════════════════════════════════════════╗
;║																					  ║
;║		This function is the equivalent of the function "printf" in the standart      ║
;║	C library <stdio.h>. This function uses a special format string, which consists   ║
;║	of quotes, some text and format symbols inside, terminating symbol '\0'.          ║
;║	Arguments arg_1, ..., arg_n are not neccessary, they are inserted instead of      ║
;║	format symbols.                                                                   ║
;║		                                                                              ║
;║		WARNING! The number of these arguments and format symbols MUST be the same.   ║
;║	Otherwise the stack can be damaged.                                               ║
;║                                                                                    ║
;║		ARGUMENTS:                                                                    ║
;║						pointer to the format string                                  ║
;║						arg_1                                                         ║
;║						...                                                           ║
;║						arg_n                                                         ║
;║		RETURN:			The number of the arguments really written.                   ║
;║                                                                                    ║
;╚════════════════════════════════════════════════════════════════════════════════════╝

_printf:

	push rbp
	push rsi
	push rdi
	push rax
	mov rbp, rsp
	add rbp, 8	* 5				; rbp is a pointer to the start of arguments
	
	xor r11, r11				; counter of the written variables

	mov ax, cs
	mov ds, ax
	mov es, ax
	
	mov rsi, [rbp]
	mov rdi, printf_buffer
	
	.Printf_Cycle:
	mov al, [rsi]
	cmp al, 0
	je .Printf_End
	
	cmp al, '%'
	jne .next_form
	call _found_format
	jmp .Printf_Cycle
.next_form:
	cmp al, 5ch
	jne	.Printf_Sym
	call _found_slash
	jmp .Printf_Cycle
	
	.Printf_Sym:
	movsb
	jmp .Printf_Cycle
	
	
	.Printf_End:
	mov rax, printf_buffer
	sub rdi, rax
	mov [buffer_ptr], rdi

	mov rax, WRITE		; номер системного вызова "sys_write"
	mov rbx, STD_OUT	; файловый дескриптор stdout
	mov rcx, printf_buffer		; строка
	mov rdx, [buffer_ptr]	; длина строки
	int 0x80

	
	pop rax
	pop rdi
	pop rsi
	pop rbp

	mov rax, r11
ret

_found_format:
	
	inc rsi
	mov al, [rsi]

	cmp al, 'c'
	je .printf_char
	
	cmp al, 'd'
	mov r15, 0
	mov r14, 0
	je .printf_digit

	cmp al, 'u'
	mov r15, 1
	mov r14, 0
	je .printf_digit

	cmp al, 'l'						;ll
	mov r15, 0
	mov r14, 1
	je .printf_digit

	cmp al, 'v'						;llu
	mov r15, 1
	mov r14, 1
	je .printf_digit
	
	cmp al, 'b'				; 2 ^ 1
	mov r10, 1
	mov r14, 0
	je .printf_hex
	
	cmp al, 's'
	je .printf_string

	cmp al, 'x'				; 2 ^ 4
	mov r10, 4
	mov r15, 61h
	mov r14, 0
	je .printf_hex

	cmp al, 'X'				; 2 ^ 4 capitilized
	mov r10, 4
	mov r15, 41h
	mov r14, 0
	je .printf_hex

	cmp al, 'p'				; 2 ^ 4 ptr
	mov r10, 4
	mov r15, 61h
	mov r14, 1
	je .printf_hex

	cmp al, 'o'				; 2 ^ 3
	mov r10, 3
	mov r14, 0
	je .printf_hex

	cmp al, 'f'				; 2 ^ 5
	mov r10, 5
	mov r15, 61h
	mov r14, 0
	je .printf_hex

	cmp al, 'i'				; 2 ^ 6
	mov r10, 6
	mov r15, 61h
	mov r14, 0
	je .printf_hex

	cmp al, 't'				; 2 ^ 2
	mov r10, 2
	mov r14, 0
	je .printf_hex

	cmp al, '%'
	je .printf_percent

	dec r11

	jmp .End

	.printf_char:
	call _Printf_Char
	jmp .End
	
	.printf_digit:
	call _Printf_Digit
	jmp .End

	.printf_bin:
	call _Printf_Bin
	jmp .End
	
	.printf_string:
	call _Printf_String
	jmp .End

	.printf_hex:
	call _Printf_Hex
	jmp .End

	.printf_percent:
	call _Printf_Percent
	dec r11
	jmp .End

.End:
	inc r11
	inc rsi
ret

;/*!Function to print a single symbol
;\return ax
 ;*/
_Printf_Char:

	add rbp, 8
	mov bl, [rbp]
	mov [rdi], bl
	inc rdi

ret

section .data 
temp_buf: times 20d db 0

section .text
_Printf_Digit:

	add rbp, 8h
	mov rax, [rbp]

	mov r8, rax

	cmp r15, 1					; 1 if unsigned, else signed
	je .Pos
	call _Is_Positive
	je .Pos
	neg r8
	mov byte [rdi], '-'
	inc rdi
	.Pos:

	cmp r14, 1					; whether is long
	je .no_shorten
	call _Shorten
.no_shorten:

	mov rax, r8
	mov rbx, 10d
	xor rcx, rcx

	.Cycle:
	xor rdx, rdx
	div rbx
	add rdx, 30h						;остаток
	inc rcx
	mov byte [temp_buf + rcx], dl

	cmp rax, 0
	ja .Cycle 

	.Write_buf:
	mov rax, [temp_buf + rcx]
	mov byte [rdi], al
	inc rdi
	loop .Write_buf 

.End:
ret



_Printf_Bin:

	add rbp, 8
	mov rbx, [rbp]
	mov r8, 1
	shl r8, 63
	mov rcx, 64
	mov rdx, 0
	
	cmp rbx, 0h
	jne .Cycle
	mov byte [rdi], 30h
	inc rdi
	jmp .End
	
	.Cycle:
	mov rax, rbx
	and rax, r8
	shr rax, 63
	add rdx, rax
	add rax, 30h
	
	cmp rdx, 0
	je .Skip_Write
	mov [rdi], al
	inc rdi
	.Skip_Write:
	shl rbx, 1
	loop .Cycle



.End:
ret

_Printf_String:

	add rbp, 8
	mov rbx, [rbp]

	.Cycle:
	mov al, [rbx]
	cmp al, 0
	je .End
	mov [rdi], al
	inc rdi
	inc rbx
	jmp .Cycle

.End:
ret

_Printf_Hex:

	push rcx

	add rbp, 8
	mov rbx, [rbp]

	xor r8, r8

	cmp r14, 0						; if (r14 == 1) it is ptr
	je .Not_ptr						; ptr consists of 8 bytes
	mov word [rdi], "0x"			; meanwhile the others of 4 bytes
	add rdi, 2
	shl rbx, 31d					; deletes 4 bytes
	shr rbx, 31d

.Not_ptr:


	mov rcx, r10					; in "r10" - "length" of one symbol
	mov r14, 64d			
	sub r14, rcx					;in "r14" number of shifts while using the mask

	mov r9, 1
.create_mask:
	shl r9, 1
	loop .create_mask
	dec r9

	mov rcx, r14
.left_mask_shift:
	shl r9, 1
	loop .left_mask_shift			; there is the mask in "r9" 

	xor rdx, rdx					; number of iterations = 64 bits / "length" of one symbol
	mov rax, 64d
	div r10

	cmp rdx, 0
	je .it_divides
	mov rcx, rdx					; if 64 doesn't divide "length", let's shorten the number
.delete_useless:
	shl rbx, 1
	loop .delete_useless

.it_divides:
	mov rcx, rax					; in rcx - number of iterations

	cmp rbx, 0
	jne .Cycle
	mov byte [rdi], 30h
	inc rdi
	jmp .End



.Cycle:

	mov rax, r9
	and rax, rbx

	mov r13, rcx
	mov rcx, r14
.right_mask_shift:
	shr rax, 1
	loop .right_mask_shift		; moves the mask with the value to the little ranks

	mov rcx, r13

	add r8, rax
	cmp r8, 0
	je .No_Sym					; uses to delete forward zeros
	
	cmp rax, 10d
	jb .printf_digit
	sub rax, 10d
	add rax, r15				; r15 uses to choose whether the letter is capitalized
	jmp .next
.printf_digit:
	add rax, 30h

.next:
	mov byte [rdi], al
	inc rdi 

.No_Sym:

	mov r13, rcx
	mov rcx, r10
.left_number_shift:
	shl rbx, 1 
	loop .left_number_shift				;decreases the value of the number

	mov rcx, r13
	
	loop .Cycle

.End:
pop rcx
ret

_Printf_Percent:

	mov byte [rdi], '%'
	inc rdi
ret

_Is_Positive:

	mov r9, 1
	cmp r14, 1
	je .long
	shl r9, 31d
	jmp .next
.long:
	shl r9, 63d
.next:
	and r9, r8
	cmp r9, 0			;checked the first byte
ret

_Shorten:

	mov r9, 1
	shl r9, 20h
	dec r9			
	and r8, r9 			;deleted last 4 bytes
ret

_found_slash:

inc rsi
mov al, [rsi]
inc rsi

cmp al, "n"
je .found_n

cmp al, "t"
je .found_t

cmp al, "v"
je .found_v

cmp al, 5ch
je .found_sl

dec rdi

.found_t:
	mov byte [rdi], 9h
	jmp .End
.found_n:
	mov byte [rdi], 0ah
	jmp .End
.found_v:
	mov byte [rdi], 0bh
	jmp .End
.found_sl:
	mov byte [rdi], 5ch
	jmp .End
.End:
inc rdi
ret