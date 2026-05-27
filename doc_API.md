# API — coprocessador_api.h

---

### `void* mapeia_memoria(void)`

Abre o `/dev/mem` e mapeia o endereco fisico da bridge no espaco virtual do processo. Precisa ser a primeira coisa chamada — o ponteiro que ela retorna e usado em todas as outras funcoes.

| Parametro | Descricao |
|---|---|
| (nenhum) | nao recebe argumentos |

**Retorno:** ponteiro para a base virtual dos PIOs. Guarda esse valor, ele vai ser necessario em todas as proximas chamadas.

> Precisa rodar com `sudo` por conta do acesso ao `/dev/mem`.

---

### `void reset_coprocessador(void* base_virtual)`

Manda um pulso de reset pro co-processador e limpa os registradores de controle. Recomendado chamar antes de comecar uma nova classificacao.

| Parametro | Descricao |
|---|---|
| `base_virtual` | ponteiro retornado por `mapeia_memoria` |

**Retorno:** void.

> Nao apaga as memorias internas (pesos, bias, beta, imagem). So os registradores de controle sao zerados.

---

### `void store_bias(void* base_virtual, const char* caminho_arquivo)`

Le o arquivo de bias e manda os 128 valores pro co-processador.

| Parametro | Descricao |
|---|---|
| `base_virtual` | ponteiro retornado por `mapeia_memoria` |
| `caminho_arquivo` | caminho pro arquivo `b_q.bin` — ex: `"bins/b_q.bin"` |

**Retorno:** void.

> Arquivo binario int16 big-endian. Tamanho esperado: 256 bytes.

---

### `void store_beta(void* base_virtual, const char* caminho_arquivo)`

Le o arquivo de coeficientes beta e manda os 1280 valores pro co-processador.

| Parametro | Descricao |
|---|---|
| `base_virtual` | ponteiro retornado por `mapeia_memoria` |
| `caminho_arquivo` | caminho pro arquivo `beta_q.bin` — ex: `"bins/beta_q.bin"` |

**Retorno:** void.

> Arquivo binario int16 big-endian. Tamanho esperado: 2560 bytes.

---

### `void store_imagem(void* base_virtual, const char* caminho_arquivo)`

Le o arquivo de imagem e manda os 784 pixels pro co-processador. Define qual imagem vai ser classificada na proxima inferencia.

| Parametro | Descricao |
|---|---|
| `base_virtual` | ponteiro retornado por `mapeia_memoria` |
| `caminho_arquivo` | caminho pro arquivo de imagem — ex: `"bins/0.bin"` |

**Retorno:** void.

> Arquivo binario uint8. Tamanho esperado: 784 bytes (imagem MNIST 28x28).

---

### `void store_pesos(void* base_virtual, const char* caminho_arquivo)`

Le o arquivo de pesos e manda os 100352 valores pro co-processador. E a funcao mais demorada da API porque carrega a matriz de pesos inteira da rede neural.

| Parametro | Descricao |
|---|---|
| `base_virtual` | ponteiro retornado por `mapeia_memoria` |
| `caminho_arquivo` | caminho pro arquivo `w_in_q.bin` — ex: `"bins/w_in_q.bin"` |

**Retorno:** void.

> Arquivo binario int16 big-endian. Tamanho esperado: 200704 bytes.

---

### `unsigned int comeca_infer(void* base_virtual)`

Manda o START pro co-processador e fica aguardando ate a inferencia terminar. Retorna o digito que a rede neural classificou. Chamar so depois de todos os `store_*` terem sido executados.

| Parametro | Descricao |
|---|---|
| `base_virtual` | ponteiro retornado por `mapeia_memoria` |

**Retorno:** digito predito pela rede neural, valor entre 0 e 9.

> Unica funcao da API que tem retorno.
