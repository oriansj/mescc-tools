;; Copyright (C) 2017 Jeremiah Orians
;; This file is part of stage0.
;;
;; stage0 is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; stage0 is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with stage0.  If not, see <http://www.gnu.org/licenses/>.

	section .text
	global _start

	;; Register usage:
	;; RAX, RSI, RDI => Temps
	;; R13 => MALLOC
	;; R14 => Output_file
	;; R15 => Input_file

	;; Struct TYPE format: (size 56)
	;; NEXT => 0
	;; SIZE => 8
	;; OFFSET => 16
	;; INDIRECT => 24
	;; MEMBERS => 32
	;; TYPE => 40
	;; NAME => 48

	;; Struct TOKEN_LIST format: (size 40)
	;; NEXT => 0
	;; LOCALS/PREV => 8
	;; S => 16
	;; TYPE => 24
	;; ARGS/DEPTH => 32

; Where the ELF Header is going to hit
; Simply jump to _start
; Our main function
_start:
	pop rax                     ;·Get·the·number·of·arguments
	pop rdi                     ;·Get·the·program·name
	pop rdi                     ;·Get·the·actual·input name
	mov rsi, 0                  ;·prepare·read_only
	mov rax, 2                  ;·the·syscall·number·for·open()
	syscall                     ; Now open that damn file
	mov r15, rax                ; Preserve the file pointer we were given

	pop rdi                     ;·Get·the·actual·output name
	mov rsi, 577                ; Prepare file as O_WRONLY|O_CREAT|O_TRUNC
	mov rdx, 384                ; Prepare file as RW for owner only (600 in octal)
	mov rax, 2                  ;·the·syscall·number·for·open()
	syscall                     ; Now open that damn file
	cmp rax, 0                  ; Check for missing output
	jg _start_out               ; Have real input
	mov rax, 1                  ; Use stdout

_start_out:
	mov r14, rax                ; Preserve the file pointer we were given

	mov rax, 12                 ; the Syscall # for SYS_BRK
	mov rdi, 0                  ; Get current brk
	syscall                     ; Let the kernel do the work
	mov r13, rax                ; Set our malloc pointer
	mov rax, 0                  ; HEAD = NULL
	call read_all_tokens        ; Read all tokens
	call Reverse_List           ; Reverse order
 ;	call program                ; Convert into program
	call recursive_output       ; Print core program

Done:
	; program completed Successfully
	mov rdi, 0                  ; All is well
	mov rax, 0x3c               ; put the exit syscall number in eax
	syscall                     ; Call it a good day


;; read_all_tokens function
;; Recieves FILE* in R15 and Token_List* in RAX
;; Tokenizes all input and returns updated list in RAX
;; Returns TOKEN in RAX
;; Uses RAX for C
read_all_tokens:
	mov [Token], rax
	call fgetc
read_all_tokens_loop:
	cmp rax, -4                 ; Check for EOF
	je read_all_tokens_done     ; Stop if found
	call get_token              ; Read all tokens
	jmp read_all_tokens_loop    ; Loop
read_all_tokens_done:
	mov rax, [Token]
	ret


	;; get_token function
	;; Recieves INT in RAX and FILE* in R15
	;; Makes a list of TOKEN_LIST
	;; C and STRING_INDEX are stored in memory, RCX is used for S and RDX is used for current
	;; Returns C in RAX
get_token:
	push rbx                    ; Protect RBX
	push rcx                    ; Protect RCX
	push rdx                    ; Protect RDX

	mov [C], rax                ; Set C

	mov rax, 40                 ; Malloc CURRENT
	call malloc                 ; Get Pointer
	mov rdx, rax                ; Set CURRENT

	mov rax, 256                ; Malloc the string
	call malloc                 ; Get pointer to S
	mov rcx, rax                ; Set S
	mov [rdx+16], rcx           ; CURRENT->S = S
