# Marco-2
# Projeto Coprocessador - Sistemas Digitais (PBL)
Este repositório contém o desenvolvimento de um coprocessador para a disciplina de Sistemas Digitais. Atualmente, o projeto encontra-se na finalização do **Marco 2**, focado na integração dos módulos fundamentais e estruturação do Datapath.

## Sumário

- [Introdução e Definição do Problema](-introdução-e-definição-do-problema)
- [Requisitos Principais](-requisitos-principais)
- [Fundamentação Teórica](-fundamentação-teórica)
   - [DE1-SoC e a Lightweight HPS-to-FPGA Bridge](-de1-soc-e-a-lightweight-hps-to-fpga-bridge)
   - [MMIO (Memory-Mapped I/O)](-mmio-memory-mapped-io)
   - [Drive /dev/mem e Syscalls](-devmem-e-syscalls)
   - [Polling](-polling)
- [Co-processador ELM](-co-processador-elm)
   - [Descrição](-descrição)
   - [Barramentos](-barramentos)
   - [ISA — Conjunto de Instruções](-isa--conjunto-de-instruções)
- [Descrição da Solução](-descrição-da-solução)

- [Modo de Uso](-modo-de-uso)
- [Testes e Resultados](-testes-e-resultados)
- [Erros e Limitações](-erros-e-limitações)
- [Referências](-referências)

---

## Introdução e Definição do Problema
Este projeto faz parte do Marco2, da disciplina de SD(Sistemas Digitais) - TEC499, que tem como objetivo realizar a integração entre o co-processador ELM implementado na FPGA(do marco1, projetado por um monitor da referente materia) e o sistema Linux executando no HPS da placa DE1-SoC. O co-processador, desenvolvido em Verilog no Marco 1, é responsável por executar a inferência do modelo ELM diretamente em hardware.

No Marco 2, o foco principal é permitir que o processador ARM consiga se comunicar corretamente com o co-processador através de MMIO (Memory-Mapped I/O), utilizando as bridges entre HPS e FPGA disponíveis na placa. Para isso, foi utilizada a ferramenta Platform Designer no Quartus Prime para integrar o hardware ao sistema do HPS.

Além da parte de hardware, também foi desenvolvido um driver Linux com partes em Assembly ARM, responsável por fazer o controle e acesso aos registradores do co-processador.

O principal desafio desta etapa é garantir que a comunicação entre o Linux e o co-processador funcione de forma correta e estável, permitindo o envio e leitura de dados sem erros de sincronização. Para isso, foi necessário mapear os registradores do módulo, configurar a comunicação entre HPS e FPGA e implementar as funções de acesso ao hardware.

Ao final deste marco, o sistema deve estar apto para que, no Marco 3, uma aplicação em linguagem C consiga utilizar o co-processador através do driver desenvolvido.
## Requisitos Principais

### Integração HPS↔FPGA
Fazer a integração entre o HPS e o co-processador ELM na FPGA utilizando o Platform Designer, permitindo que o processador ARM consiga se comunicar com o hardware implementado em Verilog.

### Driver Linux em Assembly ARM
Desenvolver um driver Linux com funções em Assembly ARM para realizar o controle do co-processador e o acesso aos registradores do hardware.

### Comunicação via MMIO
Implementar a comunicação utilizando MMIO (Memory-Mapped I/O), permitindo que o Linux consiga ler e escrever dados nos registradores do co-processador através de endereços de memória.

### Controle do Co-processador
Implementar as rotinas de controle do co-processador — incluindo início de inferência, monitoramento via flags Done/Busy/Error e leitura do resultado — através de uma API definida com funções como open, write, read e ioctl.

### Leitura e Envio de Dados
Garantir o envio correto dos dados de entrada para o co-processador e a leitura dos resultados retornados após a inferência.

### Demonstração de Estabilidade
Realizar testes para verificar se a comunicação entre HPS e FPGA está funcionando corretamente e de forma estável durante várias execuções.

## Fundamentação Teórica

### DE1-SoC e a Lightweight HPS-to-FPGA Bridge
A DE1-SoC é a placa utilizada no nosso projeto. Ela junta duas partes principais: 
o HPS, que é o processador ARM responsável por rodar o Linux, e a FPGA, 
onde o co-processador ELM foi implementado em Verilog.

Como essas duas partes precisam se comunicar e trocar informações, a placa possui bridges 
que fazem essa comunicação. No noaso projeto foi utilizada a Lightweight Bridge,decidido e apresentado em uma das seções tutoriais,  
que permite que o processador ARM consiga acessar os registradores do 
hardware na FPGA de forma mais simples e direta.

A placa conta com as seguintes especificações relevantes para o projeto:

