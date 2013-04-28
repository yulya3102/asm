global FDCT
global IDCT
global matrix_multiplication

; [esp + 4] - 8x8 matrix with points
; [esp + 8] - 8x8 result matrix
; [esp + 12] - N
IDCT:
    mov eax, [esp + 4]
    mov edx, [esp + 8]
    mov ecx, [esp + 12]

    push esi
    mov esi, eax
    push edi
    mov edi, edx
    push ebx
    mov ebx, ecx
    
    ; esi - input
    ; edi - output
    ; ebx - N

    xor ecx, ecx
idct_cycle:
    push ecx
    
    push edi
    push esi
    call idct_one_matrix
    add esp, 2 * 4

    pop ecx
    add esi, 64 * 4
    add edi, 64 * 4
    inc ecx
    cmp ecx, ebx
    jb idct_cycle

    pop ebx
    pop edi
    pop esi
ret

; [esp + 4] - input 8x8 matrix
; [esp + 8] - output 8x8 matrix
idct_one_matrix:
    mov eax, [esp + 4] ; eax = input
    mov edx, [esp + 8] ; edx = output

    push ebx
    push esi
    push edi

    mov esi, eax
    mov edi, edx

    ; esi = input
    ; edi = output
    
    ; result = C * input * C^T
    push ebp
    mov ebp, esp
    sub esp, 64 * 4
    
    mov ebx, esp    ; ebx - C * input
    push ebx
    push esi
    ; TODO: push C^-1 matrix
    call matrix_multiplication
    add esp, 3 * 4

    push edi
    ; TODO: push C^-1^T matrix
    push ebx
    call matrix_multiplication
    add esp, 3 * 4

    leave
    
    mov eax, edi

    pop edi
    pop esi
    pop ebx
ret

; [esp + 4] - 8x8 matrix with points
; [esp + 8] - 8x8 result matrix
; [esp + 12] - N
FDCT:
    mov eax, [esp + 4]
    mov edx, [esp + 8]
    mov ecx, [esp + 12]

    push esi
    mov esi, eax
    push edi
    mov edi, edx
    push ebx
    mov ebx, ecx
    
    ; esi - input
    ; edi - output
    ; ebx - N

    xor ecx, ecx
fdct_cycle:
    push ecx
    
    push edi
    push esi
    call fdct_one_matrix
    add esp, 2 * 4

    pop ecx
    add esi, 64 * 4
    add edi, 64 * 4
    inc ecx
    cmp ecx, ebx
    jb fdct_cycle

    pop ebx
    pop edi
    pop esi
ret

; [esp + 4] - input 8x8 matrix
; [esp + 8] - output 8x8 matrix
fdct_one_matrix:
    mov eax, [esp + 4] ; eax = input
    mov edx, [esp + 8] ; edx = output

    push ebx
    push esi
    push edi

    mov esi, eax
    mov edi, edx

    ; esi = input
    ; edi = output
    
    ; result = C * input * C^T
    push ebp
    mov ebp, esp
    sub esp, 64 * 4
    
    mov ebx, esp    ; ebx - C * input
    push ebx
    push esi
    push cmatrix
    call matrix_multiplication
    add esp, 3 * 4

    push edi
    push cmatrixt
    push ebx
    call matrix_multiplication
    add esp, 3 * 4

    leave
    
    mov eax, edi

    pop edi
    pop esi
    pop ebx
ret

; A, B, A * B - 8x8
; [esp + 4] - A
; [esp + 8] - B
; [esp + 12] - A * B
matrix_multiplication:
    mov eax, [esp + 4]
    mov ecx, [esp + 8]
    mov edx, [esp + 12]
    push ebx
    mov ebx, ecx

    push eax
    push edx
    push ebx
    call transpose_matrix
    pop ebx
    pop edx
    pop eax

    ; eax - A
    ; ebx - B
    ; edx - A * B

    ; for j = 0..7 
    ;     xmm0, xmm1 = B_j
    ;     for i = 0..7
    ;         xmm2, xmm3 = A_i
    ;         xmm0, xmm1 = A_i * B_j
    ;         C_ij = sum xmm0, xmm1

    xor ecx, ecx