reset:
	mov [string_index], rcx     ; S[0]
	mov rax, [C]                ; Using C

	call clear_white_space      ; Clear WhiteSpace
	mov [C], rax                ; Set C

	cmp rax, -4                 ; Check for EOF
	je get_token_abort          ; if EOF abort

	cmp rax, 35                 ; Check for '#'
	jne get_token_alpha         ; Nope

	;; Deal with # line comments
	call purge_macro            ; Let it handle it
	mov [C], rax                ; Set C
	jmp reset                   ; Try again

get_token_alpha:
	mov rax, [C]                ; Send C
	mov rbx, alphas             ; Get alphanumerics
	call In_Set                 ; See if in set
	cmp rax, 1                  ; IF TRUE
	jne get_token_symbol        ; Otherwise

	;; Store keywords
	mov rax, [C]                ; Send C
	call preserve_keyword       ; Store
	mov [C], rax                ; Set C
	jmp get_token_done          ; Be done with this token

get_token_symbol:
	mov rax, [C]                ; Send C
	mov rbx, symbols            ; Get symbols
	call In_Set                 ; See if in set
	cmp rax, 1                  ; IF TRUE
	jne get_token_strings       ; Otherwise

	;; Store symbols
	mov rax, [C]                ; Send C
	call preserve_symbol        ; Store
	mov [C], rax                ; Set C
	jmp get_token_done          ; Be done with this token

get_token_strings:
	mov rax, [C]                ; Send C
	mov rbx, strings            ; Get symbols
	call In_Set                 ; See if in set
	cmp rax, 1                  ; IF TRUE
	jne get_token_comment       ; Otherwise

	;; Store String
	mov rax, [C]                ; Send C
	call consume_word           ; Store
	mov [C], rax                ; Set C
	jmp get_token_done          ; Be done with this token

get_token_comment:
	mov rax, [C]                ; Send C
	cmp rax, 47                 ; IF '/' == C
	jne get_token_else          ; Otherwise

	call consume_byte           ; Hope it just is '/'
	mov [C], rax                ; Set C

	cmp rax, 42                 ; IF '*' we have '/*'
	jne get_token_comment_line  ; Check for '//'

	;; Deal with /* block comments */
	call fgetc                  ; get next C
	mov [C], rax                ; Set C
get_token_comment_block_outer:
	mov rax, [C]                ; Using C
	cmp rax, 47                 ; IF '/' != C
	je get_token_comment_block_done ; be done

get_token_comment_block_inner:
	mov rax, [C]                ; Using C
	cmp rax, 42                 ; IF '*' != C
	je get_token_comment_block_iter ; jump over

	;; Deal with inner loop
	call fgetc                  ; get next C
	mov [C], rax                ; Set C
	jmp get_token_comment_block_inner ; keep going

get_token_comment_block_iter:
	call fgetc                  ; get next C
	mov [C], rax                ; Set C
	jmp get_token_comment_block_outer

get_token_comment_block_done:
	call fgetc                  ; get next C
	mov [C], rax                ; Set C
	jmp reset                   ; throw away, try again

get_token_comment_line:
	cmp rax, 47                 ; IF '/' we have //
	jne get_token_done          ; keep if just '/'

	;; Deal with // line comment
	call fgetc                  ; drop to match
	mov [C], rax                ; Set C
	jmp reset                   ; throw away, try again

get_token_else:
	mov rax, [C]                ; Send C
	call consume_byte
	mov [C], rax                ; Set C

get_token_done:
	mov rax, [Token]            ; TOKEN
	mov [rdx+8], rax            ; CURRENT->PREV = TOKEN
	mov [rdx], rax              ; CURRENT->NEXT = TOKEN
	mov [Token], rdx            ; TOKEN = CURRENT

get_token_abort:
	pop rdx                     ; Restore RDX
	pop rcx                     ; Restore RCX
	pop rbx                     ; Restore RBX
	mov rax, [C]                ; Return C
	ret


