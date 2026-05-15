#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdint.h>
#include <stdlib.h>
#include <sys/mman.h>

#define LW_BASE      0xFF200000
#define PIO_DATA_OUT 0x00
#define PIO_SIGNALS  0x10
#define PIO_DATA_IN  0x20

volatile uint32_t *base;

// envia instrução e aguarda DONE (bit 4 do data_out)
void send_instruction(uint32_t instrucao) {
    base[PIO_DATA_IN  / 4] = instrucao;
    base[PIO_SIGNALS  / 4] = 1;
    while (!(base[PIO_DATA_OUT / 4] & (1 << 4)));
    base[PIO_SIGNALS  / 4] = 0;
}

// envia instrução SEM aguardar DONE
// Store Weights Addr não ativa a flag DONE
void send_no_wait(uint32_t instrucao) {
    base[PIO_DATA_IN  / 4] = instrucao;
    base[PIO_SIGNALS  / 4] = 1;
    base[PIO_SIGNALS  / 4] = 0;
}

// ============================================================
// Store Bias — 128 valores de 16 bits com sinal
// Formato: [ não usado(6) | dado(16) bits 25-10 | endereço(7) bits 9-3 | OP(3)=011 ]
// ============================================================
void store_bias() {
    int fd = open("/home/aluno/b_q.bin", O_RDONLY);
    if (fd < 0) { printf("ERRO: nao abriu bias\n"); return; }
    uint8_t buffer[256];
    read(fd, buffer, 256);
    close(fd);

    int i;
    for (i = 0; i < 128; i++) {
        uint16_t raw  = ((uint16_t)buffer[i*2] << 8) | buffer[i*2 + 1];
        int16_t valor = (int16_t)raw;

        uint32_t instrucao  = ((uint32_t)(uint16_t)valor << 10) & 0x03FFFC00;
                 instrucao |= ((uint32_t)i << 3) & 0x000003F8;
                 instrucao |= 3;  // OP = 011

        send_instruction(instrucao);
    }
    printf("bias enviado\n");
}

// ============================================================
// Store Beta — 1280 valores de 16 bits com sinal
// Formato: [ não usado(2) | dado(16) bits 29-14 | endereço(11) bits 13-3 | OP(3)=100 ]
// ============================================================
void store_beta() {
    int fd = open("/home/aluno/beta_q.bin", O_RDONLY);
    if (fd < 0) { printf("ERRO: nao abriu beta\n"); return; }
    uint8_t buffer[2560];
    read(fd, buffer, 2560);
    close(fd);

    int i;
    for (i = 0; i < 1280; i++) {
        uint16_t raw  = ((uint16_t)buffer[i*2] << 8) | buffer[i*2 + 1];
        int16_t valor = (int16_t)raw;

        uint32_t instrucao  = ((uint32_t)(uint16_t)valor << 14) & 0x3FFFC000;
                 instrucao |= ((uint32_t)i << 3) & 0x00003FF8;
                 instrucao |= 4;  // OP = 100

        send_instruction(instrucao);
    }
    printf("beta enviado\n");
}

// ============================================================
// Store Image — 784 pixels de 8 bits sem sinal
// Formato: [ padding(11) | dado(8) bits 20-13 | endereço(10) bits 12-3 | OP(3)=000 ]
// ============================================================
void store_image() {
    int fd = open("/home/aluno/imagem.bin", O_RDONLY);
    if (fd < 0) { printf("ERRO: nao abriu imagem\n"); return; }
    uint8_t buffer[784];
    read(fd, buffer, 784);
    close(fd);

    int i;
    for (i = 0; i < 784; i++) {
        uint8_t valor = buffer[i];

        uint32_t instrucao  = ((uint32_t)valor << 13) & 0x001FE000;
                 instrucao |= ((uint32_t)i << 3) & 0x00001FF8;
                 instrucao |= 0;  // OP = 000

        send_instruction(instrucao);
    }
    printf("imagem enviada\n");
}

// ============================================================
// Store Weights — 100352 valores de 16 bits com sinal
// Addr:  [ não usado(12) | endereço(17) bits 19-3 | OP(3)=001 ] — SEM DONE
// Value: [ não usado(13) | dado(16) bits 18-3      | OP(3)=010 ] — COM DONE
// ============================================================
void store_weights() {
    int fd = open("/home/aluno/W_in_q.bin", O_RDONLY);
    if (fd < 0) { printf("ERRO: nao abriu weights\n"); return; }

    uint8_t *buffer = malloc(200704);  // 100352 valores x 2 bytes
    if (!buffer) { printf("ERRO: malloc falhou\n"); close(fd); return; }
    read(fd, buffer, 200704);
    close(fd);

    int i;
    for (i = 0; i < 100352; i++) {
        uint16_t raw  = ((uint16_t)buffer[i*2] << 8) | buffer[i*2 + 1];
        int16_t valor = (int16_t)raw;

        // 1) envia endereço (nao ativa DONE)
        uint32_t addr_instr = ((uint32_t)i << 3) & 0x000FFFF8;
                 addr_instr |= 1;  // OP = 001
        send_no_wait(addr_instr);

        // 2) envia valor (ativa DONE)
        uint32_t val_instr  = ((uint32_t)(uint16_t)valor << 3) & 0x0007FFF8;
                 val_instr  |= 2;  // OP = 010
        send_instruction(val_instr);
    }

    free(buffer);
    printf("weights enviados\n");
}

// ============================================================
// Start — inicia inferência
// Formato: [ padding(29) | OP(3)=101 ]
// ============================================================
void start_inference() {
    uint32_t instrucao = 5;  // OP = 101
    send_instruction(instrucao);
}

int main() {
    // abre /dev/mem e mapeia ponte LW (0xFF200000)
    int mem_fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (mem_fd < 0) { printf("ERRO: nao abriu /dev/mem\n"); return 1; }

    base = (volatile uint32_t *)mmap(NULL, 0x1000,
                                     PROT_READ | PROT_WRITE,
                                     MAP_SHARED,
                                     mem_fd, LW_BASE);

    store_bias();
    store_beta();
    store_image();
    store_weights();
    start_inference();

    // lê resultado
    uint32_t resultado = base[PIO_DATA_OUT / 4];

    printf("data_out: ");
    int i;
    for (i = 31; i >= 0; i--) {
        printf("%d", (resultado >> i) & 1);
        if (i % 4 == 0 && i != 0) printf(" ");
    }
    printf("\n");
    printf("digito predito: %d\n", resultado & 0xF);  // bits 3-0

    munmap((void *)base, 0x1000);
    close(mem_fd);
    return 0;
}