- Processador ARM Cortex-A9 dual-core (HPS)
- FPGA Cyclone V
- 1GB de RAM DDR3
- Sistema operacional Linux embarcado rodando no HPS
- Lightweight Bridge com endereço base 0xFF200000

### Platform Designer

O Platform Designer é uma ferramenta dentro do Quartus, apresentada durante 
uma das sessões de desenvolvimento no laboratório. Com ela é possível montar 
a ligação entre o HPS e a FPGA de forma visual.

No projeto foram adicionados 3 PIOs e conectados ao HPS através da 
Lightweight Bridge:

PIO Data In — 32 bits, saída — envia instruções ao co-processador

PIO Signals — 3 bits, saída — envia os sinais Enable, Clear e Reset

PIO Data Out— 32 bits, entrada — recebe as flags e o resultado

Após a conexão de tudo, o Platform Designer atribuiu automaticamente 
endereços de memória para cada PIO:

Data In = 0xFF200000
Signals = 0xFF200010
Data Out = 0xFF200020

Esses endereços são os que o driver utiliza para se comunicar com o 
co-processador via MMIO.

### MMIO (Memory-Mapped I/O)
MMIO (Memory-Mapped I/O) é uma forma de comunicação onde os registradores 
do hardware funcionam como posições de memória. Na prática, isso significa 
que o Linux consegue controlar o co-processador apenas lendo e escrevendo 
em determinados endereços de memória. Dessa forma, é possível enviar dados 
para a FPGA, iniciar a inferência e depois ler o resultado retornado pelo 
hardware.

No nosso projeto é de grande importância isso, por literalmente esta em toda a comunicação entre o Drive e o co-processador, no envio de Instruções, pulsos, polling e na leitura do digito esperado. 

### Drive (/dev/mem e Syscalls)
O /dev/mem é um recurso do Linux que permite acessar diretamente regiões 
da memória física do sistema. No nosso projeto, ele foi utilizado para acessar 
os registradores do co-processador conectados pela Lightweight Bridge.

Para fazer esse acesso, o programa utiliza syscalls, que são chamadas do 
sistema operacional. Funções permitem abrir o /dev/mem, mapear os 
endereços da FPGA na memória do programa e depois liberar os recursos 
utilizados.

A syscall mais importante no nosso processo é o mmap(), porque é ela que 
faz o mapeamento do endereço físico da FPGA, como o 0xFF200000, para o 
espaço de memória do processo. Na prática, isso permite que o código em 
Assembly consiga acessar os PIOs diretamente utilizando ponteiros, como 
se estivesse acessando variáveis normais da memória.

### Polling
Polling é uma forma simples de acompanhar o funcionamento de um hardware durante a execução de alguma tarefa. Em vez do hardware avisar sozinho quando terminou o processamento, o software fica verificando continuamente o registrador de status até receber a resposta esperada.

No projeto que fizemos, isso acontece durante a inferência do co-processador ELM. Depois que o Linux envia os dados e inicia o processamento, o driver fica lendo as flags de status, como Busy e Done, para verificar se a execução ainda está acontecendo ou se já foi finalizada.

Antes de verificar a flag Done, o driver também checa a flag Error. Caso ela esteja ativa, significa que ocorreu algum problema durante o processamento, evitando que o sistema fique preso em um loop de espera infinito.

## Co-processador ELM

O co-processador foi cedido aos grupos e foi implementado pelo monitor da 
disciplina, Maike. Com ele foi entregue uma descrição detalhada e formatada 
contendo modo de uso, barramentos, unidade de controle, de inferencia, load/store e ISA. Com ele em 
mãos, iniciamos o processo de entender e analisar como funciona e 
principalmente como usaríamos no nosso projeto. De forma que em sessões 
tutoriais, foi bastante discutido que ele seria tratado como uma caixa preta, 
mas que nós teríamos que conectar, já que no Marco 2 isso é a base do 
problema — conectar a FPGA com o HPS.

### Unidade de Controle

A Unidade de Controle conecta todo o co-processador e é responsável por 
receber as instruções e os sinais de controle externos, assim como retornar 
as flags e os resultados das operações. A entrada de dados é realizada 
através do barramento Data In e a saída através do Data Out.

Dentro da Unidade de Controle é feita a decodificação da instrução recebida, 
que a depender do opcode, direciona o co-processador para um estado de 
memória ou de inferência.

Um ponto importante é que durante a execução de uma instrução nenhuma outra 
pode ser executada ao mesmo tempo — é necessário aguardar o fim da execução 
atual para que uma nova instrução possa ser lida. Caso uma instrução seja 
enviada enquanto outra ainda está sendo executada, a flag de erro poderá 
ser ativada.

