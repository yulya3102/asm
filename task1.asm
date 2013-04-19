extern _printf
	section .text
	global _main
_main:
	mov eax, [esp + 8] 	;argv
	mov esi, [eax + 8] 	;argv[2] - hex number string
	mov eax, [eax + 4] 	;argv[1] - format string

	push eax
	call parse_format_string
	add esp, 4
	;ah - flags, al - length
	;ah: ____0- +
	mov bx, ax

	push ebp
	mov ebp, esp
	sub esp, 16 		;16 byte for number
	
	push esp 			;storage for number
	push esi 			;string with number
	call parse_hex_string	
	add esp, 8
	;in edx now 128-bit hex number :33

	push ebp
	mov ebp, esp
	sub esp, 41 		;41 byte for string: sign + 39 digits + \0

	push esp 			;storage for string
	push edx 			;16 byte hex number
	call hex_number_to_dec_string
	add esp, 8
	;in edx now string with dec number
	;in eax (al) length of string (without \0)
	shl ebx, 16
	mov bx, ax

	push ebp
	mov ebp, esp
	sub esp, 51 		;51 byte for result string: 50 symbols + \0

	push esp 			;storage for result string
	push edx 			;string with dec number
	push ebx 			;flags, length, bx: length of edx without \0
	call format_string
	add esp, 8

	push edx
	call _printf
	add esp, 4

	leave

	leave

	leave
	xor eax, eax
	ret

; [esp + 4] - flags, length, 0, length of string with number without \0
; [esp + 8] - string with number
; [esp + 12] - storage for result string
; result: string in edx
format_string:
	mov eax, [esp + 4]
	mov ecx, [esp + 8]
	mov edx, [esp + 12]
	push ebx
	push esi
	push edi
	mov edi, edx
	mov esi, ecx
	mov ebx, eax
	mov eax, ebx
	shr eax, 16
	;edi = &data
	;esi = dec_string
	;bx = 0, dec_string.length()
	;ax = flags, length

	;dl = sign_symbol
	;if esi.length >= length
	;	return
	;if zero_flag
	;	while esi.length < length
	;		esi = sign_symbol + '0' + esi
	;if minus_flag
	;	while esi.length < length
	;		esi += ' '
	;while esi.length < length
	;	esi = ' ' + esi
	;
	
	;sign_symbol = 0
	;if plus_flag
	;	sign_symbol = '+'
	;if space_flag
	;	sign_symbol = ' '
	;if esi < 0
	;	sign_symbol = '-'
	;	esi -= '-'
	xor dl, dl 	;sign_symbol
	cmp [esi], byte '-'
	jne fs_sign_label
	mov dl, '-'
	inc esi
	jmp fs_not_signed
fs_sign_label:
	test ah, 1
	jz fs_not_plus_flag
	mov dl, '+'
	inc bl
fs_not_plus_flag:
	test ah, 2
	jz fs_not_space_flag
	mov dl, ' '
	inc bl
fs_not_space_flag:
fs_not_signed:

	;if esi.length >= length
	;	return
	cmp bl, al
	jb fs_format
	test dl, dl
	jz fs_r_not_signed
	dec esi
	mov [esi], dl
fs_r_not_signed
	mov edx, esi
	jmp fs_return

fs_format:
	;if zero_flag
	;	[edi] = sign_symbol
	;	do
	;		edi++
	;		[edi] = '0'
	;		esi.length++
	;	while esi.length < length
	;	do
	;		[edi] = [esi]
	;		edi++
	;		esi++
	;	while [edi - 1] != 0
	;	return
	test ah, 8
	jz fs_not_zero_flag
	mov [edi], dl
	test dl, dl
	jnz fs_z_signed_start
	inc edi
	push edi
	jmp fs_z_not_signed_start
fs_z_signed_start:
	push edi
	inc edi
fs_z_not_signed_start:
fs_z_add_zero_cycle:
	mov [edi], byte '0'
	inc edi
	inc bl
	cmp bl, al
	jb fs_z_add_zero_cycle
fs_z_add_string:
	mov dh, [esi]
	mov [edi], dh
	inc edi
	inc esi
	cmp [edi - 1], byte 0
	jne fs_z_add_string

	pop edi
	mov edx, edi
	jmp fs_return

fs_not_zero_flag:
	;if minus_flag
	;	edi += sign_symbol
	;	edi += esi
	;	do
	;		[edi] = ' '
	;		edi++
	;		esi.length++
	;	while esi.length < length
	;	return
	test ah, 4
	jz fs_not_minus_flag
	push edi
	test dl, dl
	jz fs_m_add_string
	mov [edi], dl
	inc edi
fs_m_add_string:
	mov dh, [esi]
	mov [edi], dh
	inc edi
	inc esi
	cmp [edi - 1], byte 0
	jne fs_m_add_string
	;[edi - 1] == 0
	dec edi
