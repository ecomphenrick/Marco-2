@ ============================================================
@ Constantes
@ ============================================================
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
.global mmap_lw
.type mmap_lw, %function

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

.global start_inferencia
.type start_inferencia, %function

@ ============================================================
mmap_lw:
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

@ ============================================================
reset_coprocessador:
    push {r10, lr}
    mov  r10, r0                        

    mov  r2, #4                         
    str  r2, [r10, #PIO_SIGNALS]        
    mov  r2, #0                         
    str  r2, [r10, #PIO_SIGNALS]        
    
    pop  {r10, lr}
    bx   lr

@ ============================================================
store_bias:
    push {r4, r5, r6, r7, r8, r9, r10, lr}
    mov  r10, r0                @ r0 recebe a base virtual do C. Salva em r10.
    
    mov  r0, r1                 @ r1 recebe a string do C. Move para r0 (open).
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
    mov  r6, #0                 

bias_loop:
    cmp  r6, #128               
    beq  bias_fim

    ldrh r1, [r0]               
    rev16 r1, r1                
    sxth  r1, r1                

    lsl   r3, r1, #10           
    ldr   r2, =0x03FFFC00       
    and   r3, r3, r2            
    lsl   r4, r6, #3            
    ldr   r2, =0x000003F8       
    and   r4, r4, r2            
    mov   r2, #3                
    orr   r2, r2, r3            
    orr   r2, r2, r4            

    bl    send_instruction  

    add  r0, r0, #2             
    add  r6, r6, #1             
    b    bias_loop

bias_fim:
    pop  {r4, r5, r6, r7, r8, r9, r10, lr}
    bx   lr

@ ============================================================
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

    bl    send_instruction      

    add  r0, r0, #2             
    add  r6, r6, #1             
    b    beta_loop

beta_fim:
    pop  {r4, r5, r6, r7, r8, r9, r10, lr}
    bx   lr

@ ============================================================
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

    ldrb r1, [r0]               

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

    add  r0, r0, #1             
    add  r6, r6, #1             
    b    imagem_loop

imagem_fim:
    pop  {r4, r5, r6, r7, r8, r9, r10, lr}
    bx   lr

@ ============================================================
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
    bl    send_no_wait

    @ instrução de valor
    lsl   r3, r1, #3
    ldr   r2, =0x0007FFF8
    and   r3, r3, r2
    mov   r2, #2
    orr   r2, r2, r3
    bl    send_instruction

    add  r0, r0, #2             
    add  r6, r6, #1
    b    pesos_loop

pesos_fim:
    pop  {r4, r5, r6, r7, r8, r9, r10, lr}
    bx   lr

@ ============================================================
start_inferencia:
    push {r7, r10, lr}
    mov  r10, r0                        

    mov  r2, #5                         
    str  r2, [r10, #PIO_DATA_IN]        
    mov  r2, #1                         
    str  r2, [r10, #PIO_SIGNALS]        
    mov  r2, #0                         
    str  r2, [r10, #PIO_SIGNALS]        

start_poll:
    ldr  r2, [r10, #PIO_DATA_OUT]       
    tst  r2, #(1 << 4)                  
    beq  start_poll                     

    ldr  r0, [r10, #PIO_DATA_OUT]       

    pop  {r7, r10, lr}
    bx   lr

@ ============================================================
send_instruction:
    push {r7, lr}
    str  r2, [r10, #PIO_DATA_IN]        
    mov  r2, #1                         
    str  r2, [r10, #PIO_SIGNALS]        
    mov  r2, #0                         
    str  r2, [r10, #PIO_SIGNALS]        
poll_done:
    ldr  r2, [r10, #PIO_DATA_OUT]       
    tst  r2, #(1 << 4)                  
    beq  poll_done                      
    pop  {r7, lr}
    bx   lr

@ ============================================================
send_no_wait:
    str  r2, [r10, #PIO_DATA_IN]        
    mov  r2, #1                         
    str  r2, [r10, #PIO_SIGNALS]        
    mov  r2, #0                         
    str  r2, [r10, #PIO_SIGNALS]        
    bx   lr