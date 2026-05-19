@ ============================================================
@ Constantes — equivalente aos #define do C
@ ============================================================
.equ PIO_DATA_OUT, 0x00     @ offset do pio_data_out (FPGA → HPS)
.equ PIO_SIGNALS,  0x10     @ offset do pio_signals  (HPS → FPGA: enable/clr/rst)
.equ PIO_DATA_IN,  0x20     @ offset do pio_data_in  (HPS → FPGA: instrução)
.equ LW_BASE_PAGE, 0xFF200  @ endereço físico 0xFF200000 em páginas (>> 12)

.data
devmem:         .asciz "/dev/mem"                   @ arquivo de acesso à memória física

buffer_bias:    .space 256                          @ espaço destinado ao buffer (128x2 bytes)
buffer_beta:    .space 2560                         @ espaço destinado ao buffer (1280x2 bytes)
buffer_imagem:  .space 784                          @ espaço destinado ao buffer (784 bytes)
buffer_pesos:   .space 2                            @ buffer dedicado para leitura dos pesos (1 valor x 2 bytes)

.text
.global mmap_lw
.global reset_coprocessador
.global store_bias
.global store_beta
.global store_imagem
.global store_pesos
.global start_inferencia

@ ============================================================
@ mmap_lw: abre /dev/mem e mapeia a ponte LW (0xFF200000)
@ Retorna: r0 = ponteiro virtual para a base
@ ============================================================
mmap_lw:
    push {r4, r5, r7, lr}
    
    ldr  r0, =devmem            @ r0 = endereço da string "/dev/mem"
    mov  r1, #2                 @ O_RDWR
    mov  r2, #0                 @ não usado
    mov  r7, #5                 @ syscall open
    swi  0                      @ chama o Linux → fd em r0
    mov  r4, r0                 @ salva fd do /dev/mem

    mov  r0, #0                 @ addr = NULL (kernel escolhe)
    mov  r1, #0x1000            @ length = 1 página (4096 bytes)
    mov  r2, #3                 @ PROT_READ | PROT_WRITE
    mov  r3, #1                 @ MAP_SHARED
    ldr  r5, =LW_BASE_PAGE      @ offset em páginas (0xFF200000 >> 12)
    mov  r7, #192               @ syscall mmap2
    swi  0                      @ chama o Linux → r0 = ponteiro virtual
    
    pop  {r4, r5, r7, lr}
    bx   lr