fs_m_add_space_cycle:
	mov [edi], byte ' '
	inc edi
	inc bl
	cmp bl, al
	jb fs_m_add_space_cycle
	mov [edi], byte 0

	pop edi
	mov edx, edi
	jmp fs_return

fs_not_minus_flag:
	;do
	;	[edi] = ' '
	;	edi++
	;	esi.length++
	;while esi.length < length
	;edi += sign_symbol + esi
	push edi
fs_n_add_space_cycle:
	mov [edi], byte ' '
	inc edi
	inc bl
	cmp bl, al
	jb fs_n_add_space_cycle
	test dl, dl
	jz fs_n_add_string
	mov [edi], dl
	inc edi
fs_n_add_string:
	mov dh, [esi]
	mov [edi], dh
	inc edi
	inc esi
	cmp [edi - 1], byte 0
	jne fs_n_add_string
	pop edi
	mov edx, edi

fs_return:
	pop edi
	pop esi
	pop ebx
	ret

; [esp + 4] - format string
; result: ah - flags, al - length
parse_format_string:
	mov edx, [esp + 4]
	push ebx
	;bh = 0
	;// bh: 0000'0''-'' ''+'
	;i = 0
	;while edx[i] != 0
	;	case edx of
	;	'0': bh |= 00001000
	;	'-': bh |= 00000100
	;	' ': bh |= 00000010
	;	'+': bh |= 00000001
	;	default: break
	;	i++
	;//now edx is dec length
	;al = 0
	;while edx[i] != 0
	;	al *= 10
	;	al += edx[i] - '0'	
	;	i++
	xor bh, bh
	xor al, al
pfs_parse_flags:
	cmp [edx], byte 0
	je pfs_end
	cmp [edx], byte '0'
	jne pfs_not_zero
	or bh, 8
	inc edx
	jmp pfs_parse_flags
pfs_not_zero:
	cmp [edx], byte '-'
	jne pfs_not_minus
	or bh, 4
	inc edx
	jmp pfs_parse_flags
pfs_not_minus:
	cmp [edx], byte ' '
	jne pfs_not_space
	or bh, 2
	inc edx
	jmp pfs_parse_flags
pfs_not_space:
	cmp [edx], byte '+'
	jne pfs_parse_length
	or bh, 1
	inc edx
	jmp pfs_parse_flags
pfs_parse_length:
	cmp [edx], byte 0
	je pfs_end
	mov bl, 10
	mul bl
	add al, [edx]
	sub al, '0'
	inc edx
	jmp pfs_parse_length
pfs_end:
	;if '+' then not ' '
	;if '0' then not '-'
	test bh, 1
	jz pfs_not_plus_flag
	and bh, 0xfd
pfs_not_plus_flag:
	test bh, 8
	jz pfs_not_zero_flag
	and bh, 0xfb
pfs_not_zero_flag:
	mov ah, bh
	pop ebx
	ret

; [esp + 4] - 16 byte hex number
; [esp + 8] - storage for string
; result: edx - &string, eax - edx.length()
hex_number_to_dec_string:
	;esi = hex_number
	;edx = &data
	mov eax, [esp + 4] 	;eax = hex_number
	mov edx, [esp + 8] 	;edx = &data
	push esi
	push ebx
	mov esi, eax

	;for i = 1..41 do
	;	edx[i] = 0
	mov cl, 41
	push edx
hntds_clear_storage_cycle:
	mov [edx], byte 0
	inc edx
	dec cl
	jnz hntds_clear_storage_cycle
	pop edx

	;if esi < 0 then
	;	edx[0] = '-'
	;	esi = -esi
	mov al, [esi]
	cmp al, 0x80
	jb hntds_unsigned
	mov [edx], byte '-'
	;for i = 16..1 do
	;	esi[i] = not esi[i]
	mov cl, 16
	push esi
hntds_signed_not_cycle:
	mov al, [esi]
	not al
	mov [esi], al
	inc esi
	dec cl
	jnz hntds_signed_not_cycle
	;esi += 1
	mov cl, 16
	pop esi
	push esi
	add esi, 16
hntds_signed_inc_cycle:
	dec esi
	mov al, [esi]
	add al, 1
	mov [esi], al
	;cmp al, 10
	jnc hntds_signed_end
	;sub al, 10
	;mov [esi], al
	dec cl
	jne hntds_signed_inc_cycle
hntds_signed_end:
	pop esi



hntds_unsigned:
	inc edx

	;for j = 1..16
	;	cf = 0
	;	edx *= 256
	;	edx += esi[j]
	mov cl, 16
hntds_cycle:

	;cf = 0
	;for i = 39..1 do
	;	edx[i] *= 256
	;	edx[i] += cf
	;	cf = edx[i] / 10
	;	edx[i] %= 10
	mov bl, 0 		;cf 
	mov ch, 39
	push edx
	add edx, 38
