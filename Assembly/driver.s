.equ PIO_DATA_OUT, 0x00     
.equ PIO_SIGNALS,  0x10     
.equ PIO_DATA_IN,  0x20     
.equ LW_BASE_PAGE, 0xFF200  

.data
devmem:         .asciz "/dev/mem"                   

.balign 4       
buffer_bias:    .space 256                          
buffer_beta:    .space 2560                         
buffer_imagem:  .space 784                          
buffer_pesos:   .space 200704                            
.balign 4       

.text
.global mapeia_memoria
.type mapeia_memoria, %function

.global reset_coprocessador
.type reset_coprocessador, %function

.global store_bias
.type store_bias, %function

.global store_beta
.type store_beta, %function

.global store_imagem
.type store_imagem, %function

.global store_pesos
.type store_pesos, %function

.global comeca_infer
.type comeca_infer, %function

mapeia_memoria:
    push {r4, r5, r7, lr}
    
    ldr  r0, =devmem            
    mov  r1, #2                 @ O_RDWR (Conforme seu código funcional)
    mov  r2, #0                 
    mov  r7, #5                 
    swi  0                      
    mov  r4, r0                 

    mov  r0, #0                 
    mov  r1, #0x1000            
    mov  r2, #3                 
    mov  r3, #1                 
    ldr  r5, =LW_BASE_PAGE      
    mov  r7, #192               
    swi  0                      
    
    pop  {r4, r5, r7, lr}
    bx   lr