@ ============================================================
@ reset_coprocessador: reseta os registradores do co-processador
@ Parâmetros: r0 = base virtual da ponte
@ ============================================================
reset_coprocessador:
    push {r10, lr}
    mov  r10, r0                        

    mov  r2, #4                         @ bit 2 = reset = 1
    str  r2, [r10, #PIO_SIGNALS]        @ escreve no pio_signals
    mov  r2, #0                         @ reset = 0
    str  r2, [r10, #PIO_SIGNALS]        @ escreve no pio_signals
    
    pop  {r10, lr}
    bx   lr

@ ============================================================
@ store_bias: lê buffer e envia 128 instruções ao co-processador
@ Formato: [ não usado(6) | dado(16) bits 25-10 | endereço(7) bits 9-3 | OP(3)=011 ]
@ Parâmetros: r0 = base virtual da ponte, r1 = endereço da string do caminho
@ ============================================================
store_bias:
    push {r8, r9, r10, lr}
    mov  r10, r0                        
    
    mov  r0, r1                 @ r0 = endereço da string do caminho passado pela API
    mov  r1, #0                 @ somente leitura
    mov  r2, #0                 @ não usado
    mov  r7, #5                 @ syscall open
    swi  0                      @ chama o Linux → fd em r0
    mov  r8, r0                 @ salva o fd em r8

    mov  r0, r8                 @ r0 = fd
    ldr  r1, =buffer_bias       @ r1 = endereço do buffer
    mov  r2, #256               @ tamanho do buffer
    mov  r7, #3                 @ syscall read
    swi  0                      @ chama o Linux → bytes lidos em r0
    mov  r9, r0                 @ salva quantos bytes foram lidos

    mov  r0, r8                 @ r0 = fd
    mov  r7, #6                 @ syscall close
    swi  0                      @ fecha o arquivo

    ldr  r0, =buffer_bias       @ r0 = endereço do buffer
    mov  r6, #0                 @ r6 = índice (0..127)

bias_loop:
    cmp  r6, #128               @ chegou ao fim?
    beq  bias_fim

    ldrh r1, [r0]               @ lê 2 bytes sem sinal
    rev16 r1, r1                @ corrige endian
    sxth  r1, r1                @ aplica sinal (16 → 32 bits)

    lsl   r3, r1, #10           @ desloca dado para bits 25-10
    ldr   r2, =0x03FFFC00       @ máscara: zera bits fora do campo do dado
    and   r3, r3, r2            @ aplica máscara
    lsl   r4, r6, #3            @ desloca endereço para bits 9-3
    ldr   r2, =0x000003F8       @ máscara: zera bits fora do campo do endereço
    and   r4, r4, r2            @ aplica máscara
    mov   r2, #3                @ OP = 011 (STORE_BIAS)
    orr   r2, r2, r3            @ junta OP + dado
    orr   r2, r2, r4            @ junta + endereço → r2 = instrução montada

    bl    send_instruction      @ envia instrução e aguarda DONE

    add  r0, r0, #2             @ avança 2 bytes no buffer
    add  r6, r6, #1             @ incrementa índice
    b    bias_loop

bias_fim:
    pop  {r8, r9, r10, lr}
    bx   lr

@ ============================================================
@ store_beta: lê buffer e envia 1280 instruções ao co-processador
@ Formato: [ não usado(2) | dado(16) bits 29-14 | endereço(11) bits 13-3 | OP(3)=100 ]
@ Parâmetros: r0 = base virtual da ponte, r1 = endereço da string do caminho
@ ============================================================
store_beta:
    push {r8, r9, r10, lr}
    mov  r10, r0                        

    mov  r0, r1                 @ r0 = endereço da string do caminho
    mov  r1, #0                 @ somente leitura
    mov  r2, #0                 @ não usado
    mov  r7, #5                 @ syscall open
    swi  0                      @ chama o Linux → fd em r0
    mov  r8, r0                 @ salva o fd em r8

    mov  r0, r8                 @ r0 = fd
    ldr  r1, =buffer_beta       @ r1 = endereço do buffer
    mov  r2, #2560              @ tamanho do buffer
    mov  r7, #3                 @ syscall read
    swi  0                      @ chama o Linux → bytes lidos em r0
    mov  r9, r0                 @ salva quantos bytes foram lidos

    mov  r0, r8                 @ r0 = fd
    mov  r7, #6                 @ syscall close
    swi  0                      @ fecha o arquivo

    ldr  r0, =buffer_beta       @ r0 = endereço do buffer
    mov  r6, #0                 @ r6 = índice (0..1279)

beta_loop:
    ldr  r5, =1280              @ limite do loop
    cmp  r6, r5                 @ chegou ao fim?
    beq  beta_fim

    ldrh r1, [r0]               @ lê 2 bytes sem sinal
    rev16 r1, r1                @ corrige endian
    sxth  r1, r1                @ aplica sinal (16 → 32 bits)

    lsl   r3, r1, #14           @ desloca dado para bits 29-14
    ldr   r2, =0x3FFFC000       @ máscara: zera bits fora do campo do dado
    and   r3, r3, r2            @ aplica máscara
    lsl   r4, r6, #3            @ desloca endereço para bits 13-3
    ldr   r2, =0x00003FF8       @ máscara: zera bits fora do campo do endereço
    and   r4, r4, r2            @ aplica máscara
    mov   r2, #4                @ OP = 100 (STORE_BETA)
    orr   r2, r2, r3            @ junta OP + dado
    orr   r2, r2, r4            @ junta + endereço → r2 = instrução montada

    bl    send_instruction      @ envia instrução e aguarda DONE

    add  r0, r0, #2             @ avança 2 bytes no buffer
    add  r6, r6, #1             @ incrementa índice
    b    beta_loop

beta_fim:
    pop  {r8, r9, r10, lr}
    bx   lr

@ ============================================================
@ store_imagem: lê buffer e envia 784 instruções ao co-processador
@ Formato: [ padding(11) | dado(8) bits 20-13 | endereço(10) bits 12-3 | OP(3)=000 ]
@ Parâmetros: r0 = base virtual da ponte, r1 = endereço da string do caminho
@ ============================================================
store_imagem:
    push {r8, r9, r10, lr}
    mov  r10, r0                        

    mov  r0, r1                 @ r0 = endereço da string do caminho
    mov  r1, #0                 @ somente leitura
    mov  r2, #0                 @ não usado
    mov  r7, #5                 @ syscall open
    swi  0                      @ chama o Linux → fd em r0
    mov  r8, r0                 @ salva o fd em r8

    mov  r0, r8                 @ r0 = fd
    ldr  r1, =buffer_imagem     @ r1 = endereço do buffer
    mov  r2, #784               @ tamanho do buffer
    mov  r7, #3                 @ syscall read
    swi  0                      @ chama o Linux → bytes lidos em r0
    mov  r9, r0                 @ salva quantos bytes foram lidos

    mov  r0, r8                 @ r0 = fd
    mov  r7, #6                 @ syscall close
    swi  0                      @ fecha o arquivo

    ldr  r0, =buffer_imagem     @ r0 = endereço do buffer
    mov  r6, #0                 @ r6 = índice (0..783)

imagem_loop:
    ldr  r5, =784               @ limite do loop
    cmp  r6, r5                 @ chegou ao fim?
    beq  imagem_fim

    ldrb r1, [r0]               @ lê 1 byte sem sinal (pixel)

    lsl   r3, r1, #13           @ desloca dado para bits 20-13
    ldr   r2, =0x001FE000       @ máscara: zera bits fora do campo do dado
    and   r3, r3, r2            @ aplica máscara
    lsl   r4, r6, #3            @ desloca endereço para bits 12-3
    ldr   r2, =0x00001FF8       @ máscara: zera bits fora do campo do endereço
    and   r4, r4, r2            @ aplica máscara
    mov   r2, #0                @ OP = 000 (STORE_IMAGE)
    orr   r2, r2, r3            @ junta OP + dado
    orr   r2, r2, r4            @ junta + endereço → r2 = instrução montada

    bl    send_instruction      @ envia instrução e aguarda DONE

    add  r0, r0, #1             @ avança 1 byte no buffer
    add  r6, r6, #1             @ incrementa índice
    b    imagem_loop

imagem_fim:
    pop  {r8, r9, r10, lr}
    bx   lr

@ ============================================================
@ store_pesos: envia 100352 pares addr+value ao co-processador
@ Addr:  [ não usado(12) | endereço(17) bits 19-3 | OP(3)=001 ] SEM DONE
@ Value: [ não usado(13) | dado(16) bits 18-3      | OP(3)=010 ] COM DONE
@ Parâmetros: r0 = base virtual da ponte, r1 = endereço da string do caminho
@ ============================================================
store_pesos:
    push {r8, r9, r10, r11, r12, lr}
    mov  r10, r0                        

    mov  r0, r1                 @ r0 = endereço da string do caminho
    mov  r1, #0                 @ somente leitura
    mov  r2, #0                 @ não usado
    mov  r7, #5                 @ syscall open
    swi  0                      @ chama o Linux → fd em r0
    mov  r8, r0                 @ salva o fd em r8

    mov  r12, #0                @ r12 = índice global (0..100351)

pesos_loop:
    ldr  r5, =100352            @ limite do loop
    cmp  r12, r5                @ chegou ao fim?
    beq  pesos_fim

    mov  r0, r8                 @ r0 = fd
    ldr  r1, =buffer_pesos      @ r1 = buffer dedicado de 2 bytes
    mov  r2, #2                 @ lê 2 bytes (1 valor)
    mov  r7, #3                 @ syscall read
    swi  0                      @ chama o Linux

    ldr  r11, =buffer_pesos     @ r11 = endereço do buffer
    ldrh r1, [r11]              @ lê valor do buffer
    rev16 r1, r1                @ corrige endian
    sxth  r1, r1                @ aplica sinal

    @ monta instrução de endereço (SEM DONE)
    lsl   r3, r12, #3           @ desloca endereço para bits 19-3
    ldr   r2, =0x000FFFF8       @ máscara: zera bits fora do campo do endereço
    and   r3, r3, r2            @ aplica máscara
    mov   r2, #1                @ OP = 001 (STORE_WEIGHTS_ADDR)
    orr   r2, r2, r3            @ r2 = instrução de endereço montada
    bl    send_no_wait          @ envia SEM aguardar DONE

    @ monta instrução de valor (COM DONE)
    lsl   r3, r1, #3            @ desloca dado para bits 18-3
    ldr   r2, =0x0007FFF8       @ máscara: zera bits fora do campo do dado
    and   r3, r3, r2            @ aplica máscara
    mov   r2, #2                @ OP = 010 (STORE_WEIGHTS_VALUE)
    orr   r2, r2, r3            @ r2 = instrução de valor montada
    bl    send_instruction      @ envia e aguarda DONE

    add  r12, r12, #1           @ incrementa índice
    b    pesos_loop

pesos_fim:
    mov  r0, r8                 @ r0 = fd
    mov  r7, #6                 @ syscall close
    swi  0                      @ fecha o arquivo

    pop  {r8, r9, r10, r11, r12, lr}
    bx   lr

@ ============================================================
@ start_inferencia: envia START e lê resultado após DONE subir
@ DONE só sobe após enable=0 (conforme documentação)
@ Retorna: r0 = data_out (bits 3-0 = dígito predito)
@ Parâmetros: r0 = base virtual da ponte
@ ============================================================
start_inferencia:
    push {r7, r10, lr}
    mov  r10, r0                        

    mov  r2, #5                         @ OP = 101 (START)
    str  r2, [r10, #PIO_DATA_IN]        @ escreve no pio_data_in
    mov  r2, #1                         @ enable = 1 (latch da instrução)
    str  r2, [r10, #PIO_SIGNALS]        @ escreve no pio_signals
    mov  r2, #0                         @ enable = 0 (DONE só sobe após isso)
    str  r2, [r10, #PIO_SIGNALS]        @ escreve no pio_signals

start_poll:
    ldr  r2, [r10, #PIO_DATA_OUT]       @ lê pio_data_out
    tst  r2, #(1 << 4)                  @ testa bit DONE (bit 4)
    beq  start_poll                     @ se DONE = 0, continua aguardando

    ldr  r0, [r10, #PIO_DATA_OUT]       @ lê resultado

    pop  {r7, r10, lr}
    bx   lr

@ ============================================================
@ send_instruction: escreve instrução, pulsa enable e aguarda DONE
@ DONE só sobe após enable=0 (conforme documentação)
@ Entrada: r2 = instrução de 32 bits, r10 = base virtual da ponte
@ ============================================================
send_instruction:
    push {r7, lr}
    str  r2, [r10, #PIO_DATA_IN]        @ escreve instrução no pio_data_in
    mov  r2, #1                         @ enable = 1 (latch da instrução)
    str  r2, [r10, #PIO_SIGNALS]        @ escreve no pio_signals
    mov  r2, #0                         @ enable = 0 (DONE só sobe após isso)
    str  r2, [r10, #PIO_SIGNALS]        @ escreve no pio_signals
poll_done:
    ldr  r2, [r10, #PIO_DATA_OUT]       @ lê pio_data_out
    tst  r2, #(1 << 4)                  @ testa bit DONE (bit 4)
    beq  poll_done                      @ se DONE = 0, continua aguardando
    pop  {r7, lr}
    bx   lr

@ ============================================================
@ send_no_wait: escreve instrução e pulsa enable sem aguardar DONE
@ Store Weights Addr não ativa DONE e leva apenas 2 ciclos
@ Entrada: r2 = instrução de 32 bits, r10 = base virtual da ponte
@ ============================================================
send_no_wait:
    str  r2, [r10, #PIO_DATA_IN]        @ escreve instrução no pio_data_in
    mov  r2, #1                         @ enable = 1
    str  r2, [r10, #PIO_SIGNALS]        @ escreve no pio_signals
    mov  r2, #0                         @ enable = 0
    str  r2, [r10, #PIO_SIGNALS]        @ escreve no pio_signals
    bx   lr
