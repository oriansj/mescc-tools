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
;	call debug_list             ; Try to figure out what is wrong
	mov [global_token], rax     ; Set global_token
	call program                ; Convert into program
	mov rax, header_string1     ; Our header string
	call File_Print             ; Print it
	mov rax, [output_list]      ; Our output_list
	call recursive_output       ; Print core program
	mov rax, header_string2     ; Our second label
	call File_Print             ; Print it
	mov rax, [globals_list]     ; Our globals
	call recursive_output       ; Get them
	mov rax, header_string3     ; Our final header
	call File_Print             ; Print it
	mov rax, [strings_list]     ; Our strings
	call recursive_output       ; Get them

Done:
	; program completed Successfully
	mov rdi, 0                  ; All is well
	mov rax, 0x3c               ; put the exit syscall number in eax
	syscall                     ; Call it a good day

header_string1:
	db 10, "# Core program", 10, 0

header_string2:
	db 10, ":ELF_data", 10, 10, "# Program global variables", 10, 0

header_string3:
	db 10, "# Program strings", 10, 0

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
	db 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 95, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 0    ; "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz"

symbols:
	db 60, 61, 62, 124, 38, 33, 45, 0     ; "<=>|&!-"

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
;; walks the list and prints the I->S for all nodes backwards
;; Uses RBX for I
recursive_output:
	push rbx                    ; Protect RBX
	push rcx                    ; Protect RCX
	cmp rax, 0                  ; Check for NULL
	je recursive_output_done    ; Skip the work
	mov rbx, rax                ; I = Head

	mov rax, [rbx]              ; Iterate to next Token
	call recursive_output       ; Recurse

	mov rax, [rbx + 16]         ; Using S
	call File_Print             ; Print it

recursive_output_done:
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
	mov rdi, r14                ; Write to target file
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


;; program function
;; recieves nothing, returns nothing
;; Uses RAX for type_size
program:
	;; The binary initialized the globals to null, so we can skip those steps
	push rbx                    ; Protect RBX
	push rcx                    ; Protect RCX

new_type:
	mov rax, [global_token]     ; Using global_token
	cmp rax, 0                  ; Check if NULL
	je program_done             ; Be done if null

	mov rbx, [rax+16]           ; GLOBAL_TOKEN->S
	mov rax, constant           ; "CONSTANT"
	call match                  ; IF GLOBAL_TOKEN->S == "CONSTANT"
	cmp rax, 0                  ; If true
	jne program_else            ; Looks like not a constant

	;; Deal with minimal constant case
	mov rax, [global_token]     ; Using global_token
	mov rax, [rax]              ; global_token->next
	mov [global_token], rax     ; global_token = global_token->next

	mov rax, [rax+16]           ; global_token->S
	mov rbx, 0                  ; NULL
	mov rcx, [global_constant_list] ; global_constant_list
	call sym_declare            ; Declare that constant
	mov [global_constant_list], rax ; global_constant_list = sym_declare(global_token->s, NULL, global_constant_list);

	mov rbx, [global_token]     ; Using global_token
	mov rbx, [rbx]              ; global_token->next
	mov [rax+32], rbx           ; global_constant_list->arguments = global_token->next

	mov rbx, [rbx]              ; global_token->next->next
	mov [global_token], rbx     ; global_token = global_token->next->next;
	jmp new_type                ; go around again

program_else:
	call type_name              ; Figure out the type_size
	cmp rax, 0                  ; IF NULL == type_size
	je new_type                 ; it was a new type

	;; Add to global symbol table
	mov rbx, rax                ; put type_size in the right spot
	mov rax, [global_token]     ; Using global token
	mov rax, [rax+16]           ; global_token->S
	mov rcx, [global_symbol_list] ; Using global_symbol_list
	call sym_declare            ; Declare symbol
	mov [global_symbol_list], rax ; global_symbol_list = sym_declare(global_token->s, type_size, global_symbol_list);
	mov rbx, [global_token]     ; Using global token
	mov rbx, [rbx]              ; global_token->next
	mov [global_token], rbx     ; global_token = global_token->next

	mov rbx, [global_token]     ; Using global token
	mov rbx, [rbx+16]           ; global_token->S
	mov rax, semicolon          ; ";"
	call match                  ; if(match(";", global_token->s))
	cmp rax, 0                  ; If true
	jne program_function        ; looks like not a match

	;; Deal with the global variable
	mov rbx, [globals_list]     ; Using globals_list
	mov rax, program_string_0   ; ":GLOBAL_"
	call emit                   ; Emit it
	mov rbx, rax                ; update globals_list

	mov rax, [global_token]     ; Using global token
	mov rax, [rax+8]            ; global token->prev
	mov rax, [rax+16]           ; global token->prev->s
	call emit                   ; Emit it

	mov rbx, rax                ; update globals_list
	mov rax, program_string_1   ; "\nNOP\n"
	call emit                   ; Emit it
	mov [globals_list], rax     ; update globals_list

	mov rax, [global_token]     ; Using global token
	mov rax, [rax]              ; global_token->next
	mov [global_token], rax     ; global_token = global_token->next
	jmp new_type                ; go around again

