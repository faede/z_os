	%include "boot.inc"
	section loader vstart=LOADER_BASE_ADDR
	LOADER_STACK_TOP equ LOADER_BASE_ADDR

;构建gdt及其内部的描述符
	GDT_BASE: dd 0x00000000
		  dd 0x00000000

	CODE_DESC:dd 0x0000FFFF
		  dd DESC_CODE_HIGH4

	DATA_STACK_DESC: dd 0x0000FFFF
				 dd DESC_DATA_HIGH4

	VIDEO_DESC: dd 0x80000007				; limit=(0xbfffff-0xb8000)/4k=0x7
			dd DESC_VIDEO_HIGH4 				; 此时dpl为0

	GDT_SIZE equ $ - GDT_BASE
	GDT_LIMIT equ GDT_SIZE - 1
	times 60 dq 0		;此处预留60个描述符的空位

	SELECTOR_CODE equ (0x0001<<3) + TI_GDT + RPL0
		;相当于(CODE_DESC - GDT_BASE)/8 + TI_GDT + RPL0
	SELECTOR_DATA equ (0x0002<<3) + TI_GDT + RPL0	;同上
	SELECTOR_VIDEO equ (0x0003<<3) + TI_GDT + RPL0	;同上

	;	total_mem_bytes 用于保存内存容量，以字节为单位
	;	当前偏移loader.bin 文件头0x200字节
	;	loader.bin的内存中加载地址是0xb00
	;	将来在内核中会引用此地址
	total_mem_bytes dd 0
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	

	;以下是 gdt 的指针，前2字节是gdt界限，后4字节是gdt起始地址

	gdt_ptr dw GDT_LIMIT
			dd GDT_BASE

;人工对齐: total_mem_bytes4 + gdt_ptr6 + ards_buf244+ards_nr2,共256字节
	ards_buf times db 0
	ards_nr dw 0		;record number of ards struct


	loader_start:

; in 15h eax = 0000E820h, edx = 534D4150h ('SMAP') 获取内存布局

	xor ebx, ebx		; first call set it zero
	mov edx, 0x53D4150  ; set only once
	mov di, ards_buf 	; ards struct buff
.e820_mem_get_loop:
	mov eax, 0x0000e820	; after int 0x15 eax -> 0x53D4150 so need reflash
	mov ecx, 20
	int 0x15
	jc .e820_failed_so_try_e801

	add di, cx
	inc word [ards_nr]
	cmp ebx, 0
	jnz .e820_mem_get_loop

; on all of ards find max of (base_add_low + length_low),
; which is the capacity of memory
	mov cx, [ards_nr]
; travel every ards struct, time is the number of ards 
	mov ebx, ards_buf
	xor edx, edx 		; set 0


.find_max_mem_area:
	mov eax, [ebx]		;base_add_low
	add eax, [ebx+8]	;length_low
	add ebx, 20
	cmp edx, eax
	jge .next_ards
	mov edx, eax		; edx as total memory size
.next_ards:
	loop .find_max_mem_area	; loop will decrease cx register
	jmp .mem_get_ok

;--------------------- int 15h ax = E801h get size of memory, most support 4G---
; after return ax equal ax , takte KB base, bx equal dx, take 64KB base
; ax cx are low 16MB, bx dx are 16MB to 4GB
.e820_failed_so_try_e801:
	mov	ax, 0xe801 
	int 0x15 
	jc .e801_failed_so_try88

; 1 cac low 15 MB memory
; ax and bx is number fo take KB base, convert to take byte base
	mov cx,0x400		;cx equal ax, cx as mul number
	mul cx
	shl edx, 16
	and eax, 0x0000FFFF 
	or edx, eax
	add edx, 0x100000	;ax 15MB so need add 15MB
	mov esi, edx		;save low 15MB on esi

; convert higher than 16
	xor eax, eax
	mov ax, bx
	mov ecx, 0x10000 	;0x10000 -> 64KB
	mul ecx				; mul by eax
						; high 32 ->edx low 32 ->eax
	add esi,eax
	; edx must 0

	mov edx, esi
	jmp .mem_get_ok

;-------------- int 15h ah = 0x88 get memory in 64MB -----------
.e801_failed_so_try88:
	mov ah, 0x88
	int 0x15
	jc .error_hlt
	and eax, 0x0000FFFF

	;16bit mul ,mul by ax, -> 32: high 16 in dx, low 16 in ax
	mov cx,0x400
	mul cx
	shl edx,16			; mov dx to high 16
	or edx, eax			; combinate ax
	add edx, 0x100000	; it only return greater than 1M, so add 1MB

.mem_get_ok:
	mov [total_mem_bytes], edx ;change to byte save in total_mem_bytes








;---------------------准备进入保护模式-------------------------
; 1 打开A20
; 2 加载gdt
; 3 将cr0 的pe位置1
;-----------------------打开A20------------------------------

	in al,0x92
	or al, 0000_0010b
	out 0x92, al

	;--------------------加载gdt------------------------
	lgdt [gdt_ptr]

	;--------------------将cr0 的pe(0)位置1------------------------
	mov eax, cr0
	or eax, 0x00000001
	mov cr0, eax

	jmp dword SELECTOR_CODE:p_mode_start 		;刷新流水线 

[bits 32]
p_mode_start:
	mov ax, SELECTOR_DATA
	mov ds, ax
	mov	es, ax
	mov ss, ax
	mov esp, LOADER_STACK_TOP
	mov ax, SELECTOR_VIDEO
	mov gs, ax

	mov byte [gs:160], 'p'

	jmp $



