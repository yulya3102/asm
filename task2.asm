global fdct
global idct

; [esp + 4] - 8x8 matrix with points
; [esp + 8] - 8x8 result matrix
; [esp + 12] - N
idct:
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

    sub esp, 4
    push edi
    push esi
    call idct_one_matrix
    add esp, 3 * 4

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
    
    ; result = C^-1 * input * C^-1^T
    push ebp
    mov ebp, esp
    sub esp, 67 * 4
    
    mov ebx, esp    ; ebx - C^-1 * input
    sub esp, 4
    push ebx
    push esi
    push invcmatrix
    call matrix_multiplication
    add esp, 4 * 4

    sub esp, 4
    push edi
    push invcmatrixt
    push ebx
    call matrix_multiplication
    add esp, 4 * 4

    leave
    
    mov eax, edi

    pop edi
    pop esi
    pop ebx
ret

; [esp + 4] - 8x8 matrix with points
; [esp + 8] - 8x8 result matrix
; [esp + 12] - N
fdct:
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

    sub esp, 4
    push edi
    push esi
    call fdct_one_matrix
    add esp, 3 * 4

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
    sub esp, 67 * 4
    
    mov ebx, esp    ; ebx - C * input
    sub esp, 4
    push ebx
    push esi
    push cmatrix
    call matrix_multiplication
    add esp, 4 * 4

    sub esp, 4
    push edi
    push cmatrixt
    push ebx
    call matrix_multiplication
    add esp, 4 * 4

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

    sub esp, 12
    push eax
    push edx
    push ebx
    call transpose_matrix
    pop ebx
    pop edx
    pop eax
    add esp, 12

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
    movaps xmm0, [ebx + 4 * ecx]
    movaps xmm1, [ebx + 4 * ecx + 16]
    pop ecx

    ; xmm0, xmm1 = B_j
        
    xor ch, ch
mm_icycle:
    ; A_i = A + 8 * i
    push ecx
    shl ch, 3
    movzx ecx, ch
    movaps xmm2, [eax + 4 * ecx]
    movaps xmm3, [eax + 4 * ecx + 16]
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

    sub esp, 12
    push eax
    push edx
    push ebx
    call transpose_matrix
    pop ebx
    pop edx
    pop eax
    add esp, 12
       
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
    align 16
    cmatrix dd 0.125, 0.125, 0.125, 0.125, 0.125, 0.125, 0.125, 0.125, 0.17338, 0.146985, 0.0982118, 0.0344874, -0.0344874, -0.0982118, -0.146985, -0.17338, 0.16332, 0.0676496, -0.0676496, -0.16332, -0.16332, -0.0676496, 0.0676496, 0.16332, 0.146985, -0.0344874, -0.17338, -0.0982118, 0.0982118, 0.17338, 0.0344874, -0.146985, 0.125, -0.125, -0.125, 0.125, 0.125, -0.125, -0.125, 0.125, 0.0982118, -0.17338, 0.0344874, 0.146985, -0.146985, -0.0344874, 0.17338, -0.0982118, 0.0676496, -0.16332, 0.16332, -0.0676496, -0.0676496, 0.16332, -0.16332, 0.0676496, 0.0344874, -0.0982118, 0.146985, -0.17338, 0.17338, -0.146985, 0.0982118, -0.0344874
    cmatrixt dd 0.125, 0.17338, 0.16332, 0.146985, 0.125, 0.0982118, 0.0676496, 0.0344874, 0.125, 0.146985, 0.0676496, -0.0344874, -0.125, -0.17338, -0.16332, -0.0982118, 0.125, 0.0982118, -0.0676496, -0.17338, -0.125, 0.0344874, 0.16332, 0.146985, 0.125, 0.0344874, -0.16332, -0.0982118, 0.125, 0.146985, -0.0676496, -0.17338, 0.125, -0.0344874, -0.16332, 0.0982118, 0.125, -0.146985, -0.0676496, 0.17338, 0.125, -0.0982118, -0.0676496, 0.17338, -0.125, -0.0344874, 0.16332, -0.146985, 0.125, -0.146985, 0.0676496, 0.0344874, -0.125, 0.17338, -0.16332, 0.0982118, 0.125, -0.17338, 0.16332, -0.146985, 0.125, -0.0982118, 0.0676496, -0.0344874
    invcmatrix dd 1.000000,   1.387040,   1.306560,   1.175870,   1.000000,   0.785694,   0.541196,   0.275900,   1.000000,   1.175870,   0.541196,  -0.275900,  -1.000000,  -1.387040,  -1.306560,  -0.785694,   1.000000,   0.785694,  -0.541196,  -1.387040,  -1.000000,   0.275900,   1.306560,   1.175870,   1.000000,   0.275900,  -1.306560,  -0.785694,   1.000000,   1.175870,  -0.541196,  -1.387040,   1.000000,  -0.275900,  -1.306560,   0.785694,   1.000000,  -1.175870,  -0.541196,   1.387040,   1.000000,  -0.785694,  -0.541196,   1.387040,  -1.000000,  -0.275900,   1.306560,  -1.175870,   1.000000,  -1.175870,   0.541196,   0.275900,  -1.000000,   1.387040,  -1.306560,   0.785694,   1.000000,  -1.387040,   1.306560,  -1.175870,   1.000000,  -0.785694,   0.541196,  -0.275900
    invcmatrixt dd 1.000000,   1.000000,   1.000000,   1.000000,   1.000000,   1.000000,   1.000000,   1.000000,   1.387040,   1.175870,   0.785694,   0.275900,  -0.275900,  -0.785694,  -1.175870,  -1.387040,   1.306560,   0.541196,  -0.541196,  -1.306560,  -1.306560,  -0.541196,   0.541196,   1.306560,   1.175870,  -0.275900,  -1.387040,  -0.785694,   0.785694,   1.387040,   0.275900,  -1.175870,   1.000000,  -1.000000,  -1.000000,   1.000000,   1.000000,  -1.000000,  -1.000000,   1.000000,   0.785694,  -1.387040,   0.275900,   1.175870,  -1.175870,  -0.275900,   1.387040,  -0.785694,   0.541196,  -1.306560,   1.306560,  -0.541196,  -0.541196,   1.306560,  -1.306560,   0.541196,   0.275900,  -0.785694,   1.175870,  -1.387040,   1.387040,  -1.175870,   0.785694,  -0.275900