program_function:
	mov rbx, [global_token]     ; Using global token
	mov rbx, [rbx+16]           ; global_token->S
	mov rax, open_paren         ; "("
	call match                  ; if(match(";", global_token->s))
	cmp rax, 0                  ; If true
	jne program_error           ; Otherwise deal with error case

	;; Deal with function definition
	call declare_function       ; Lets get the parsing rolling
	jmp new_type                ; Keep looping through functions

program_error:
	;; Deal with the case of something we don't support

program_done:
	pop rcx                     ; Restore RCX
	pop rbx                     ; Restore RBX
	ret

;; Strings needed by the program function
program_string_0: db ":GLOBAL_", 0
program_string_1: db 10, "NOP", 10, 0


;; declare_function function
;; Recieves nothing and returns nothing
;; Sets current function and adds it to the global function list
declare_function:
	push rbx                    ; Protect RBX
	push rcx                    ; Protect RCX
	mov rax, 0                  ; Using NULL
	mov [current_count], rax    ; current_count = 0

	mov rax, [global_token]     ; Using global token
	mov rax, [rax+8]            ; global token->prev
	mov rax, [rax+16]           ; global token->prev->s
	mov rbx, 0                  ; NULL
	mov rcx, [global_function_list] ; global_function_list
	call sym_declare            ; sym_declare(global_token->prev->s, NULL, global_function_list);
	mov [fn_function], rax      ; function = sym_declare(global_token->prev->s, NULL, global_function_list);
	mov [global_function_list], rax ; global_function_list = function

	call collect_arguments      ; collect all of the function arguments

	mov rax, [global_token]     ; Using global token
	mov rax, [rax+16]           ; global token->s
	mov rbx, semicolon          ; ";"
	call match                  ; IF global token->s == ";"
	cmp rax, 0                  ; If true
	jne declare_function_full   ; It was a prototype

	;; Deal with prototypes
	mov rax, [global_token]     ; Using global token
	mov rax, [rax]              ; global token->next
	mov [global_token], rax     ; global token = global token->next
	jmp declare_function_done   ; Move on

declare_function_full:
	;; Deal will full function definitions
	mov rax, declare_function_string_0 ; "# Defining function "
	call emit_out               ; emit it

	mov rax, [fn_function]      ; function
	mov rax, [rax+16]           ; function->s
	call emit_out               ; emit it

	mov rax, declare_function_string_1 ; "\n:FUNCTION_"
	call emit_out               ; emit it

	mov rax, [fn_function]      ; function
	mov rax, [rax+16]           ; function->s
	call emit_out               ; emit it

	mov rax, declare_function_string_3 ; "\n"
	call emit_out               ; emit it

	call statement              ; Recursively get the function pieces

	mov rax, [output_list]      ; output
	mov rax, [rax+16]           ; output->s
	mov rbx, declare_function_string_2 ; "RETURN\n"
	call match                  ; IF output->s == "RETURN\n"
	cmp rax, 0                  ; If true we can skip adding it
	je declare_function_done    ; otherwise we need to add it

	;; Add the return to the end of a function lacking a return;
	mov rax, declare_function_string_2 ; "RETURN\n"
	call emit_out               ; emit it

declare_function_done:
	pop rcx                     ; Restore RCX
	pop rbx                     ; Restore RBX
	ret


declare_function_string_0: db 35, " Defining function ", 0
declare_function_string_1: db 10, ":FUNCTION_", 0
declare_function_string_2: db "RETURN", 10, 0
declare_function_string_3: db 10, 0


;; collect_arguments function
;; Recieves nothing
;; Returns Nothing
;; Adds arguments to the function definition
;; holds struct type* type_size in RCX, then replace with struct token_list* a in RCX when type_size is used
collect_arguments:
	push rbx                    ; Protect RBX
	push rcx                    ; Protect RCX
	mov rax, [global_token]     ; Using global_token
	mov rax, [rax]              ; global_token->next
	mov [global_token], rax     ; global_token = global_token->next
