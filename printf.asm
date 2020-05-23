
section .bss
STD_OUT equ 1
WRITE     equ 4


section .text

    global _printf

    
section .data
    printf_buffer: times 101h db 30h              ; The main buffer for _printf.
    canary: db 0

section .text     

;╔════════════════════════════════════════════════════════════════════════╗
;║        This macros makes function _printf more convenient to use.      ║
;║                                                                        ║
;║        This macros expects the word 'printf', then the pointer to the  ║
;║    format line, and then arguments of the function in the order like   ║
;║    in the format line.                                                 ║
;║                                                                        ║
;║    Some features:                                                      ║
;║        %0 - number of arguments that macros received                   ║
;║        %rep (n)- repeats the commands before %endrep (n) times         ║
;║        %rotate - moves numbers of the received elements: %1 ⇒ %2 etc.  ║
;║                                                                        ║
;║        All arguments are pushed in the stack with size 8. RSP-register ║
;║    is moved backwards, so the pushed registers become trash.           ║
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

;Some additional macroses:

%define cur_arg     rbp + r11 * 8 + 2 * 8 
%define arg_count   r11
%define source      rsi
%define dest        rdi

%macro PUSHALL 0
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
%endmacro

%macro POPALL 0
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
%endmacro


%macro puts 1                           ; A supplementary macros. It prints a string. 
section .data
    %%string: db %1, 0
    %%length: db $ - %%string
section .text
    PUSHALL
    mov rax, WRITE                  	; The number of the system call "sys_write".
    mov rbx, STD_OUT                	; The file descriptor "stdout".
    mov rcx, %%string          	        ; Pointer to the buffer.
    mov dl, [%%length]                  ; RDX = RDI - RAX = number of symbols written into the buffer.
	int 0x80
    POPALL
%endmacro

%macro write_buf 1
    mov byte [rdi], %1						; Move the necessary character to the destination address.
    inc rdi								    ; Increment the destination register.
    add dl, 1                               ; Increment the printf_buffer counter.
    jnc %%next                              ; If overflow is not detected, move further.
    ;puts "THE BUFFER IS FULL"              ; To test how buffer overflow control works.
    call _write_result                      ; If overflow is detected, let's write down the buffer.
%%next:                                     ; If overflow is not detected, move further.
%endmacro


_check_canary:                              ; This function checks whether the byte after
    push rax                                ; printf_buffer is damaged.
    mov al, byte [canary]
    cmp al, 0
    je .end
    puts "Error! The memory is damaged!\n"
    mov rax, 1		                        ; System call "sys_exit"
	mov rbx, 0		                        ; Error number
	int 0x80
.end:    
    pop rax
ret

%macro jecall 2-4
    cmp byte [rsi], %1
    jne %%_next
    %if %0 > 2
        mov r14, %3
        mov r15, %4
    %endif
    call %2
    jmp _format_endian
    %%_next:
%endmacro

%macro jmpcall 1-3
    %if %0 > 1
        mov r14, %2
        mov r15, %3
    %endif
    call %1
    jmp _format_endian
%endmacro

