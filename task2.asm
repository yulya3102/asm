global main
main:

ret

; [esp + 4] - 8x8 matrix with points
; [esp + 8] - 8x8 result matrix
; [esp + 12] - N
fdct:
    

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

    ; eax - A
    ; ebx - B
    ; edx - A * B

    ; for j = 0..7 
    ;   xmm0, xmm1 = B_j
    ;   for i = 0..7
    ;       xmm2, xmm3 = A_i
    ;       xmm0, xmm1 = A_i * B_j
    ;       C_ij = sum xmm0, xmm1

    xor ecx, ecx
mm_jcycle:
    ; TODO:
    ; B_j[i] = B + 8 * i + j

    ; xmm0, xmm1 = B_j
        
    xor ch, ch
mm_icycle:
    ; A_i = A + 8 * i
    push ecx
    shl ch, 3
    movzx ecx, ch
    movaps xmm2, [eax + ecx]
    movaps xmm3, [eax + ecx + 128]
    pop ecx

    ; xmm2, xmm3 = A_i

    mulps xmm0, xmm2
    mulps xmm1, xmm3
    addps xmm0, xmm1

    haddps xmm0, xmm0
    haddps xmm0, xmm0

    ; C_ij = [edx + 8 * i + j]
    push ecx
    shl ch, 3
    add ch, cl
    movzx ecx, ch
    movss [edx + ecx], xmm0
    pop ecx

    inc ch
    cmp ch, 8
    jb mm_icycle
    inc cl
    cmp cl, 8
    jb mm_jcycle
       
    pop ebx
    mov eax, edx
ret