collect_arguments_loop:
	mov rbx, [global_token]     ; Using global_token
	mov rbx, [rbx+16]           ; global_token->S
	mov rax, close_paren        ; ")"
	call match                  ; IF global_token->S == ")"
	cmp rax, 0                  ; we reached the end
	je collect_arguments_done   ; be done

	;; deal with the case of there are arguments
	call type_name              ; Get the type
	mov rcx, rax                ; put type_size safely out of the way

	mov rbx, [global_token]     ; Using global_token
	mov rbx, [rbx+16]           ; global_token->S
	mov rax, close_paren        ; ")"
	call match                  ; IF global_token->S == ")"
	cmp rax, 0                  ; is a foo(int, char,void) case
	je collect_arguments_common ; deal with commas

	;; Trying second else
	mov rbx, [global_token]     ; Using global_token
	mov rbx, [rbx+16]           ; global_token->S
	mov rax, comma              ; ","
	call match                  ; IF global_token->S == ","
	cmp rax, 0                  ; then deal with the common
	je collect_arguments_common ; case of commas between arguments

	;; deal with foo(int a, char b)
	mov rax, [global_token]     ; Using global_token
	mov rax, [rax+16]           ; global_token->S
	mov rbx, rcx                ; put type_size in the right place
	mov rcx, [fn_function]      ; Using function
	mov rcx, [rcx+32]           ; function->args
	call sym_declare            ; sym_declare(global_token->s, type_size, function->arguments);
	mov rcx, rax                ; put a in a safe place

	mov rax, [fn_function]      ; Using function
	mov rax, [rax+32]           ; function->args
	cmp rax, 0                  ; IF function->args == NULL
	jne collect_arguments_another ; otherwise it isn't the first

	;; Deal with the case of first argument in the function
	mov rax, -4                 ; -4
	mov [rcx+32], rax           ; a->depth = -4
	jmp collect_arguments_next  ; get to next

collect_arguments_another:
	;; deal with the case of non-first arguments
	mov rax, [fn_function]      ; Using function
	mov rax, [rax+32]           ; function->args
	mov rax, [rax+32]           ; function->args->depth
	sub rax, 4                  ; function->args->depth - 4
	mov [rcx+32], rax           ; a->depth = function->args->depth - 4

collect_arguments_next:
	mov rax, [global_token]     ; Using global_token
	mov rax, [rax]              ; global_token->next
	mov [global_token], rax     ; global_token = global_token->next

	mov rax, [fn_function]      ; Using function
	mov [rax+32], rcx           ; function->args = a

collect_arguments_common:
	mov rbx, [global_token]     ; Using global_token
	mov rbx, [rbx+16]           ; global_token->S
	mov rax, comma              ; ","
	call match                  ; IF global_token->S == ","
	cmp rax, 0                  ; then deal with the comma
	jne collect_arguments_loop  ; otherwise loop

	;; keep foo(bar(), 1) expressions working
	mov rax, [global_token]     ; Using global_token
	mov rax, [rax]              ; global_token->next
	mov [global_token], rax     ; global_token = global_token->next
	jmp collect_arguments_loop  ; keep going

collect_arguments_done:
	mov rax, [global_token]     ; Using global_token
	mov rax, [rax]              ; global_token->next
	mov [global_token], rax     ; global_token = global_token->next
	pop rcx                     ; Restore RCX
	pop rbx                     ; Restore RBX
	ret


;; statement function
;; Recieves nothing
;; Returns nothing
;; Walks down global_token recursively to collect the contents of the function
statement:
	push rbx                    ; Protect RBX
	push rcx                    ; Protect RCX

	mov rbx, [global_token]     ; Using global_token
	mov rbx, [rbx+16]           ; global_token->S
	mov rax, open_curly_brace   ; "{"
	call match                  ; IF global_token->S == "{"
	jne statement_label         ; otherwise try label

	;; deal with { statement }
	call recursive_statement    ; Statements inside of statements for days
	jmp statement_done          ; Be done

statement_label:
	mov al, [rbx]               ; global_token->S[0]
	movzx rax, al               ; make it useful
	cmp rax, 58                 ; IF global_token->S == ':'
	jne statement_local         ; otherwise try locals

	;; deal with labels
	mov rax, rbx                ; put global_token->S in the right spot
	call emit_out               ; emit it

	mov rax, statement_string_0 ; Using "\t#C goto label\n"
	call emit_out               ; emit it

	mov rax, [global_token]     ; Using global_token
	mov rax, [rax]              ; global_token->next
	mov [global_token], rax     ; global_token = global_token->next
	jmp statement_done          ; be done

statement_local:
	mov rax, rbx                ; put global_token->S in the right place
	mov rbx, prim_types         ; pointer to primative types
	call lookup_type            ; See if found
	cmp rax, 0                  ; IF NULL == lookup_type(global_token->S, prim_types)
	jne statement_local_success ; Sweet a new local

	;; Second chance
	mov rbx, [global_token]     ; Using global_token
	mov rbx, [rbx+16]           ; global_token->S
	mov rax, struct             ; "struct"
	call match                  ; IF global_token->S == "struct"
	cmp rax, 0                  ; then we are a local
	jne statement_if            ; otherwise try IF

statement_local_success:
	; call collect_local
	jmp statement_done          ; be done

statement_if:
	mov rax, if_string          ; Using "if"
	call match                  ; IF global_token->S == "if"
	cmp rax, 0                  ; then we have an if statement
	jne statement_do            ; otherwise try DO

	;; Deal with IF statement
	; call process_if
	jmp statement_done          ; be done