reset_coprocessador:
    push {r10, lr}
    mov  r10, r0                        

    mov  r2, #4                         
    str  r2, [r10, #PIO_SIGNALS]        
    mov  r2, #0                         
    str  r2, [r10, #PIO_SIGNALS]        
    
    pop  {r10, lr}
    bx   lr


store_bias:
    push {r4, r5, r6, r7, r8, r9, r10, lr}
    mov  r10, r0                @ r0 recebe a base virtual do C. Salva em r10.
    
    mov  r0, r1                 @ aponta para o endereço da string
    mov  r1, #0                 @parametro rd only
    mov  r2, #0                 @nao usado (parametro)
    mov  r7, #5                 @syscall opne
    swi  0                      @Passa para o linux que devolve o FD em r0
    mov  r8, r0                 @r8 = fd, r0 vai ser perdido

    mov  r0, r8                 @talvez redundante
    ldr  r1, =buffer_bias       @colocar em buffer bias
    mov  r2, #256             @256 bytes de r0
    mov  r7, #3                 @syscall read
    swi  0                      @r0 qtd bytes lidos
    mov  r9, r0                 @salva em r9

    mov  r0, r8                 @syscall de close
    mov  r7, #6                 
    swi  0                      

    ldr  r0, =buffer_bias      @r0 aponta para o primeiro valor do buffer 
    mov  r6, #0                @iterador, começa em 0 

bias_loop:
    cmp  r6, #128            @acaba quando r6 chegar em 128   
    beq  bias_fim              @quando acabar pula pra bias_fim

    ldrh r1, [r0]              @le valor sem sinal 
    rev16 r1, r1               @reverte sinal
    sxth  r1, r1               @extende o sinal talvez revsh resolvesse

    @montando instrução
    lsl   r3, r1, #10          @desloca os 16 bits do valor para o lugar correto
    ldr   r2, =0x03FFFC00      @r2 = 000 | 11111... | 0000  
    and   r3, r3, r2           @máscara para zerar os valores fora do campo do valor 
    lsl   r4, r6, #3           @mesma coisa para o endereço 
    ldr   r2, =0x000003F8       
    and   r4, r4, r2            
    mov   r2, #3               @r2 = opcode de store bias 
    orr   r2, r2, r3           @Or entre OP e valor 
    orr   r2, r2, r4           @Or entre OP + Valor e endereço 

    bl    mandar_instrucao     @passa r2 para mandar_instrucao  

    add  r0, r0, #2             @avança 2 bytes no valor
    add  r6, r6, #1             @avança 1 bytes no iterador
    b    bias_loop              @volta para inicio do loop

bias_fim:
    pop  {r4, r5, r6, r7, r8, r9, r10, lr} @tira pilha
    bx   lr                                @volta para a função que chamou


@Para o store Beta o procedimento é o mesmo, muda apenas os valores e o formato da instrução
store_beta:
    push {r4, r5, r6, r7, r8, r9, r10, lr}
    mov  r10, r0                        

    mov  r0, r1                 
    mov  r1, #0                 
    mov  r2, #0                 
    mov  r7, #5                 
    swi  0                      
    mov  r8, r0                 

    mov  r0, r8                 
    ldr  r1, =buffer_beta       
    mov  r2, #2560              
    mov  r7, #3                 
    swi  0                      
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

    bl    mandar_instrucao      

    add  r0, r0, #2             
    add  r6, r6, #1             
    b    beta_loop

beta_fim:
    pop  {r4, r5, r6, r7, r8, r9, r10, lr}
    bx   lr

@procedimento parecido, mas a imagem tem apenas 1 bytes sem sinal por valor
store_imagem:
    push {r4, r5, r6, r7, r8, r9, r10, lr}
    mov  r10, r0                        

    mov  r0, r1                 
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

    ldrb r1, [r0]           @grande mudança acontece aqui     

    lsl   r3, r1, #13           
    ldr   r2, =0x001FE000       
    and   r3, r3, r2            
    lsl   r4, r6, #3            
    ldr   r2, =0x00001FF8       
    and   r4, r4, r2            
    mov   r2, #0                
    orr   r2, r2, r3            
    orr   r2, r2, r4            

    bl    mandar_instrucao      

    add  r0, r0, #1             
    add  r6, r6, #1             
    b    imagem_loop

imagem_fim:
    pop  {r4, r5, r6, r7, r8, r9, r10, lr}
    bx   lr

@procedimento de leitura igual as outras, mas monta duas instruções
store_pesos:
    push {r4, r5, r6, r7, r8, r9, r10, lr}
    mov  r10, r0                        

    mov  r0, r1                 
    mov  r1, #0                 
    mov  r2, #0                 
    mov  r7, #5                 
    swi  0                      
    mov  r8, r0                 

    mov  r0, r8                 
    ldr  r1, =buffer_pesos      
    ldr  r2, =200704            
    mov  r7, #3                 
    swi  0                      

    mov  r0, r8                 
    mov  r7, #6                 
    swi  0                      

    ldr  r0, =buffer_pesos      
    mov  r6, #0                 

pesos_loop:
    ldr  r5, =100352
    cmp  r6, r5
    beq  pesos_fim

    ldrh r1, [r0]               
    rev16 r1, r1
    sxth  r1, r1

    @ instrução de endereço
    lsl   r3, r6, #3
    ldr   r2, =0x000FFFF8
    and   r3, r3, r2
    mov   r2, #1
    orr   r2, r2, r3
    bl    mandar_sem_espera

    @ instrução de valor
    lsl   r3, r1, #3
    ldr   r2, =0x0007FFF8
    and   r3, r3, r2
    mov   r2, #2
    orr   r2, r2, r3
    bl    mandar_instrucao

    add  r0, r0, #2             
    add  r6, r6, #1
    b    pesos_loop

pesos_fim:
    pop  {r4, r5, r6, r7, r8, r9, r10, lr}
    bx   lr

@falta comentar a partir daqui
comeca_infer:
    push {r7, r10, lr}
    mov  r10, r0                        

    mov  r2, #5                         
    str  r2, [r10, #PIO_DATA_IN]        
    mov  r2, #1                         
    str  r2, [r10, #PIO_SIGNALS]        
    mov  r2, #0                         
    str  r2, [r10, #PIO_SIGNALS]        

comecar_poll:
    ldr  r2, [r10, #PIO_DATA_OUT]       
    tst  r2, #(1 << 4)                  
    beq  comecar_poll                     

    ldr  r0, [r10, #PIO_DATA_OUT]       

    pop  {r7, r10, lr}
    bx   lr


mandar_instrucao:
    push {r7, lr}
    str  r2, [r10, #PIO_DATA_IN]        
    mov  r2, #1                         
    str  r2, [r10, #PIO_SIGNALS]        
    mov  r2, #0                         
    str  r2, [r10, #PIO_SIGNALS]        
poll_fim:
    ldr  r2, [r10, #PIO_DATA_OUT]       
    tst  r2, #(1 << 4)                  
    beq  poll_fim                      
    pop  {r7, lr}
    bx   lr

mandar_sem_espera:
    str  r2, [r10, #PIO_DATA_IN]        
    mov  r2, #1                         
    str  r2, [r10, #PIO_SIGNALS]        
    mov  r2, #0                         
    str  r2, [r10, #PIO_SIGNALS]        
    bx   lr