;; Malloc isn't actually required if the program being built fits in the initial memory
;; However, it doesn't take much to add it.
;; Requires R13 to be initialized and RAX to have the number of desired bytes
malloc:
	mov rdi, r13                ; Using the current pointer
	add rdi, rax                ; Request the number of desired bytes
	mov rax, 12                 ; the Syscall # for SYS_BRK
	push rcx                    ; Protect rcx
	push r11                    ; Protect r11
	syscall                     ; call the Kernel
	pop r11                     ; Restore r11
	pop rcx                     ; Restore rcx
	mov rax, r13                ; Return pointer
	mov r13, rdi                ; Update pointer
	ret


;; clear_white_space function
;; Recieves INT C in RAX and FILE* in R15
;; Returns first non-whitespace char in RAX
clear_white_space:
	cmp rax, 32                 ; Check for ' '
	je clear_white_space_wipe   ; wipe it out

	cmp rax, 10                 ; Check for '\n'
	je clear_white_space_wipe   ; wipe it output

	cmp rax, 9                  ; Check for '\t'
	jne clear_white_space_done  ; looks like non-whitespace

clear_white_space_wipe:
	call fgetc                  ; Read a new byte
	cmp rax, -4                 ; Check for EOF
	je clear_white_space_done   ; Short circuit
	jmp clear_white_space       ; iterate

clear_white_space_done:
	ret



;; In_Set function
;; Recieves Char C in RAX and CHAR* in RBX
;; Returns 1 if true, zero if false in RAX
In_Set:
	push rbx                    ; Protect RBX
	push rcx                    ; Protect RCX
In_Set_loop:
	mov cl, [rbx]               ; Read char
	movzx rcx, cl               ; Zero extend it

	cmp rax, rcx                ; See if they match
	je In_Set_True              ; return true

	cmp rcx, 0                  ; Check for NULL
	je In_Set_False             ; return false

	add rbx, 1                  ; s = s + 1
	jmp In_Set_loop             ; Keep looping

In_Set_True:
	mov rax, 1                  ; Set True
	pop rcx                     ; Restore RCX
	pop rbx                     ; Restore RBX
	ret

In_Set_False:
	mov rax, 0                  ; Set FALSE
	pop rcx                     ; Restore RCX
	pop rbx                     ; Restore RBX
	ret

alphas:
	db 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 95, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 0

symbols:
	db 60, 61, 62, 124, 38, 33, 45, 0

strings:
	db 34, 39, 0


;; purge_macro function
;; Recieves CH in RAX
;; Reads chars until Line feed is read
;; returns line feed
purge_macro:
	call fgetc                  ; read next char
	cmp rax, 10                 ; Check for '\n'
	jne purge_macro             ; Keep going
	ret


;; preserve_keyword function
;; Recieves INT C in RAX
;; collects all chars in keyword
;; Returns C in RAX
;; Uses RCX for INT C
preserve_keyword:
	push rbx                    ; Protect RBX
	push rcx                    ; Protect RCX
	mov rcx, rax                ; Setup C
	mov rbx, alphas             ; Concerning ourselves with "abc.."
preserve_keyword_loop:
	call In_Set                 ; Check if alphanumerics
	cmp rax, 1                  ; IF TRUE
	jne preserve_keyword_label  ; Otherwise check for label

	mov rax, rcx                ; Pass C
	call consume_byte           ; consume that byte
	mov rcx, rax                ; Update C
	jmp preserve_keyword_loop   ; keep looping

preserve_keyword_label:
	mov rax, rcx                ; Fix return
	cmp rax, 58                 ; Check for ':'
	jne preserve_keyword_done   ; be done

	;; Fix our goto label
	call fixup_label            ; Fix the label
	mov rax, 32                 ; Return Whitespace

preserve_keyword_done:
	pop rcx                     ; Restore RCX
	pop rbx                     ; Restore RBX
	ret