statement_do:
	mov rax, do_string          ; Using "do
	call match                  ; IF global_token->S == "do"
	cmp rax, 0                  ; then we have a do statement
	jne statement_while         ; otherwise try WHILE

	;; Deal with DO statement
	; call process_do
	jmp statement_done          ; be done

statement_while:
	mov rax, while_string       ; Using "while"
	call match                  ; IF global_token->S == "while"
	cmp rax, 0                  ; then we have a while statement
	jne statement_for           ; otherwise try FOR

	;; Deal with WHILE statement
	; call process_while
	jmp statement_done          ; be done

statement_for:
	mov rax, for_string         ; Using "for"
	call match                  ; IF global_token->S == "for"
	cmp rax, 0                  ; then we have a for statement
	jne statement_asm           ; otherwise try ASM

	;; Deal with FOR statement
	; call process_for
	jmp statement_done          ; be done

statement_asm:
	mov rax, asm_string         ; Using "asm"
	call match                  ; IF global_token->S == "asm"
	cmp rax, 0                  ; then we have an asm statement
	jne statement_goto          ; otherwise try GOTO

	;; Deal with ASM statement
	; call process_asm
	jmp statement_done          ; be done

statement_goto:
	mov rax, goto_string        ; Using "goto"
	call match                  ; IF global_token->S == "goto"
	cmp rax, 0                  ; then we have a goto statement
	jne statement_return        ; Otherwise try RETURN

	;; Deal with GOTO statement
	mov rax, statement_string_1 ; Using "JUMP %"
	call emit_out               ; emit it

	mov rax, [global_token]     ; Using global_token
	mov rax, [rax]              ; global_token->next
	mov [global_token], rax     ; global_token = global_token->next

	mov rax, [rax+16]           ; global_token->S
	call emit_out               ; emit it

	mov rax, statement_string_2 ; Using "\n"
	call emit_out               ; emit it

	mov rax, [global_token]     ; Using global_token
	mov rax, [rax]              ; global_token->next
	mov [global_token], rax     ; global_token = global_token->next

	mov rax, statement_string_4 ; Using "ERROR in statement\nMissing ;\n"
	mov rbx, semicolon          ; Using ";"
	call require_match          ; Make sure it has the required
	jmp statement_done          ; Be done

statement_return:
	mov rax, return_string      ; Using "return"
	call match                  ; IF global_token->S == "return"
	cmp rax, 0                  ; then we have a return statement
	jne statement_break         ; Otherwise try BREAK

	;; Deal with RETURN Statement
	call return_result          ; Return anything they want
	jmp statement_done          ; be done

statement_break:
	mov rax, break_string       ; Using "break"
	call match                  ; IF global_token->S == "break"
	cmp rax, 0                  ; then we have a break statement
	jne statement_continue      ; Otherwise try CONTINUE

	;; Deal with BREAK statement
	; call process_break
	jmp statement_done          ; be done

statement_continue:
	mov rax, continue_string    ; Using "continue"
	call match                  ; IF global_token->S == "continue"
	cmp rax, 0                  ; then we have a continue statement
	jne statement_else          ; Otherwise we are punting to an expression

	;; Deal with CONTINUE statement
	mov rax, [global_token]     ; Using global_token
	mov rax, [rax]              ; global_token->next
	mov [global_token], rax     ; global_token = global_token->next

	mov rax, statement_string_3 ; Using "\n#continue statement\n"
	call emit_out               ; emit it

	mov rax, statement_string_4 ; Using "ERROR in statement\nMissing ;\n"
	mov rbx, semicolon          ; Using ";"
	call require_match          ; Don't forget the ";"
	jmp statement_done          ; Be done

statement_else:
;	call expression
	mov rax, statement_string_4 ; Using "ERROR in statement\nMissing ;\n"
	mov rbx, semicolon          ; Using ";"
	call require_match          ; make sure we have it

statement_done:
	pop rcx                     ; Restore RCX
	pop rbx                     ; Restore RBX
	ret


statement_string_0: db 9, "#C goto label", 10, 0
statement_string_1: db "JUMP %", 0
statement_string_2: db 10, 0
statement_string_3: db 10, "#continue statement", 10, 0
statement_string_4: db "ERROR in statement", 10, "Missing ;", 10, 0


	;; recursive_statement function
	;; Recieves nothing
	;; Returns nothing
	;; Walks the global_token list to build the contents of statements
	;; Uses struct token_list* frame in RCX
recursive_statement:
	push rbx                    ; Protect RBX
	push rcx                    ; Protect RCX

	mov rax, [global_token]     ; Using global_token
	mov rax, [rax]              ; global_token->next
	mov [global_token], rax     ; global_token = global_token->next

	mov rcx, [fn_function]      ; Using function
	mov rcx, [rcx+8]            ; frame = function->locals

