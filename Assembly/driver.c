#include <stdio.h>
#include <sys/mman.h>
#include "api_driver_c.h"

int main(){
    setvbuf(stdout, NULL, _IONBF, 0);

    int i;
    char nome_arquivo[64];

    printf("Iniciando mapeamento...\n");

    void* endereco = mapeia_memoria();

    if (!endereco || endereco == (void*)-1){
        printf("Erro no mapeamento.\n");
        return -1;
    }

    for(i = 1; i < 100; i++){

        printf("Resetando o coprocessador...\n");
        reset_coprocessador(endereco);

        printf("Enviando beta...\n");
        store_beta(endereco, "bins/beta_q.bin");

        printf("Enviando bias...\n");
        store_bias(endereco, "bins/b_q.bin");

        printf("Enviando pesos...\n");
        store_pesos(endereco, "bins/W_in_q.bin");

        // Gera o nome do arquivo: 1.bin, 2.bin, 3.bin...
        sprintf(nome_arquivo, "bins/%d.bin", i);

        printf("Enviando imagem: %s\n", nome_arquivo);
        store_imagem(endereco, nome_arquivo);

        printf("Iniciando a inferencia...\n");

        unsigned int resultado = comeca_infer(endereco);

        // Aplica a máscara 0x0F para isolar os 4 bits da predição
        printf("O resultado da inferencia e: %d\n", resultado & 0x0F);
    }

    return 0;
}