mm_jcycle:
    ; B_j = B + 8 * j
    push ecx
    shl cl, 3
    movzx ecx, cl
    movups xmm0, [ebx + 4 * ecx]
    movups xmm1, [ebx + 4 * ecx + 16]
    pop ecx

    ; xmm0, xmm1 = B_j
        
    xor ch, ch
mm_icycle:
    ; A_i = A + 8 * i
    push ecx
    shl ch, 3
    movzx ecx, ch
    movups xmm2, [eax + 4 * ecx]
    movups xmm3, [eax + 4 * ecx + 16]
    pop ecx

    ; xmm2, xmm3 = A_i

    mulps xmm2, xmm0
    mulps xmm3, xmm1
    addps xmm2, xmm3

    haddps xmm2, xmm2
    haddps xmm2, xmm2

    ; C_ij = [edx + 8 * i + j]
    push ecx
    shl ch, 3
    add ch, cl
    movzx ecx, ch
    movss [edx + 4 * ecx], xmm2
    pop ecx

    inc ch
    cmp ch, 8
    jb mm_icycle
    inc cl
    cmp cl, 8
    jb mm_jcycle

    push eax
    push edx
    push ebx
    call transpose_matrix
    pop ebx
    pop edx
    pop eax
       
    pop ebx
    mov eax, edx
ret

; [esp + 4] - 8x8 matrix
transpose_matrix:
    mov eax, [esp + 4]
    push esi
    mov esi, eax

    ; for i = 0 .. 7
    ;     for j = i + 1 .. 7
    ;         swap [esi + i * N + j], [esi + j * N + i]
    xor ecx, ecx
    ; cl = i
    ; ch = j
tm_icycle:
    mov ch, cl
    inc ch
tm_jcycle:
    ; edx = i * N + j
    mov edx, ecx
    shl dl, 3
    add dl, dh
    movzx edx, dl
    ; eax = [esi + i * N + j]
    mov eax, [esi + 4 * edx]
    ; ecx = j * N + i
    push ecx
    shl ch, 3
    add ch, cl
    movzx ecx, ch
    xchg eax, [esi + 4 * ecx]
    mov [esi + 4 * edx], eax
    pop ecx

    inc ch
    cmp ch, 8
    jb tm_jcycle

    inc cl
    cmp cl, 8
    jb tm_icycle
    
    pop esi
ret

section .data
    cmatrix dd 0.353553, 0.353553, 0.353553, 0.353553, 0.353553, 0.353553, 0.353553, 0.353553, 0.490393, 0.415735, 0.277785, 0.0975452, -0.0975452, -0.277785, -0.415735, -0.490393, 0.46194, 0.191342, -0.191342, -0.46194, -0.46194, -0.191342, 0.191342, 0.46194, 0.415735, -0.0975452, -0.490393, -0.277785, 0.277785, 0.490393, 0.0975452, -0.415735, 0.353553, -0.353553, -0.353553, 0.353553, 0.353553, -0.353553, -0.353553, 0.353553, 0.277785, -0.490393, 0.0975452, 0.415735, -0.415735, -0.0975452, 0.490393, -0.277785, 0.191342, -0.46194, 0.46194, -0.191342, -0.191342, 0.46194, -0.46194, 0.191342, 0.0975452, -0.277785, 0.415735, -0.490393, 0.490393, -0.415735, 0.277785, -0.0975452 
    cmatrixt dd 0.353553, 0.490393, 0.46194, 0.415735, 0.353553, 0.277785, 0.191342, 0.0975452, 0.353553, 0.415735, 0.191342, -0.0975452, -0.353553, -0.490393, -0.46194, -0.277785, 0.353553, 0.277785, -0.191342, -0.490393, -0.353553, 0.0975452, 0.46194, 0.415735, 0.353553, 0.0975452, -0.46194, -0.277785, 0.353553, 0.415735, -0.191342, -0.490393, 0.353553, -0.0975452, -0.46194, 0.277785, 0.353553, -0.415735, -0.191342, 0.490393, 0.353553, -0.277785, -0.191342, 0.490393, -0.353553, -0.0975452, 0.46194, -0.415735, 0.353553, -0.415735, 0.191342, 0.0975452, -0.353553, 0.490393, -0.46194, 0.277785, 0.353553, -0.490393, 0.46194, -0.415735, 0.353553, -0.277785, 0.191342, -0.0975452