;; preserve_symbol function
;; Recieves INT C in RAX
;; collects all chars in symbol
;; Returns C in RAX
;; Uses RCX for INT C
preserve_symbol:
	push rbx                    ; Protect RBX
	push rcx                    ; Protect RCX
	mov rcx, rax                ; Setup C
	mov rbx, symbols            ; Concerning ourselves with "<=>.."
preserve_symbol_loop:
	call In_Set                 ; Check if alphanumerics
	cmp rax, 1                  ; IF TRUE
	jne preserve_symbol_done    ; Otherwise be done

	mov rax, rcx                ; Pass C
	call consume_byte           ; consume that byte
	mov rcx, rax                ; Update C
	jmp preserve_symbol_loop    ; keep looping

preserve_symbol_done:
	mov rax, rcx                ; Fix return
	pop rcx                     ; Restore RCX
	pop rbx                     ; Restore RBX
	ret


	;; consume_word function
	;; recieves INT C in RAX
	;; returns INT C in RAX
	;; Uses RAX for C, RBX for FREQ and RCX for ESCAPE
consume_word:
	push rbx                    ; Protect RBX
	push rcx                    ; Protect RCX
	mov rbx, rax                ; FREQ = C
	mov rcx, 0                  ; ESCAPE = FALSE
consume_word_loop:
	cmp rcx, 0                  ; IF !ESCAPE
	jne consume_word_escape     ; Enable escape

	cmp rax, 92                 ; if '\\'
	jne consume_word_iter       ; keep state

	mov rcx, 1                  ; ESCAPE = TRUE
	jmp consume_word_iter       ; keep going

consume_word_escape:
	mov rcx, 0                  ; ESCAPE = FALSE

consume_word_iter:
	call consume_byte           ; read next char

	cmp rcx, 0                  ; IF ESCAPE
	jne consume_word_loop       ; keep looping

	cmp rax, rbx                ; IF C != FREQ
	jne consume_word_loop       ; keep going

	call fgetc                  ; return next char
	pop rcx                     ; Restore RCX
	pop rbx                     ; Restore RBX
	ret


;; consume_byte function
;; Recieves INT C in RAX
;; Inserts C into string S, updates String S
;; Returns Next char in RAX
consume_byte:
	push rbx                    ; Protect RBX
	mov rbx, [string_index]     ; S[0]
	mov [rbx], al               ; S[0] = C
	add rbx, 1                  ; S = S + 1
	mov [string_index], rbx     ; Update S
	call fgetc
	pop rbx                     ; Restore RBX
	ret


;; fixup_label function
;; Recieves S in RCX
;; prepends ':' to string and returns registers un changed
;; Uses RAX for HOLD, RBX for PREV and RCX for S[0]
fixup_label:
	push rax                    ; Protect RAX
	push rbx                    ; Protect RBX
	push rcx                    ; Protect RCX
	mov rax, 58                 ; HOLD = ':'
	mov rcx, [rdx+16]           ; HOLD_STRING[0]
fixup_label_loop:
	mov rbx, rax                ; PREV = HOLD
	mov al, [rcx]               ; HOLD = HOLD_STRING[I]
	movzx rax, al               ; make useful
	mov [rcx], bl               ; HOLD_STRING[I] = PREV
	add rcx, 1                  ; I = I + 1
	cmp rax, 0                  ; IF NULL == HOLD
	jne fixup_label_loop        ; Keep looping

	pop rcx                     ; Restore RCX
	pop rbx                     ; Restore RBX
	pop rax                     ; Restore RAX
	ret


