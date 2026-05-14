.data
caminho_bias: .asciz "/home/oem/Downloads/pbl/b_q.bin" @caminho do arquivo do bias
caminho_beta: @colocar caminho
buffer_bias: .space 256
buffer_beta: .space 2560

.text
.global _start

_start:
	bl store_bias @chama a função
	mov r7, #1 	@exit
	swi 0 		@util para o echo
	

store_bias:

	ldr r0, =caminho_bias @ caminho do arquivo
        mov r1, #0       @ somente leitura
        mov r2, #0       @ modo
        mov r7, #5       @ chamada ao sistema (open)
        swi 0            @ chama o linux, fecha...

        mov r8, r0       @ salva o file descriptor


        mov r0, r8       @ fd
        ldr r1, =buffer_bias  @ endereço do buffer
        mov r2, #256     @qtd de bytes
        mov r7, #3       @ chamada ao sistema read
        swi 0            @ chama o linux e fecha

        mov r9, r0      @ salva quantos bytes foram lidos

        mov r0, r8      @fd
        mov r7, #6      @ chamada ao sistema de fechamento
        swi 0           @ chama o linx

        ldr r0, =buffer_bias @endereço do buffer
        ldrh r1, [r0]  @le os 2 primeiros bytes
		rev16 r1,r1
		sxth r1,r1
	
	mov r0, r1 @retornando valor

        bx lr

store_beta:
	