recursive_statement_loop:
	mov rbx, [global_token]     ; Using global_token
	mov rbx, [rbx+16]           ; global_token->S
	mov rax, close_curly_brace  ; Using "}"
	call match                  ; IF global_token->S == "}"
	cmp rax, 0                  ; Then we are done recuring
	je recursive_statement_cleanup ; and then we clean up

	;; Deal with the recursive calls
	call statement              ; Deal with another statement
	jmp recursive_statement_loop ; loop some more

recursive_statement_cleanup:
	mov rax, [global_token]     ; Using global_token
	mov rax, [rax]              ; global_token->next
	mov [global_token], rax     ; global_token = global_token->next

	mov rax, recursive_statement_string_0 ; Using "RETURN\n"
	mov rbx, [output_list]      ; Using output
	mov rbx, [rbx+16]           ; output->S
	call match                  ; IF output->S == "RETURN\n"
	cmp rax, 0                  ; Then we can skip the clean up
	je recursive_statement_done ; and be done

	;; Deal with cleanup
	mov rbx, [fn_function]      ; Using function
	mov rbx, [rbx+8]            ; i = function->locals
	mov rax, recursive_statement_string_1 ; Using "POP_ebx\t# _recursive_statement_locals\n"

recursive_statement_locals:
	cmp rbx, rcx                ; IF frame != i
	je recursive_statement_done ; Otherwise be done

	;; Lets emit
	call emit_out               ; emit it
	mov rbx, [rbx]              ; i = i->next
	jmp recursive_statement_locals ; keep going

recursive_statement_done:
	mov rax, [fn_function]      ; Using function
	mov [rax+8], rcx            ; function->locals = frame
	pop rcx                     ; Restore RCX
	pop rbx                     ; Restore RBX
	ret


recursive_statement_string_0: db "RETURN", 10, 0
recursive_statement_string_1: db "POP_ebx", 9, "# _recursive_statement_locals", 10, 0


;; return_result function
;; Recieves nothing
;; Returns nothing
;; Cleans up function and generates return
;; Also handles returing expressions
return_result:
	push rbx                    ; Protect RBX
	push rcx                    ; Protect RCX
	mov rax, [global_token]     ; Using global_token
	mov rax, [rax]              ; global_token->next
	mov [global_token], rax     ; global_token = global_token->next

	mov rax, [rax+16]           ; global_token->S
	mov al, [rax]               ; global_token->S[0]
	movzx rax, al               ; make it useful
	cmp rax, 59                 ; If global_token->S[0] == ';'
	jne return_result_cleanup   ; Go straight to cleanup

;	call expression             ; get the expression we are returning

return_result_cleanup:
	mov rax, return_result_string_0 ; Using "ERROR in return_result\nMISSING ;\n"
	mov rbx, semicolon          ; Using ";"
	call require_match          ; Make sure we have it

	mov rbx, [fn_function]      ; Using function
	mov rbx, [rbx+8]            ; function->locals
	mov rax, return_result_string_1 ; Using "POP_ebx\t# _return_result_locals\n"
return_result_locals:
	cmp rbx, 0                  ; IF NULL == i
	je return_result_done       ; Be done

	call emit_out               ; Emit out pop
	jmp return_result_locals    ; Keep going

return_result_done:
	mov rax, return_result_string_2 ; Using "RETURN\n"
	call emit_out               ; Emit it
	pop rcx                     ; Restore RCX
	pop rbx                     ; Restore RBX
	ret


return_result_string_0: db "ERROR in return_result", 10, "MISSING ;", 10, 0
return_result_string_1: db "POP_ebx", 9, "# _return_result_locals", 10, 0
return_result_string_2: db "RETURN", 10, 0


;; require_match function
;; Recieves char* message in RAX and char* required in RBX
;; Returns nothing
;; Uses RCX to hold message and updates global_token
require_match:
	push rbx                    ; Protect RBX
	push rcx                    ; Protect RCX
	mov rcx, rax                ; put the message somewhere safe
	mov rax, [global_token]     ; Using global_token
	mov rax, [rax+16]           ; global_token->S
	call match                  ; IF required == global_token->S
	cmp rax, 0                  ; we are fine
	je require_match_good       ; otherwise pain

	;; Deal will bad times
;	call line_error             ; Tell user what went wrong
	mov r14, 2                  ; write to standard error
	mov rax, rcx                ; using our message
	call File_Print             ; Print it
	call Exit_Failure           ; Abort HARD

require_match_good:
	mov rax, [global_token]     ; Using global_token
	mov rax, [rax]              ; global_token->next
	mov [global_token], rax     ; global_token = global_token->next
	pop rcx                     ; Restore RCX
	pop rbx                     ; Restore RBX
	ret


