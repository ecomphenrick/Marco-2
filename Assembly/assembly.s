.equ PIO_DATA_OUT, 0x00     @ offset do pio_data_out (FPGA → HPS)
.equ PIO_SIGNALS,  0x10     @ offset do pio_signals  (HPS → FPGA: enable/clr/rst)
.equ PIO_DATA_IN,  0x20     @ offset do pio_data_in  (HPS → FPGA: instrução)
.equ LW_BASE_PAGE, 0xFF200  @ endereço físico 0xFF200000 em páginas (>> 12)

.data
caminho_bias:   .asciz "bins/b_q.bin"       @ caminho do arquivo bias
caminho_beta:   .asciz "bins/beta_q.bin"    @ caminho do arquivo beta
caminho_imagem: .asciz "bins/3.bin"    @ caminho do arquivo imagem
caminho_pesos:  .asciz "bins/W_in_q.bin"    @ caminho do arquivo pesos
devmem:         .asciz "/dev/mem"                  @ arquivo de acesso à memória física
buffer_bias:    .space 256                          @ espaço destinado ao buffer (128x2 bytes)
buffer_beta:    .space 2560                         @ espaço destinado ao buffer (1280x2 bytes)
buffer_imagem:  .space 784                          @ espaço destinado ao buffer (784 bytes)
buffer_pesos:  .space 200704     @ 100352 × 2 bytes                       @ buffer dedicado para leitura dos pesos (1 valor x 2 bytes)
sinal:          .byte 45                            @ '-'
newline:        .byte 10                            @ '\n'
num_buf:        .space 8                            @ buffer para os dígitos
byte_buf:       .space 2                            @ buffer de 1 byte para write

.text
.global _start

_start:
    bl   mapeia_memoria                @ mapeia ponte LW → r10 = base virtual
    mov  r10, r0

    bl   reset_coprocessador    @ reseta os registradores do co-processador

    bl   store_bias             @ envia bias
    bl   store_beta             @ envia beta
    bl   store_imagem           @ envia imagem
    bl   store_pesos            @ envia pesos
    bl   start_inferencia       @ inicia inferência → resultado em r0

    and  r0, r0, #0xF           @ pega apenas bits 3-0 (dígito predito)
    bl   print_signed           @ imprime no terminal

    mov  r7, #1                 @ syscall exit
    swi  0


mapeia_memoria:
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

