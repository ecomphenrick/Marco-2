.data
devmem:       .asciz "/dev/mem"
caminho_bias: .asciz "/home/oem/Downloads/pbl/b_q.bin"
buffer_bias:  .space 256

.text
.global _start

_start:
    bl mmap_lw
    mov r10, r0         @ r10 = base virtual da ponte LW

    bl store_bias

    mov r7, #1
    swi 0

@ ============================================================
@ mmap_lw: abre /dev/mem e mapeia a ponte LW (0xFF200000)
@ Retorna: r0 = ponteiro virtual para a base
@ ============================================================
mmap_lw:
    push {r4, r5, r7, lr}

    ldr  r0, =devmem
    mov  r1, #2                 @ O_RDWR
    mov  r2, #0
    mov  r7, #5                 @ syscall open
    swi  0
    mov  r4, r0                 @ r4 = fd

    mov  r0, #0                 @ addr = NULL
    mov  r1, #0x1000            @ length = 1 página
    mov  r2, #3                 @ PROT_READ | PROT_WRITE
    mov  r3, #1                 @ MAP_SHARED
    ldr  r5, =0xFF200           @ offset em páginas
    mov  r7, #192               @ syscall mmap2
    swi  0

    pop  {r4, r5, r7, lr}
    bx   lr

@ ============================================================
@ store_bias: lê buffer_bias e envia o primeiro valor ao co-processador
@ Depende: r10 = base virtual da ponte
@ ============================================================
store_bias:
    push {r7, r8, lr}

    @ abre o arquivo
    ldr  r0, =caminho_bias
    mov  r1, #0                 @ O_RDONLY
    mov  r2, #0
    mov  r7, #5
    swi  0
    mov  r8, r0                 @ r8 = fd

    @ lê 256 bytes para o buffer
    mov  r0, r8
    ldr  r1, =buffer_bias
    mov  r2, #256
    mov  r7, #3
    swi  0

    @ fecha o arquivo
    mov  r0, r8
    mov  r7, #6
    swi  0

    @ lê primeiro valor do buffer (big-endian, com sinal)
    ldr  r0, =buffer_bias
    ldrh r1, [r0]
    rev16 r1, r1
    sxth  r1, r1                @ r1 = valor do bias

    @ monta instrução Store Bias (endereço 0)
    mov  r2, #3                 @ OP = 011
    lsl  r3, r1, #10            @ dado nos bits 25-10
    orr  r2, r2, r3             @ r2 = instrução completa

    @ escreve no pio_data_in
    str  r2, [r10, #0x20]

    pop  {r7, r8, lr}
    bx   lr
