.data
caminho: .asciz "/home/oem/Downloads/pbl/b_q.bin" @caminho do arquivo
buffer: .space 256

.text
.global _start

_start:
	ldr r0, =caminho @ caminho do arquivo
	mov r1, #0	 @ somente leitura
	mov r2, #0	 @ modo
	mov r7, #5	 @ chamada ao sistema (open)
	swi 0		 @ chama o linux, fecha...
	
	mov r8, r0	 @ salva o file descriptor


	mov r0, r8       @ fd
	ldr r1, =buffer  @ endereço do buffer
	mov r2, #256	 @qtd de bytes
	mov r7, #3	 @ chamada ao sistema read
	swi 0	 	 @ chama o linux e fecha
	
	mov r9, r0	@ salva quantos bytes foram lidos
	
	mov r0, r8 	@fd
	mov r7, #6	@ chamada ao sistema de fechamento
	swi 0		@ chama o linx

	ldr r0, =buffer	@endereço do buffer
	ldrh r1, [r0]  @le os 2 primeiros bytes

	mov r7, #1	@exit
	mov r0, r1	@sai com o numero de bytes lidos
	swi 0



