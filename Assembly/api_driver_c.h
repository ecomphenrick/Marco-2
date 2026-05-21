#ifndef COPROCESSADOR_API_H
#define COPROCESSADOR_API_H

// Controle de mapeamento e hardware
void* mmap_lw(void);
void reset_coprocessador(void* base_virtual);

// Transferência de dados (Recebem a base MMIO e o caminho do arquivo)
void store_bias(void* base_virtual, const char* caminho_arquivo);
void store_beta(void* base_virtual, const char* caminho_arquivo);
void store_imagem(void* base_virtual, const char* caminho_arquivo);
void store_pesos(void* base_virtual, const char* caminho_arquivo);

// Execução
unsigned int start_inferencia(void* base_virtual);

#endif
