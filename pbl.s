.data
caminho_bias: .asciz "/home/oem/Downloads/pbl/b_q.bin" @caminho do arquivo bias
buffer_bias:  .space 256 @espaço destinado ao buffer (128x2 bytes)

.text
.global _start

_start:
    bl   store_bias @chamada da função

    mov  r7, #1 
    swi  0

store_bias:
    push {r8, r9}

    ldr  r0, =caminho_bias @r0 endereço da string
    mov  r1, #0 @somente leitura
    mov  r2, #0 @nao usado
    mov  r7, #5 @syscall open
    swi  0   #chama o linux com os parametros
    mov  r8, r0 @salva em r8 o endereço da string (para nao perder)

    mov  r0, r8 (devolve o valor a r0, agora é o fd = arquivo 3 por exempo)
    ldr  r1, =buffer_bias @r1 = endereço do bias
    mov  r2, #256 @tamanho do buffer
    mov  r7, #3 @modo de leitura
    swi  0  @ chama o linux
    mov  r9, r0 @r9 pega oq devolveu (256bytes)

    mov  r0, r8 @fd novamente em r0
    mov  r7, #6 @syscall de fechamento
    swi  0 @fecha o arquivo e retorna em r0

    ldr  r0, =buffer_bias @r0 aponta para endereço do buffer
    ldrh r1, [r0] @le 2 bytes
    rev16 r1, r1 @reverte (problema de endian)
    sxth  r1, r1 @adiciona sinal

    lsl   r3, r1, #10
    ldr   r2, =0x03FFFC00
    and   r3, r3, r2
    mov   r2, #3
    orr   r2, r2, r3

    pop  {r7, r8, r9, lr}
    bx   lr