hntds_mul_cycle:
	mov al, [edx]
	shl ax, 8 		;ax == al * 256
	add al, bl
	mov bl, 10
	div bl 			;al = ax / bl, ah = ax % bl
	mov bl, al
	mov [edx], ah
	dec edx
	dec ch
	jnz hntds_mul_cycle
	pop edx

	;cf = esi[j]
	;for i = 39..1 do
	;	edx[i] += cf
	;	cf = edx[i] / 10
	;	edx[i] %= 10
	mov bl, [esi]	;cf
	mov ch, 39
	push edx
	add edx, 38
hntds_add_cycle:
	mov al, [edx]	
	xor ah, ah
	xor bh, bh
	add ax, bx
	mov bl, 10
	div bl
	mov bl, al
	mov [edx], ah
	dec edx
	dec ch
	jnz hntds_add_cycle
	pop edx

	inc esi
	dec cl
	jnz hntds_cycle

	dec edx

	;and get string from that shit :3
	;ah = sign
	;edx[last] += '0'
	;i = 1 //sign
	;while edx[i+1] == 0
	;	i++
	;edx[i] = ah
	;while i < 40
	;	i++
	;	edx[i] += '0'
	mov ah, [edx]
	add edx, 39
	add [edx], byte '0'
	sub edx, 39
	mov cl, 39
hntds_del_zeros_cycle:
	dec cl
	inc edx
	cmp [edx], byte 0
	je hntds_del_zeros_cycle
	dec edx
	mov [edx], ah
	push edx

	cmp cl, 0
	je hntds_check_minus
hntds_to_string_cycle:
	inc edx
	add [edx], byte '0'
	dec cl
	jnz hntds_to_string_cycle

hntds_check_minus:	
	pop edx
	cmp [edx], byte '-'
	je hntds_end
	inc edx

hntds_end:
	push edx
	xor eax, eax
hntds_count_symbols_cycle:
	inc eax
	inc edx
	cmp [edx], byte 0
	jne hntds_count_symbols_cycle

	pop edx
	pop ebx
	pop esi
	ret

; [esp + 4] - hex number string
; [esp + 8] - storage for number
; result: in edx - 128-bit hex number
parse_hex_string:
	mov eax, [esp + 4] 	;eax = number_string
	mov edx, [esp + 8]	;edx = &data;
	push ebx
	mov ebx, eax
	
	;for i = 1 .. 16 do
	;    edx[i] = 0
	mov cl, 16
phs_clear_strorage_cycle:
	mov [edx], byte 0
	inc edx
	dec cl
	jnz phs_clear_strorage_cycle

	sub edx, 16

	mov ch, [ebx]
	cmp ch, '-'
	jne phs_l10
	inc ebx

phs_l10:

	;cl = 0
	;while s[i] != 0
	;	cl++
	xor cl, cl
	push ebx
phs_count_digits:
	mov al, [ebx]
	cmp al, 0
	je phs_l2
	inc cl
	inc ebx
	jmp phs_count_digits

phs_l2:
	dec ebx 	;now last symbol in ebx

	;for i = 1 .. cl do
	;	data[i] = string[i] - '0'

	push edx
	add edx, 15
	xor ax, ax
phs_l5:
	cmp cl, 0
	je phs_l4
	mov al, [ebx]
	cmp al, 'a'
	jb phs_l6
	sub al, 'a'
	add al, 10
	jmp phs_j7
phs_l6:
	cmp al, 'A'
	jb phs_j8
	sub al, 'A'
	add al, 10
	jmp phs_j7
phs_j8:
	sub al, '0'
phs_j7:
	;shl al, 4
	mov [edx], al
	;dec edx
	dec ebx
	dec cl

	cmp cl, 0
	je phs_l4
	mov ah, [ebx]
	cmp ah, 'a'
	jb phs_l9
	sub ah, 'a'
	add ah, 10
	jmp phs_l7
phs_l9:
	cmp ah, 'A'
	jb phs_l8
	sub ah, 'A'
	add ah, 10
	jmp phs_l7
phs_l8:
	sub ah, '0'
phs_l7:
	shl ah, 4
	add al, ah
	mov [edx], al
	dec edx
	dec ebx
	dec cl
	jmp phs_l5

phs_l4:

	cmp ch, '-'
	jne phs_l11
	pop edx
	push edx
	;for i = 1 .. 16
	;	edx[i] = not edx[i]
	mov cl, 16
	add edx, 15
phs_l12:
	mov al, [edx]
	not al
	mov [edx], al
	dec edx
	dec cl
	jnz phs_l12
	
	;edx += 1
	pop edx
	push edx
	mov cl, 16
	add edx, 15
	mov al, [edx]
	add al, 1
	mov [edx], al
	dec cl
	dec edx
phs_l13:
	mov al, [edx]
	adc al, 0
	mov [edx], al
	dec edx
	dec cl
	jnz phs_l13

phs_l11:
	pop edx
	pop ebx
	pop ebx
	ret