;; emit_out function
;; Recieves char* S in RAX
;; Returns nothing
;; Updates output_list
emit_out:
	push rbx                    ; Protect RBX
	mov rbx, [output_list]      ; Using output_list
	call emit                   ; emit it
	mov [output_list], rax      ; update it
	pop rbx                     ; Restore RBX
	ret


;; emit function
;; Recieves char *s in RAX and struct token_list* head in RBX
;; Returns struct token_list* T in RAX
emit:
	push rcx                    ; Protect RCX
	mov rcx, rax                ; put S out of the way
	mov rax, 40                 ; sizeof(struct token_list)
	call malloc                 ; get T
	mov [rax], rbx              ; t->next = head;
	mov [rax+16], rcx           ; t->s = s;
	pop rcx                     ; Restore RCX
	ret


	;; type_name function
	;; Recieves nothing
	;; Returns type_size in RAX
	;; Uses RCX for STRUCT TYPE* RET
type_name:
	push rbx                    ; Protect RBX
	push rcx                    ; Protect RCX
	mov rbx, [global_token]     ; Using global_token
	mov rbx, [rbx+16]           ; global_token->S
	mov rax, struct             ; Using "struct"
	call match                  ; IF global_token->S == "struct"
	mov rcx, rax                ; Protect structure
	cmp rax, 0                  ; need to skip over "struct"
	jne type_name_native        ; otherwise keep going

	;; Deal with possible STRUCTs
	mov rbx, [global_token]     ; Using global_token
	mov rbx, [rbx]              ; global_token->next
	mov [global_token], rbx     ; global_token = global_token->next
	mov rax, [rbx+16]           ; global_token->S
	mov rbx, [global_types]     ; get all known types
	call lookup_type            ; Find type if possible
	mov rcx, rax                ; Set ret

	cmp rax, 0                  ; IF NULL == ret
	jne type_name_common        ; We have to create struct

	;; Create a struct
;	call create_struct          ; Create a new struct
	mov rcx, 0                  ; We wish to return NULL
	jmp type_name_done          ; be done

type_name_native:
	;; Deal only with native types
	mov rax, rbx                ; Put global_token->S in the right place
	mov rbx, [global_types]     ; get all known types
	call lookup_type            ; Find the type if possible
	mov rcx, rax                ; Set ret

	cmp rax, 0                  ; IF NULL == ret
	jne type_name_common        ; We need to abort hard

	;; Aborting hard
	mov r14, 2                  ; write to standard error
	mov rax, type_name_string_0 ; Print header
	call File_Print             ; Print it

	mov rax, [global_token]     ; Using global token
	mov rax, [rax+16]           ; global_token->S
	call File_Print             ; Print it

	mov rax, type_name_string_1 ; Print footer
	call File_Print             ; Print it

;	call line_error             ; Give details
	call Exit_Failure           ; Abort

type_name_common:
	mov rbx, [global_token]     ; Using global_token
	mov rbx, [rbx]              ; global_token->next
	mov [global_token], rbx     ; global_token = global_token->next

type_name_iter:
	mov rax, [rbx+16]           ; global_token->S
	mov al, [rax]               ; global_token->S[0]
	movzx rax, al               ; make it useful
	cmp rax, 42                 ; IF global_token->S[0] == '*'
	jne type_name_done          ; recurse

	;; Deal with char**
	mov rcx, [rcx+24]           ; ret = ret->indirect
	mov rbx, [global_token]     ; Using global_token
	mov rbx, [rbx]              ; global_token->next
	mov [global_token], rbx     ; global_token = global_token->next
	jmp type_name_iter          ; keep looping

type_name_done:
	mov rax, rcx                ; put ret in the right place
	pop rcx                     ; Restore RCX
	pop rbx                     ; Restore RBX
	ret


type_name_string_0: db "Unknown type ", 0
type_name_string_1: db 10, 0


;; lookup_type function
;; Recieves char* s in RAX and struct type* start in RBX
;; Returns struct type* in RAX
;; Uses RBX for S and RCX for I
lookup_type:
	push rbx                    ; Protect RBX
	push rcx                    ; Protect RCX
	mov rcx, rbx                ; I = Start
	mov rbx, rax                ; Put S in place
lookup_type_iter:
	cmp rcx, 0                  ; Check if I == NULL
	je lookup_type_done         ; return NULL

	mov rax, [rcx+48]           ; I->NAME
	call match                  ; Check if matching
	cmp rax, 0                  ; IF I->NAME == S
	je lookup_type_done         ; return it

	mov rcx, [rcx]              ; Otherwise I = I->NEXT
	jmp lookup_type_iter        ; And keep looping

lookup_type_done:
	mov rax, rcx                ; return either I or NULL
	pop rcx                     ; Restore RCX
	pop rbx                     ; Restore RBX
	ret