;; fgetc function
;; Recieves FILE* in R15
;; Returns -4 (EOF) or char in RAX
fgetc:
	mov rax, -4                 ; Put EOF in rax
	push rax                    ; Assume bad (If nothing read, value will remain EOF)
	lea rsi, [rsp]              ; Get stack address
	mov rdi, r15                ; Where are we reading from
	mov rax, 0                  ; the syscall number for read
	push rdx                    ; Protect RDX
	mov rdx,  1                 ; set the size of chars we want
	push rcx                    ; Protect RCX
	push r11                    ; Protect R11
	syscall                     ; call the Kernel
	pop r11                     ; Restore R11
	pop rcx                     ; Restore RCX
	pop rdx                     ; Restore RDX
	pop rax                     ; Get either char or EOF
	cmp rax, -4                 ; Check for EOF
	je fgetc_done               ; Return as is
	movzx rax, al               ; Make it useful
fgetc_done:
	ret


;; Reverse_List function
;; Recieves List in RAX
;; Returns the list reversed in RAX
Reverse_List:
	push rbx                    ; Protect RBX
	push rcx                    ; Protect RCX
	mov rbx, rax                ; Set HEAD
	mov rax, 0                  ; ROOT = NULL
Reverse_List_Loop:
	cmp rbx, 0                  ; WHILE HEAD != NULL
	je Reverse_List_Done        ; Stop otherwise

	mov rcx, [rbx]              ; NEXT = HEAD->NEXT
	mov [rbx], rax              ; HEAD->NEXT = ROOT
	mov rax, rbx                ; ROOT = HEAD
	mov rbx, rcx                ; HEAD = NEXT
	jmp Reverse_List_Loop       ; Keep Going

Reverse_List_Done:
	pop rcx                     ; Restore RCX
	pop rbx                     ; Restore RBX
	ret


;; recursive_output function
;; Recieves list in RAX
;; walks the list and prints the I->S for all nodes followed by newline
;; Uses RBX for I
recursive_output:
	push rbx                    ; Protect RBX
	push rcx                    ; Protect RCX
	mov rbx, rax                ; I = Head
recursive_output_Loop:
	mov rax, [rbx + 16]         ; Using S
	call File_Print             ; Print it
	mov rax, 10                 ; NEWLINE
	call fputc                  ; Append it

	mov rbx, [rbx]              ; Iterate to next Token
	cmp rbx, 0                  ; Check for NULL
	jne recursive_output_Loop   ; Otherwise keep looping

	pop rcx                     ; Restore RCX
	pop rbx                     ; Restore RBX
	ret


;; File_Print function
;; Recieves CHAR* in RAX
;; calls fputc for every non-null char
File_Print:
	push rbx                    ; Protect RBX
	push rcx                    ; Protect RCX
	mov rbx, rax                ; Protect S
	cmp rax, 0                  ; Protect against nulls
	je File_Print_Done          ; Simply don't try to print them
File_Print_Loop:
	mov al, [rbx]               ; Read byte
	movzx rax, al               ; zero extend
	cmp rax, 0                  ; Check for NULL
	je File_Print_Done          ; Stop at NULL

	call fputc                  ; write it
	add rbx, 1                  ; S = S + 1
	jmp File_Print_Loop         ; Keep going

File_Print_Done:
	pop rcx                     ; Restore RCX
	pop rbx                     ; Restore RBX
	ret


;; fputc function
;; recieves CHAR in RAX and FILE* in R14
;; writes char and returns
fputc:
	push rax                    ; We are writing rax
	lea rsi, [rsp]              ; Get stack address
;	mov rdi, r14                ; Write to target file
	mov rdi, 1
	mov rax, 1                  ; the syscall number for write
	push rdx                    ; Protect RDX
	mov rdx, 1                  ; set the size of chars we want
	push rcx                    ; Protect RCX
	push r11                    ; Protect R11
	syscall                     ; call the Kernel
	pop r11                     ; Restore R11
	pop rcx                     ; Restore RCX
	pop rdx                     ; Restore RDX
	pop rax                     ; Restore stack
	ret

section .data
Token:
	dq 0

C:
	dq 0

string_index:
	dq 0