;╔═══════════════════════════════════_PRINTF════════════════════════════════════════════╗
;║                                                                                      ║
;║        This function is the equivalent of the function "printf" in the standart      ║
;║    C library <stdio.h>. This function uses a special format string, which consists   ║
;║    of quotes, some text and format symbols inside, terminating symbol '\0'.          ║
;║    Arguments arg_1, ..., arg_n are not neccessary, they are inserted instead of      ║
;║    format symbols.                                                                   ║
;║                                                                                      ║
;║        WARNING! The number of these arguments and format symbols MUST be the same.   ║
;║    Otherwise the stack can be damaged.                                               ║
;║                                                                                      ║
;║        WARNING! Some registers are used for special needs:                           ║
;║                                                                                      ║
;║                rdx - number of symbols in printf_buffer - to detect buffer overflow. ║
;║                r11 - number of the current argument (has a shell: CUR_ARG = rbp+r11).║                         
;║                r13 - the mask in Printf_Hex function.                                ║
;║                r14 & r15 - arguments for some auxilary functions.                    ║
;║                                                                                      ║
;║          ARGUMENTS:                                                                  ║
;║                        pointer to the format string                                  ║
;║                        arg_1                                                         ║
;║                        ...                                                           ║
;║                        arg_n                                                         ║
;║                                                                                      ║
;║           SUPPORTED FORMAT SYMBOLS:                                                  ║
;║                                                                                      ║
;║   '%c' - uses to write a one byte symbol.                                            ║
;║   '%s' - uses to write a string, ending with 0. A pointer to the string is expected. ║
;║   '%%' - uses to write '%' itself.                                                   ║
;║                                                                                      ║
;║   '%d' - uses to write a 4-bytes signed number.                                      ║
;║   '%u' - uses to write a 4-bytes unsigned number.                                    ║
;║   '%l' - uses to write a 8-bytes signed number.                                      ║
;║   '%v' - uses to write a 8-bytes unsigned number.                                    ║
;║                                                                                      ║
;║   '%b' - uses to write a 4-bytes number in binary mod         in 2 ^ 1 based system. ║
;║   '%q' - uses to write a 4-bytes number in quaternary mod     in 2 ^ 2 based system. ║
;║   '%o' - uses to write a 4-bytes number in octal mod          in 2 ^ 3 based system. ║
;║   '%x' - uses to write a 4-bytes number in hex mod            in 2 ^ 4 based system. ║
;║   '%X' - uses to write a 4-bytes number in hex mod with capital letters.             ║
;║   '%p' - uses to write a 8-bytes number in hex mod as a pointer.                     ║
;║   '%f' - uses to write a 4-bytes number                       in 2 ^ 5 based system. ║
;║   '%i' - uses to write a 4-bytes number                       in 2 ^ 6 based system. ║           
;║                                                                                      ║
;║          RETURN:         The number of the arguments really written, in register RAX.║
;║                                                                                      ║
;╚══════════════════════════════════════════════════════════════════════════════════════╝
_printf:

    push rbp                    		; Stack frame. We refer to arguments by rbx + n * 8.
    mov rbp, rsp                		; RBX is equal stack pointer RSP.
    
    mov r10, printf_buffer

    xor r11, r11                		; Counter of the written variables.
    xor rdx, rdx                        ; Counter of symbols in the printf_buffer.

    mov rsi, [cur_arg]            		; RSI = pointer to the format string.
    mov rdi, printf_buffer        		; RDI = pointer to the buffer where to write symbols to.

.Printf_Cycle:                	    	; The main cycle of the _printf function.

    mov al, [rsi]                		; al = symbol in format string.
    cmp al, 0                    		; Comparison al with the terminating symbol of the string.
    je Printf_End                		; If the sybol is zero - JMP to the end.
    
    cmp al, '%'                    		; Check whether the symbol is format.
    jne .next_form                		; If not, let's check: maybe it is a slash.
    call _found_format            		; If yes, let's find out what particular symbol is this.
    jmp .Printf_Cycle            		; Having done everything necessary, let's return to the main cycle.

.next_form:                        		; Let's check, whether the symbol is slash.
    cmp al, 5ch                    		; Comparison
    jne .Printf_Sym              	; If not, just print the symbol at last.
    call _found_slash            		; If yes, let's call the function and handle the slash.
    jmp .Printf_Cycle            		; Having done everything necessary, let's return to the main cycle.
    
.Printf_Sym:               		    	; If al is just an ordinary symbol - let's print it!
    ;movsb                        		; Sends a byte from RSI to RDI, increments RSI and RDI.
    write_buf al
    inc rsi
    jmp .Printf_Cycle            		; Jump to the main cycle.
    
    
Printf_End:                				; We jump to this label, if we encountered the terminating symbol.

    call _write_result

    pop rbp                         	; Move RBP to the position before the function was called.
    mov rax, arg_count              	; RAX = R11 = arg_count - number written in the program.
ret