### Unidade de Inferência

A Unidade de Inferência é o módulo responsável por abrigar os MACs e os 
bancos de registradores utilizados durante o processo de cálculo. É dividida 
em seis submodulos:

**Primeira Camada** — responsável por realizar os cálculos contidos na 
camada oculta do ELM. Utiliza a tangente hiperbólica como função de ativação.

**Banco de 128 Registradores** — armazena um conjunto de registradores 
organizados em colunas, realizando operações de leitura e escrita.

**Segunda Camada** — responsável por realizar os cálculos contidos na 
camada de saída. Não possui função de ativação.

**Banco de 10 Registradores** — armazena o resultado dos neurônios da 
camada de saída.

**Argmax** — módulo comparador que busca a posição do registrador que 
contém o maior valor da camada de saída.

**Unidade de Controle de Inferência** — responsável por organizar a execução 
de modo que cada etapa da ELM ocorra de maneira correta.


### Load/Store Unit

Módulo responsável por gerenciar as operações de leitura e escrita de 
memória. É um módulo de memória genérico que implementa a criação dinâmica 
de memórias RAM. Nesse projeto foram necessárias 4 instâncias:

**mem_img** — responsável por armazenar 784 valores de 8 bits 
correspondentes aos pixels da imagem.

**mem_win** — responsável por armazenar 100352 valores de 16 bits 
correspondentes aos pesos da camada oculta.

**mem_bias** — responsável por armazenar 128 valores de 16 bits 
correspondentes aos bias da camada oculta.

**mem_beta** — responsável por armazenar 1280 valores de 16 bits 
correspondentes aos valores de beta da camada de saída.

### Barramentos

O co-processador possui 3 barramentos principais, dois de entrada e um de 
saída.

**Data In** — barramento de entrada de 32 bits utilizado exclusivamente para 
o envio das instruções ao co-processador. Os 32 bits são preenchidos de 
acordo com a instrução que será executada.

**Signals** — barramento de entrada de 3 bits utilizado para enviar os sinais 
de controle externos ao co-processador. Cada bit possui uma utilidade:

| Bit | Sinal | Descrição |
|-----|-------|-----------|
| 0 | Enable | Sinaliza que a instrução presente no barramento deve ser executada |
| 1 | Clear | Limpa resquícios de uma instrução anterior com erro |
| 2 | Reset | Reseta os registradores do co-processador | ( imagem)

**Data Out** — único barramento de saída, com largura de 32 bits, porém nem 
todos os bits são utilizados:

| Bits | Sinal | Descrição |
|------|-------|-----------|
| 0-3 | Resultado | Dígito predito pela rede neural. Confiável apenas após a conclusão da inferência |
| 4 | Done | Ativada quando uma operação é concluída. Permanece ativa até que uma nova instrução comece |
| 5 | Busy | Indica que uma operação ainda está sendo executada |
| 6 | Error | Indica que a instrução anterior não foi executada corretamente. Mesmo que tenha sido concluída, o resultado não é confiável | (imagem)

### ISA — Conjunto de Instruções

O co-processador possui 8 instruções, sendo 5 de memória e 1 de controle, 
além de 2 não utilizadas no projeto. Todas possuem opcode de 3 bits nos 
bits 31-29 do barramento Data In.

**000 — Store Image** — armazena um pixel da imagem na memória.

**001 — Store Weights Addr** — define o endereço onde o peso será armazenado.

**010 — Store Weights Value** — armazena o peso no endereço definido.

**011 — Store Bias** — armazena um bias na memória.

**100 — Store Beta** — armazena um valor de beta na memória.

**101 — Start** — inicia o processo de inferência.

**110 — Status** — não utilizada. As flags são atualizadas diretamente no 
barramento sem necessidade de solicitação.

**111 — NOP** — não utilizada. Usada para inserção de bolhas em arquiteturas 
com pipeline.


## 5. Descrição da Solução

### Arquitetura Geral 

A arquitetura do nosso projeto que foi realizado, é composta por quatro blocos principais que 
trabalham de forma em sequencia e em conjunto parte por parte para realizar a classificação de um dígito que deve ser descrito.
O Driver Assembly ARM acessa o hardware através do /dev/mem, mapeando a 
Lightweight Bridge no espaço de memória do processo. Depois disso, as instruções chegam aos PIOs configurados no Platform Designer ferramenta do Quartus, que 
as mandam ao co-processador ELM na FPGA. O resultado,o dígito esperado
entre 0 e 9, e é retornado pelo barramento Data Out e mostrado no terminal. 

---

## Modo de Uso

---

## Testes e Resultados

---

## Erros e Limitações

---

---

## Referências