reset_coprocessador:
    mov  r2, #4                         @ bit 2 = reset = 1
    str  r2, [r10, #PIO_SIGNALS]        @ escreve no pio_signals
    mov  r2, #0                         @ reset = 0
    str  r2, [r10, #PIO_SIGNALS]        @ escreve no pio_signals
    bx   lr


store_bias:
    push {r8, r9, lr}

    ldr  r0, =caminho_bias      @Aponta caminho do arquivo
    mov  r1, #0                 @ Modo de Leitura
    mov  r2, #0                 @ não usado (parametro)
    mov  r7, #5                 @ syscall open (Syscall com paramêtros)
    swi  0                      @ Retorno FD (provavelmente 3)
    mov  r8, r0                 @ Salva FD em r8

    mov  r0, r8                 @ r0 = fd (Redundante, ve se tira dps)
    ldr  r1, =buffer_bias       @ r1 = endereço do buffer
    mov  r2, #256             @ tamanho do buffer
    mov  r7, #3                 @ syscall read
    swi  0                      @ syscall retorno em 0 a qtd lida
    mov  r9, r0                 @ salva em r0 p nao perder

    mov  r0, r8                 @ r0 = aponta fd
    mov  r7, #6                 @ syscall close
    swi  0                      @ fecha o arquivo

    ldr  r0, =buffer_bias       @ r0 primeiro endereço do buffer
    mov  r6, #0                 @ r6 = índice vai ate 127

bias_loop:
    cmp  r6, #128             @Quando chegar em 128 pula pra bias_fim
    beq  bias_fim

    ldrh r1, [r0]               @ le 2 bytes
    rev16 r1, r1                @ inverte os bytes
    sxth  r1, r1                @ aplica a extensão de sinal (32 bits)

    lsl   r3, r1, #10           @ shift de 10, dado no lugar certo
    ldr   r2, =0x03FFFC00       @ máscara: zera bits fora do campo do dado (fica tipo 000 | 11111 | 0000)
    and   r3, r3, r2            @ Faz a AND e fica o valor certo dos dados e os outros zerados (deu erro no padding)
    lsl   r4, r6, #3            @ msm coisa do de cima mas para o endereço agr
    ldr   r2, =0x000003F8       
    and   r4, r4, r2            
    mov   r2, #3                @ OP = 011 - Bias
    orr   r2, r2, r3            @ R2 = OPP + Dado
    orr   r2, r2, r4            @ R2 + endereço → r2 = instrução feita em r2

    bl    send_instruction      @ envia instrução.

    add  r0, r0, #2             @ avança 2 bytes no buffer (ver possibilidade de addi)
    add  r6, r6, #1             @ incrementa índice
    b    bias_loop

bias_fim:
    pop  {r8, r9, lr}
    bx   lr


store_beta:
    push {r8, r9, lr}

    ldr  r0, =caminho_beta      
    mov  r1, #0                 
    mov  r2, #0                 
    mov  r7, #5                 
    swi  0                      
    mov  r8, r0                 

    mov  r0, r8                 
    ldr  r1, =buffer_beta       
    mov  r2, #2560             
    mov  r7, #3                 
    swi  0                      @Comentar so as diferenças
    mov  r9, r0                 

    mov  r0, r8                 
    mov  r7, #6                
    swi  0                      

    ldr  r0, =buffer_beta       
    mov  r6, #0                 

beta_loop:
    ldr  r5, =1280              
    cmp  r6, r5                 
    beq  beta_fim

    ldrh r1, [r0]               
    rev16 r1, r1               
    sxth  r1, r1                

    lsl   r3, r1, #14           
    ldr   r2, =0x3FFFC000       
    and   r3, r3, r2            
    lsl   r4, r6, #3            
    ldr   r2, =0x00003FF8       
    and   r4, r4, r2            
    mov   r2, #4                
    orr   r2, r2, r3            
    orr   r2, r2, r4            

    bl    send_instruction      

    add  r0, r0, #2             
    add  r6, r6, #1             
    b    beta_loop

beta_fim:
    pop  {r8, r9, lr}
    bx   lr


store_imagem:
    push {r8, r9, lr}

    ldr  r0, =caminho_imagem    
    mov  r1, #0                 
    mov  r2, #0                 
    mov  r7, #5                 
    swi  0                      
    mov  r8, r0                 

    mov  r0, r8                 
    ldr  r1, =buffer_imagem     
    mov  r2, #784             
    mov  r7, #3                 
    swi  0                      
    mov  r9, r0                 

    mov  r0, r8                 
    mov  r7, #6                 
    swi  0                      

    ldr  r0, =buffer_imagem     
    mov  r6, #0                 

imagem_loop:
    ldr  r5, =784               
    cmp  r6, r5                 
    beq  imagem_fim

    ldrb r1, [r0]               @ lê 1 byte sem sinal (Sem sinal e sem precisar reverter)

    lsl   r3, r1, #13           
    ldr   r2, =0x001FE000       
    and   r3, r3, r2            
    lsl   r4, r6, #3            
    ldr   r2, =0x00001FF8       
    and   r4, r4, r2            
    mov   r2, #0                
    orr   r2, r2, r3          
    orr   r2, r2, r4            

    bl    send_instruction      

    add  r0, r0, #1             @ avança 1 byte no buffer (avança so 1byte)
    add  r6, r6, #1             
    b    imagem_loop

imagem_fim:
    pop  {r8, r9, lr}
    bx   lr


store_pesos:
    push {r8, lr}               

    ldr  r0, =caminho_pesos @aponta para string
    mov  r1, #0
    mov  r2, #0
    mov  r7, #5
    swi  0
    mov  r8, r0 @fd em r8 e r0

    mov  r0, r8
    ldr  r1, =buffer_pesos
    ldr  r2, =200704            @le 200704 valores e coloca em buffer pesos
    mov  r7, #3
    swi  0

    mov  r0, r8
    mov  r7, #6
    swi  0

    ldr  r0, =buffer_pesos      @ r0 aponta para o início
    mov  r6, #0                 @ índice

pesos_loop:
    ldr  r5, =100352
    cmp  r6, r5
    beq  pesos_fim

    ldrh r1, [r0]               @ lê direto do buffer
    rev16 r1, r1
    sxth  r1, r1

    @ instrução de endereço
    lsl   r3, r6, #3
    ldr   r2, =0x000FFFF8
    and   r3, r3, r2
    mov   r2, #1
    orr   r2, r2, r3
    bl    send_no_wait

    @ instrução de valor
    lsl   r3, r1, #3
    ldr   r2, =0x0007FFF8
    and   r3, r3, r2
    mov   r2, #2
    orr   r2, r2, r3
    bl    send_instruction

    add  r0, r0, #2             @ avança 2 bytes (igual ao bias/beta)
    add  r6, r6, #1
    b    pesos_loop

pesos_fim:
    pop  {r8, lr}
    bx   lr


start_inferencia:
    push {r7, lr}

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

    pop  {r7, lr}
    bx   lr


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

 
send_no_wait:
    str  r2, [r10, #PIO_DATA_IN]        @ escreve instrução no pio_data_in
    mov  r2, #1                         @ enable = 1
    str  r2, [r10, #PIO_SIGNALS]        @ escreve no pio_signals
    mov  r2, #0                         @ enable = 0
    str  r2, [r10, #PIO_SIGNALS]        @ escreve no pio_signals
    bx   lr

@ ============================================================
@ print_signed(r0): imprime r0 como decimal com sinal + newline
@ ============================================================
print_signed:
    push {r4, r5, r6, r7, r10, r11, lr}

    mov  r4, r0                 @ r4 = valor a imprimir
    ldr  r5, =num_buf           @ r5 = buffer de dígitos
    mov  r6, #0                 @ r6 = contador de dígitos

    cmp  r4, #0                 @ é negativo?
    bge  ps_positivo

    mov  r0, #1                 @ escreve '-'
    ldr  r1, =sinal
    mov  r2, #1
    mov  r7, #4
    swi  0
    rsb  r4, r4, #0             @ inverte sinal

ps_positivo:
    cmp  r4, #0                 @ é zero?
    bne  ps_extrai

    mov  r3, #48                @ caractere '0'
    strb r3, [r5]
    mov  r6, #1
    b    ps_imprime

ps_extrai:
    cmp  r4, #0                 @ extrai dígitos por divisão
    beq  ps_imprime

    mov  r10, r4
    mov  r11, #0

ps_div:
    cmp  r10, #10
    blt  ps_div_fim
    sub  r10, r10, #10
    add  r11, r11, #1
    b    ps_div

ps_div_fim:
    add  r3, r10, #48           @ converte dígito para ASCII
    strb r3, [r5, r6]
    add  r6, r6, #1
    mov  r4, r11
    b    ps_extrai

ps_imprime:
    sub  r6, r6, #1
    ldr  r5, =num_buf

ps_imp_loop:
    cmp  r6, #0
    blt  ps_newline

    ldrb r3, [r5, r6]
    ldr  r10, =byte_buf
    strb r3, [r10]

    mov  r0, #1
    mov  r1, r10
    mov  r2, #1
    mov  r7, #4
    swi  0

    sub  r6, r6, #1
    b    ps_imp_loop

ps_newline:
    mov  r0, #1
    ldr  r1, =newline
    mov  r2, #1
    mov  r7, #4
    swi  0

    pop  {r4, r5, r6, r7, r10, r11, lr}
    bx   lr