;; sym_declare function
;; Recieves char *s in RAX, struct type* t in RBX, and struct token_list* list in RCX
;; Returns struct token_list* in RAX
;; Uses RAX for A
sym_declare:
	push rdx                    ; Protect RDX
	mov rdx, rax                ; Get char *S safely out of the way
	mov rax, 40                 ; Using sizeof(struct token_list)
	call malloc                 ; Get pointer to A
	mov [rax], rcx              ; A->NEXT = LIST
	mov [rax+16], rdx           ; A->S = S
	mov [rax+24], rbx           ; A->TYPE = T
	pop rdx                     ; Restore RDX
	ret


;; match function
;; Recieves CHAR* in RAX and CHAR* in RBX
;; Returns 0 (TRUE) or 1 (FALSE) in RAX
match:
	push rbx                    ; Protect RBX
	push rcx                    ; Protect RCX
	push rdx                    ; Protect RDX
	mov rcx, rax                ; S1 in place
	mov rdx, rbx                ; S2 in place
match_Loop:
	mov al, [rcx]               ; S1[0]
	movzx rax, al               ; Make it useful
	mov bl, [rdx]               ; S2[0]
	movzx rbx, bl               ; Make it useful
	cmp rax, rbx                ; See if they match
	jne match_False             ; If not

	add rcx, 1                  ; S1 = S1 + 1
	add rdx, 1                  ; S2 = S2 + 1
	cmp rax, 0                  ; If reached end of string
	je match_Done               ; Perfect match
	jmp match_Loop              ; Otherwise keep looping

match_False:
	mov rax, 1                  ; Return false
match_Done:
	pop rdx                     ; Restore RDX
	pop rcx                     ; Restore RCX
	pop rbx                     ; Restore RBX
	ret


;; Exit_Failure function
;; Recieves nothing
;; And aborts hard
;; Does NOT return
Exit_Failure:
	mov rdi, 1                  ; All is wrong
	mov rax, 0x3c               ; put the exit syscall number in eax
	syscall                     ; Call it a bad day

;; Keywords
union: db "union", 0
struct: db "struct", 0
constant: db "CONSTANT", 0
main_string: db "main", 0
argc_string: db "argc", 0
argv_string: db "argv", 0
if_string: db "if", 0
else_string: db "else", 0
do_string: db "do", 0
while_string: db "while", 0
for_string: db "for", 0
asm_string: db "asm", 0
goto_string: db "goto", 0
return_string: db "return", 0
break_string: db "break", 0
continue_string: db "continue", 0
sizeof_string: db "sizeof", 0
plus_string: db "+", 0
minus_string: db "-", 0
multiply_string: db "*", 0
divide_string: db "/", 0
modulus_string: db "%", 0
left_shift_string: db "<<", 0
right_shift_string: db ">>", 0
less_than_string: db "<", 0
less_than_equal_string: db "<=", 0
greater_than_equal_string: db ">=", 0
greater_than_string: db ">", 0
equal_to_string: db "==", 0
not_equal_string: db "!=", 0
bitwise_and: db "&", 0
logical_and: db "&&", 0
bitwise_or: db "|", 0
logical_or: db "||", 0
bitwise_xor: db "^", 0
arrow_string: db "->", 0


;; Frequently Used strings
;; Generally used by require_match
open_curly_brace: db "{", 0
close_curly_brace: db "}", 0
open_paren: db "(", 0
close_paren: db ")", 0
open_bracket: db "[", 0
close_bracket: db "]", 0
comma: db ",", 0
semicolon: db ";", 0
equal: db "=", 0
percent: db "%", 0
newline: db "\n", 0
underline: db "_", 0


prim_types:
type_void:
	dq type_int                 ; NEXT
	dq 4                        ; SIZE
	dq 0                        ; OFFSET
	dq type_void                ; INDIRECT
	dq 0                        ; MEMBERS
	dq type_void                ; TYPE
	dq type_void_name           ; NAME
type_void_name: db "void", 0

type_int:
	dq type_char                ; NEXT
	dq 4                        ; SIZE
	dq 0                        ; OFFSET
	dq type_int                 ; INDIRECT
	dq 0                        ; MEMBERS
	dq type_int                 ; TYPE
	dq type_int_name            ; NAME
type_int_name: db "int", 0

type_char:
	dq type_file                ; NEXT
	dq 1                        ; SIZE
	dq 0                        ; OFFSET
	dq type_char_indirect       ; INDIRECT
	dq 0                        ; MEMBERS
	dq type_char                ; TYPE
	dq type_char_name           ; NAME
type_char_name: db "char", 0

type_char_indirect:
	dq type_file                ; NEXT
	dq 4                        ; SIZE
	dq 0                        ; OFFSET
	dq type_char_double_indirect ; INDIRECT
	dq 0                        ; MEMBERS
	dq type_char_indirect       ; TYPE
	dq type_char_indirect_name  ; NAME
type_char_indirect_name: db "char*", 0