_write_result:

    PUSHALL                             ; Push all necessary registers.
    mov rax, printf_buffer          	; RAX = the start of the buffer
    sub rdi, rax                    	; RDI = current position where to write to.

    mov rax, WRITE                  	; The number of the system call "sys_write".
    mov rbx, STD_OUT                	; The file descriptor "stdout".
    mov rcx, printf_buffer          	; Pointer to the buffer.
    mov rdx, rdi                    	; RDX = RDI - RAX = number of symbols written into the buffer.
	int 0x80                            ; Call the interruption.

    call _check_canary

    POPALL                              ; Pop all necessary registers.
    mov rdi, printf_buffer              ; Return rdi to the start.
    xor rdx, rdx                        ; Drop the printf_buffer counter.
ret




										; There are some useful defines which are used below
                                    	; as arguments in the macros.
%define is_long     	r14				; The parameter of length in Printf_Digital auxilary function.
%define is_unsgn     	r15				; The parameter of sign in Printf_Digital auxilary function.
%define is_ptr        	r14				; The parameter of whether the function Printf_Hex is called to write a pointer.
%define degree        	r15				; The parameter of degree of two in Printf_Hex auxilary function.
%define is_capital      r14				; The parameter of using capital letters in Printf_Hex auxilary function.


;╔═══════════════════════════════════_found_format══════════════════════════════════════╗
;║ This function is used to detect special format, following percent.                   ║
;║ In case if no match was found, the symbol which follows percent, is skipped.         ║
;║                                                                                      ║
;║	ARGUMENTS: some registers are used for arguments in the auxilary functions:         ║
;║					r14 - for being long, being a pointer, or for writting with         ║
;║							capital letters. 											║
;║					r15 - for being unsigned, or to be the necessary degree of two.     ║
;╚══════════════════════════════════════════════════════════════════════════════════════╝
_found_format:
    
    inc rsi  
    xor rbx, rbx                       	; So, '%' was found. Let's check what is next.
    mov bl, byte [rsi]

;    jecall 'c', _Printf_Char			; Function for a char is called.
;    jecall 's', _Printf_String			; Function for a string is called.
;    jecall '%', _Printf_Percent			; Function for a percent is called.
    
										; In the next lines: first argument - r14, the second one - r15
;    jecall 'd', _Printf_Digit, 0, 0 	; Function for a 32-bits signed digit is called.
;    jecall 'u', _Printf_Digit, 0, 1		; Function for a 32-bits unsigned digit is called.
;    jecall 'l', _Printf_Digit, 1, 0		; Function for a 64-bits signed digit is called.
;    jecall 'v', _Printf_Digit, 1, 1		; Function for a 64-bits unsigned digit is called.
    
										; In the next lines numbers are inverted in a particular
										; system based on degree of 2.
;    jecall 'b', _Printf_Hex, 0, 1		; Function for a binary format (2 ^ 1) is called.
;    jecall 'q', _Printf_Hex, 0, 2		; Function for a quaternary format (2 ^ 2) is called.
;    jecall 'o', _Printf_Hex, 0, 3		; Function for an octal format (2 ^ 3) is called.
;    jecall 'h', _Printf_Hex, 0, 4       ; Function for a hex format (2 ^ 4) is called.
;    jecall 'x', _Printf_Hex, 26d, 4     ; Function for a hex format (2 ^ 4) with capital letters is called.
;    jecall 'p', _Printf_Hex, 1, 4       ; Function for a pointer format (2 ^ 4) is called.
;    jecall 'f', _Printf_Hex, 0, 5       ; Function for a 32-nd format (2 ^ 5) is called.
;    jecall 'i', _Printf_Hex, 0, 6       ; Function for a 64-th format (2 ^ 6) is called.


    jecall '%', _Printf_Percent		    ; Function for a percent is called.

    sub bl, 'a'                         ; Get value in range [0, 26]
    jmp [.Jump_Table + rbx * 8]         ; Jump to the adress in Jump_Table

