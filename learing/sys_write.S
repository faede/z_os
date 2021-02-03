section .data
str_c_lib: db "c library says: hello world!", 0xa ; 0xa is ASCII of LF
str_c_lib_len equ $-str_c_lib

str_syscall: db "syscall says: hello world!", 0xa
str_syscall_len equ $-str_syscall

section .text
global _start
_start:
;----------------------- simulte C write ----------------------
	push str_c_lib_len		; push argument
	push str_c_lib
	push 1

	call simu_write
	add esp 12

;--------------------- accross library function ----------------
	mov eax, 4 				; system write
	mov ebx, 1
	mov	ecx, str_syscall
	mov edx, str_syscall_len
	int 0x80				; estb int

;-----------------------------   exit ----------------------------
	mov eax, 1				; system exit
	int 0x80

;------------ simu_write simulte C library function write ---------
simu_write:
	push ebp
	mov ebp, esp
	mov eax, 4		; 4 is syscall write ,not C write
	mov ebx, [ebp + 8] 		; first argument
	mov ecx, [ebp + 12]		; second argument
	mov edx, [ebp + 16]		; third argument
	int 0x80
	pop ebp
	ret