type_char_double_indirect:
	dq type_file                ; NEXT
	dq 4                        ; SIZE
	dq 0                        ; OFFSET
	dq type_char_double_indirect ; INDIRECT
	dq 0                        ; MEMBERS
	dq type_char_indirect       ; TYPE
	dq type_char_double_indirect_name ; NAME
type_char_double_indirect_name: db "char**", 0

type_file:
	dq type_function            ; NEXT
	dq 4                        ; SIZE
	dq 0                        ; OFFSET
	dq type_file                ; INDIRECT
	dq 0                        ; MEMBERS
	dq type_file                ; TYPE
	dq type_file_name           ; NAME
type_file_name: db "FILE", 0

type_function:
	dq type_unsigned            ; NEXT
	dq 4                        ; SIZE
	dq 0                        ; OFFSET
	dq type_function            ; INDIRECT
	dq 0                        ; MEMBERS
	dq type_function            ; TYPE
	dq type_function_name       ; NAME
type_function_name: db "FUNCTION", 0

type_unsigned:
	dq 0                        ; NEXT
	dq 4                        ; SIZE
	dq 0                        ; OFFSET
	dq type_unsigned            ; INDIRECT
	dq 0                        ; MEMBERS
	dq type_unsigned            ; TYPE
	dq type_unsigned_name       ; NAME
type_unsigned_name: db "unsigned", 0

	;; debug_list function
	;; Recieves struct token_list* in RAX
	;; Prints contents of list and exits
	;; Does NOT return
debug_list:
	mov r12, rax                ; Protect the list pointer
	mov r14, 2                  ; write to standard error

debug_list_iter:
	;; Header
	mov rax, debug_list_string0 ; Using our first string
	call File_Print             ; Print it
	mov rax, r12                ; Use address of pointer
	; call numerate_number        ; Convert it into string
	; call File_Print             ; Print it

	;; NEXT
	mov rax, debug_list_string1 ; Using our second string
	call File_Print             ; Print it
	mov rax, [r12]              ; Use address of pointer
	; call numerate_number        ; Convert it into string
	; call File_Print             ; Print it

	;; PREV
	mov rax, debug_list_string2 ; Using our third string
	call File_Print             ; Print it
	mov rax, [r12+8]            ; Use address of pointer
	; call numerate_number        ; Convert it into string
	; call File_Print             ; Print it

	;; S
	mov rax, debug_list_string3 ; Using our fourth string
	call File_Print             ; Print it
	mov rax, [r12+16]              ; Use address of pointer
	; call numerate_number        ; Convert it into string
	; call File_Print             ; Print it

	;; S Contents
	mov rax, debug_list_string4 ; Using our fifth string
	call File_Print             ; Print it
	mov rax, [r12+16]           ; Use address of string
	cmp rax, 0                  ; IF NULL Pointer
	jne debug_list_null         ; otherwise display
	mov rax, debug_list_string_null ; Give meaningful message instead
debug_list_null:
	call File_Print             ; Print it

	;; TYPE
	mov rax, debug_list_string5 ; Using our sixth string
	call File_Print             ; Print it
	mov rax, [r12+24]           ; Use address of pointer
	; call numerate_number        ; Convert it into string
	; call File_Print             ; Print it

	;; ARGS/DEPTH
	mov rax, debug_list_string6 ; Using our third string
	call File_Print             ; Print it
	mov rax, [r12+32]           ; Use address of pointer
	; call numerate_number        ; Convert it into string
	; call File_Print             ; Print it

	mov rax, 10                 ; Add "\n"
	call fputc                  ; print it
	call fputc                  ; print it

	mov r12, [r12]              ; TOKEN = TOKEN->NEXT
	cmp r12, 0                  ; Check if NULL
	jne debug_list_iter         ; iterate otherwise

	mov rdi, 666                ; All is HELL
	mov rax, 0x3c               ; put the exit syscall number in eax
	syscall                     ; Call it a bad day


debug_list_string0: db "Token_list node at address: ", 0
debug_list_string1: db 10, "NEXT address: ", 0
debug_list_string2: db 10, "PREV address: ", 0
debug_list_string3: db 10, "S address: ", 0
debug_list_string4: db 10, "The contents of S are: ", 0
debug_list_string5: db 10, "TYPE address: ", 0
debug_list_string6: db 10, "ARGUMENTS address: ", 0
debug_list_string_null: db ">::<NULL>::<", 0

section .data
global_types:
	dq prim_types

Token:
	dq 0

C:
	dq 0

string_index:
	dq 0

output_list:
	dq 0

globals_list:
	dq 0

strings_list:
	dq 0

global_token:
	dq 0

Address_of:
	dq 0

function:
	dq 0

global_constant_list:
	dq 0

global_symbol_list:
	dq 0

current_count:
	dq 0

;; Is supposed to be the global variable named function but NASM can't handle that name
fn_function:
	dq 0

global_function_list:
	dq 0