.Jump_Table:

    dq _format_endian                   ; a - letter        || empty
    dq .handle_b                        ; b - letter        || is used
    dq .handle_c                        ; c - letter        || is used
    dq .handle_d                        ; d - letter        || is used
    dq _format_endian                   ; e - letter        || empty
    dq .handle_f                        ; f - letter        || is used
    dq _format_endian                   ; g - letter        || empty
    dq .handle_h                        ; h - letter        || is used
    dq .handle_i                        ; i - letter        || is used
    times 2 dq _format_endian           ; [j, k] - letters  || empty
    dq .handle_l                        ; l - letter        || is used
    times 2 dq _format_endian           ; [m, n] - letter   || empty
    dq .handle_o                        ; o - letter        || is used               
    dq .handle_p                        ; p - letter        || is used
    dq .handle_q                        ; q - letter        || is used
    dq _format_endian                   ; r - letter        || empty
    dq .handle_s                        ; s - letter        || is used
    dq _format_endian                   ; t - letter        || empty
    dq .handle_u                        ; u - letter        || is used
    dq .handle_v                        ; v - letter        || is used
    dq _format_endian                   ; w - letter        || empty
    dq .handle_x                        ; x - letter        || is used


.handle_b:
    jmpcall _Printf_Hex, 0, 1		    ; Function for a binary format (2 ^ 1) is called.

.handle_c:
    jmpcall _Printf_Char			    ; Function for a char is called.

.handle_d:
    jmpcall _Printf_Digit, 0, 0 	    ; Function for a 32-bits signed digit is called.

.handle_f:
    jmpcall _Printf_Hex, 0, 5           ; Function for a 32-nd format (2 ^ 5) is called.

.handle_i:
    jmpcall _Printf_Hex, 0, 6           ; Function for a 64-th format (2 ^ 6) is called.

.handle_h:
    jmpcall _Printf_Hex, 26d, 4         ; Function for a hex format (2 ^ 4) with capital letters is called.

.handle_l:
    jmpcall _Printf_Digit, 1, 0		    ; Function for a 64-bits signed digit is called.

.handle_o:
    jmpcall _Printf_Hex, 0, 3		    ; Function for an octal format (2 ^ 3) is called.

.handle_p:
    jmpcall _Printf_Hex, 1, 4           ; Function for a pointer format (2 ^ 4) is called.

.handle_q:
    jmpcall _Printf_Hex, 0, 2		    ; Function for a quaternary format (2 ^ 2) is called.

.handle_s:
    jmpcall _Printf_String			    ; Function for a string is called.

.handle_u:
    jmpcall _Printf_Digit, 0, 1		    ; Function for a 32-bits unsigned digit is called.

.handle_v:
    jmpcall _Printf_Digit, 1, 1		    ; Function for a 64-bits unsigned digit is called.

.handle_x:
    jmpcall _Printf_Hex, 0, 4           ; Function for a hex format (2 ^ 4) is called.

_format_endian:							; Label of end of the format switch.
.End:
    inc rsi                            	; Let's skip the symbol after '%'.
ret										; Leave the switch.


;╔═══════════════════════════════════_Printf_Char══════════════════════════════════════╗
;║	This function writes a char.                                                       ║
;║	ARGUMENTS: 		cur_arg - character to write.                                      ║
;║					rdi     - where to write to.                                       ║
;╚═════════════════════════════════════════════════════════════════════════════════════╝
_Printf_Char:

    inc arg_count						; Increment the number of the current argument in the stack.
    mov bl, [cur_arg]					; Move the necessary character to register bl.
    write_buf bl
ret

section .data 
temp_buf: times 65d db 0				; A temporary buffer to write digitals.

section .text


_Printf_Digit:

    inc arg_count
    mov rax, [cur_arg]

    cmp is_unsgn, 1                    ; 1 if unsigned, else signed
    je .Pos
    cmp is_long, 1
    je .signed_long
    and eax, eax
    jmp .signed_short
.signed_long:
    and rax, rax
.signed_short:
    js .signed
    jmp .Pos

