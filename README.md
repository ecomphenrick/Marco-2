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
- [Próximos Passos — Marco 3](-próximos-passos--marco-3)
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

## 4. Co-processador ELM

### 4.1 Descrição

### 4.2 Barramentos

### 4.3 ISA — Conjunto de Instruções

---

## 5. Descrição da Solução



---

## 6. Modo de Uso

---

## 7. Testes e Resultados

---

## 8. Erros e Limitações

---

## 9. Próximos Passos — Marco 3

---

## 10. Referências
