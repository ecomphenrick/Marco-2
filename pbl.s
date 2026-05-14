.data
caminho_bias: .asciz "/home/oem/Downloads/pbl/b_q.bin"
buffer_bias:  .space 256

.text
.global _start

_start:
    bl   store_bias

    mov  r7, #1
    swi  0

@ ============================================================
@ store_bias: lê buffer e monta instrução
@ ============================================================
store_bias:
    push {r7, r8, r9, lr}

    ldr  r0, =caminho_bias
    mov  r1, #0
    mov  r2, #0
    mov  r7, #5
    swi  0
    mov  r8, r0

    mov  r0, r8
    ldr  r1, =buffer_bias
    mov  r2, #256
    mov  r7, #3
    swi  0
    mov  r9, r0

    mov  r0, r8
    mov  r7, #6
    swi  0

    ldr  r0, =buffer_bias
    ldrh r1, [r0]
    rev16 r1, r1
    sxth  r1, r1

    lsl   r3, r1, #10
    ldr   r2, =0x03FFFC00
    and   r3, r3, r2
    mov   r2, #3
    orr   r2, r2, r3

    pop  {r7, r8, r9, lr}
    bx   lr