.signed:
    cmp is_long, 1
    je .min_long
    neg eax
    jmp .min_short
.min_long:
    neg rax
.min_short:
    write_buf '-'

.Pos:
    cmp is_long, 1                    ; whether is long
    je .no_shorten
    shl rax, 32
    shr rax, 32

.no_shorten:
    mov rbx, 10d
    xor rcx, rcx

    .Cycle:
    mov r15, rdx                        ; Put the printf_buffer counter into r15 to use rdx in division.
    xor rdx, rdx
    div rbx
    add rdx, 30h                        ;остаток
    inc rcx
    mov byte [temp_buf + rcx], dl
    mov rdx, r15                        ; Put the printf_buffer counter back to rdx.

    cmp rax, 0
    ja .Cycle 

    call _Write_Reverse

.End:
ret

;==========================================
; This function writes in reversed order.
; Param:
;            temp_buf - ptr to the buffer
;            rcx - number of elements.
;            rdi - where to write to.
; WARNING! Uses register rax.
;==========================================
_Write_Reverse:
    .Write_buf:
    mov al, [temp_buf + rcx]
    write_buf al
    loop .Write_buf 
ret

_Printf_String:

    inc arg_count
    mov rbx, [cur_arg]



.loop:
   mov al, [rbx]
    cmp al, 0
je .End
    write_buf al
    inc rbx
    jmp .loop

.End:
ret
section .data
    alphabet db "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!@"
section .text
%define MASK r13

_Printf_Hex:

    inc arg_count
    mov rbx, [cur_arg]

    cmp is_ptr, 1                   ; if (r14 == 1) it is ptr
    jne .Not_ptr                    ; ptr consists of 8 bytes meanwhile the others of 4 bytes
    write_buf '0'
    write_buf 'x'
    xor is_capital, is_capital
	jmp .After_ptr

.Not_ptr:
    shl rbx, 32
    shr rbx, 32
.After_ptr:
    mov rcx, degree
    mov r13, 1

.create_mask:
    shl r13, 1
    loop .create_mask
    dec r13
    xor rcx, rcx

.Cycle:
    mov rax, MASK
    and rax, rbx

    inc rcx
    add rax, alphabet
	add rax, is_capital              
	mov byte al, [rax]
    mov byte [temp_buf + rcx], al

    push rcx
    mov rcx, r15
.shr_cycle:
    shr rbx, 1
    loop .shr_cycle
    pop rcx
    
    cmp rbx, 0
    jne .Cycle

    call _Write_Reverse
ret

_Printf_Percent:

    write_buf '%'
ret


%macro jescape 2
    cmp al, %1
    jne %%_next
    write_buf %2
    jmp .End
    %%_next:
%endmacro
_found_slash:
    
    inc rsi                             ; Increase rsi to check the symbol after '\'
    mov al, [rsi]                       ; Store th symbol after '\' in al.

    cmp al, '0'                         ; We check a unique case: '\0'
    jne .not_zero                       ; If not, compare further.
    mov byte [rsi], 0                   ; If it is "\0", we put 0 instead of '0', so it will be
    jmp .found_zero                     ; detected on the next iteration of the main _printf cycle.

.not_zero:

    jescape 'a', 07h                    ; BELL - Speaker
    jescape 'b', 08h                    ; BACKSPACE
    jescape 't', 09h                    ; CHARACTER TABULATION - Horizontal tabulaton
    jescape 'n', 0ah                    ; LINE FEED - New line
    jescape 'v', 0bh                    ; LINE TABULATION - Vertical tabulation
    jescape 'f', 0ch                    ; FORM FEED - changes the page
    jescape 'r', 0dh                    ; CARRIAGE RETURN
    jescape 'e', 1bh                    ; ESCAPE 
    jescape 5ch, 5ch                    ; SLASH 

.End:                                   ; We jump there if the symbol after '\' was not zero.
    inc rsi                             ; Increase rsi, as we already managed with the symbol after '\'.
.found_zero:                            ; If '\0' was detected, we do not increase rsi.
ret