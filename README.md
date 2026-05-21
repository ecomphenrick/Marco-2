# Marco-2
# Projeto Coprocessador - Sistemas Digitais (PBL)
Este repositório contém o desenvolvimento de um coprocessador para a disciplina de Sistemas Digitais. Atualmente, o projeto encontra-se na finalização do **Marco 2**, focado na integração dos módulos fundamentais e estruturação do Datapath.

- [Introdução e Definição do Problema](#introdução-e-definição-do-problema)
- [Requisitos Principais](#requisitos-principais)
- [Fundamentação Teórica](#fundamentação-teórica)
   - [MMIO (Memory-Mapped I/O)](#mmio-memory-mapped-io)
   - [Drive /dev/mem e Syscalls](#Drive-/dev/mem-e-Syscalls)
   - [Polling](#polling)
- [Materiais e Métodos](#materiais-e-métodos)
   - [DE1-SoC](#de1-soc)
   - [Platform Designer](#platform-designer)
   - [Co-processador ELM](#co-processador-elm)
      - [Descrição](#descrição)
      - [Unidade de Controle](#unidade-de-controle)
      - [Unidade de Inferência](#unidade-de-inferência)
      - [Load/Store Unit](#loadstore-unit)
      - [Barramentos](#barramentos)
      - [ISA — Conjunto de Instruções](#isa--conjunto-de-instruções)
- [Metodologia](#metodologia)
- [Descrição da Solução](#descrição-da-solução)
   - [Arquitetura Geral](#arquitetura-geral)
   - [Escolha do /dev/mem](#escolha-do-devmem)
   - [Funções Implementadas](#funções-implementadas)
   - [Montagem da Instrução de 32 bits](#montagem-da-instrução-de-32-bits)
   - [Protocolo de Envio — Enable e Polling](#Protocolo de Envio — Enable e Polling)
   - [Leitura dos Arquivos .bin](#leitura-dos-arquivos-bin)
   - [Fluxo de Execução](#fluxo-de-execução)
- [Modo de Uso](#modo-de-uso)
- [Testes e Resultados](#testes-e-resultados)
- [Erros e Limitações](#erros-e-limitações)
- [Referências](#referências)
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
Implementar as rotinas de controle do co-processador incluindo início de inferência, monitoramento via flags Done/Busy/Error e leitura do resultado através de uma API definida com funções como open, write, read e ioctl.

### Leitura e Envio de Dados
Garantir o envio correto dos dados de entrada para o co-processador e a leitura dos resultados retornados após a inferência.

### Demonstração de Estabilidade
Realizar testes para verificar se a comunicação entre HPS e FPGA está funcionando corretamente e de forma estável durante várias execuções.

## Fundamentação Teórica

### MMIO (Memory-Mapped I/O)
MMIO (Memory-Mapped I/O) é uma forma de comunicação onde os registradores 
do hardware funcionam como posições de memória. Na prática, isso significa 
que o Linux consegue controlar o co-processador apenas lendo e escrevendo 
em determinados endereços de memória. Dessa forma, é possível enviar dados 
para a FPGA, iniciar a inferência e depois ler o resultado retornado pelo 
hardware.

No nosso projeto é de grande importância isso, por literalmente esta em toda a comunicação entre o Drive e o co-processador, no envio de Instruções, pulsos, polling e na leitura do digito esperado. 

### Drive /dev/mem e Syscalls
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

### Materiais e Métodos

## DE1-SoC

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

## Platform Designer

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

## Co-processador ELM

### Descrição

O co-processador foi cedido aos grupos e foi implementado pelo monitor da 
disciplina, Maike. Com ele foi entregue uma descrição detalhada e formatada 
contendo modo de uso, barramentos, unidade de controle, de inferencia, load/store e ISA. Com ele em 
mãos, iniciamos o processo de entender e analisar como funciona e 
principalmente como usaríamos no nosso projeto. De forma que em sessões 
tutoriais, foi bastante discutido que ele seria tratado como uma caixa preta, 
mas que nós teríamos que conectar, já que no Marco 2 isso é a base do 
problema conectar a FPGA com o HPS.

### Unidade de Controle

A Unidade de Controle conecta todo o co-processador e é responsável por 
receber as instruções e os sinais de controle externos, assim como retornar 
as flags e os resultados das operações. A entrada de dados é realizada 
através do barramento Data In e a saída através do Data Out.

Dentro da Unidade de Controle é feita a decodificação da instrução recebida, 
que a depender do opcode, direciona o co-processador para um estado de 
memória ou de inferência.

Um ponto importante é que durante a execução de uma instrução nenhuma outra 
pode ser executada ao mesmo tempo é necessário aguardar o fim da execução 
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

## Metodologia

O desenvolvimento do Marco 2 foi realizado seguindo a metodologia PBL, 
avançando de forma crescente ao longo das sessões tutoriais, com cada seção com metas, ideias e fatos que auxiliaram de forma coletiva o avanço do projeto. Inicialmente, 
o foco esteve na compreensão teórica da arquitetura da DE1-SoC, da 
comunicação entre HPS e FPGA e do funcionamento do acesso via MMIO. A 
partir disso, nosso projeto foi incrementando pouco a pouco evoluçoes de cada seção, passando pela 
configuração e entendimento do ambiente Linux embarcado que irianos trabalhaar, com a complemtntação e interligação do co processador cedido por um monitor da materia, testes iniciais em linguagem C 
e, posteriormente, implementação do driver final em Assembly ARM. Durante 
todo o processo, os roteiros de laboratório serviram como base para o 
desenvolvimento, principalmente o Lab 0, voltado para a introdução de como funciona a interligação dos modulos com 
a placa e acesso via SSH, e o Lab 2, que introduziu a integração HPS↔FPGA 
utilizada no projeto.

O primeiro contato com a placa aconteceu durante o Lab 0, que apresentou 
o acesso à DE1-SoC via SSH e a utilização de comandos Linux diretamente 
no terminal da placa. Essa etapa foi importante para que o grupo entendesse 
como executar programas, transferir arquivos e utilizar o ambiente Linux 
embarcado da FPGA.

Em seguida, o Lab 2 serviu como principal base técnica do projeto, 
introduzindo a comunicação HPS↔FPGA através de MMIO (Memory-Mapped I/O). 
Nesse laboratório foram estudados conceitos como Platform Designer, 
Lightweight Bridge, utilização de PIOs e acesso a registradores mapeados 
em memória usando /dev/mem e mmap em C. A partir desse ponto, o grupo gnahou uma nova froma de resolver o problema, e 
passou a compreender como o processador ARM poderia controlar periféricos 
implementados na FPGA.

Após o entendimento inicial da arquitetura, foi disponibilizado pelo monitor 
o co-processador ELM já implementado em Verilog. Entretanto, o módulo foi 
entregue sem integração pronta com o HPS, exigindo que o grupo realizasse 
toda a configuração do sistema no Platform Designer. Foram então adicionados 
os PIOs, que ja foram apresentados e na proxima seção vao ser aprofundados, eles foram necessários para entrada de dados, sinais de controle e leitura de 
resultados, conectando-os ao HPS através da Lightweight HPS-to-FPGA Bridge.

Para permitir o desenvolvimento fora do laboratório, também foi configurada 
uma máquina virtual Linux nos notebooks pessoais, para o melhor entendimento e disponibilidade de desenvolver sem depender tanto do LEDS. Dessa forma, o código Assembly 
podia ser escrito e compilado localmente, enquanto os testes finais eram 
executados remotamente na DE1-SoC via SSH, de forma que os testes eram ja realizados sem perca de tempo, o que fez acelerar mais a resolução do problema.

Os primeiros testes em baixo nível foram realizados utilizando pequenos 
programas em Assembly para acender LEDs da FPGA, esses testes teve como motivação um das metas de uma seção, que foi bem produtiva por conta desse priemiro contato com a programção de fato em assembly, alem da pesquisa e entendimento do Drive. Inicialmente ocorreram 
erros de segmentação, o que ajudou a identificar que o hardware ainda não 
estava corretamente gravado na placa. Após o pinamento dos sinais, compilação 
do projeto no Quartus e gravação do arquivo .sof, o acesso aos endereços 
físicos passou a funcionar corretamente.

Com o hardware validado, foi desenvolvido inicialmente um driver em linguagem 
C, antes mesmo de assembly puro, para testar toda a lógica de comunicação com o co-processador. Nessa etapa 
foram implementadas as rotinas de envio de pesos, bias, imagem e leitura do 
dígito predito, facilitando por ser em C, a depuração. O uso do C permitiu validar rapidamente o protocolo de 
comunicação antes da implementação definitiva em Assembly ARM.

Depois da validação funcional em C, o driver foi reescrito em Assembly ARM. 
O desenvolvimento foi feito de forma incremental, função por função, 
realizando testes constantes diretamente na placa. Durante essa etapa, o 
grupo trabalhou diretamente com instruções de manipulação de bits, 
deslocamentos, máscaras e escrita em registradores mapeados em memória, 
aprofundando o entendimento sobre comunicação de hardware em baixo nível.

Por fim, foram realizados testes completos de classificação utilizando o 
driver final em Assembly e o hardware gravado na FPGA. Os resultados eram 
exibidos no terminal via SSH, confirmando o funcionamento correto da 
integração entre HPS, FPGA e o co-processador ELM.

## Descrição da Solução

### Arquitetura Geral 

A arquitetura do nosso projeto que foi realizado, é composta por quatro blocos principais que 
trabalham de forma em sequencia e em conjunto parte por parte para realizar a classificação de um dígito que deve ser descrito.
O Driver Assembly ARM acessa o hardware através do /dev/mem, mapeando a 
Lightweight Bridge no espaço de memória do processo. Depois disso, as instruções chegam aos PIOs configurados no Platform Designer ferramenta do Quartus, que 
as mandam ao co-processador ELM na FPGA. O resultado,o dígito esperado
entre 0 e 9, e é retornado pelo barramento Data Out e mostrado no terminal. 

### Escolha do /dev/mem

O /dev/mem foi escolhido para fazer a conexão entre a FPGA e o HPS, 
pois ele permite o acesso direto aos registradores mapeados na memória. 
Com isso é possível mapear a Lightweight Bridge diretamente do espaço do 
usuário e controlar os registradores do hardware sem precisar desenvolver 
um driver de kernel.

Foi escolhido também, discutido e apresentado em uma das sessões tutoriais 
por todos os grupos, pela facilidade por conta de ser compatível com 
Assembly puro. A outra opção seria o módulo de kernel, que tem função 
parecida, mas foi descartada pois exigiria obrigatoriamente C no esqueleto 
de registro, o que contradiz o requisito do Marco 2 de desenvolver o driver 
em Assembly ARM.

Mais à frente, nos testes e depuração, essa escolha se mostrou ainda mais 
importante. O /dev/mem é mais rápido em testes e correções, além de não 
encerrar o sistema inteiro em caso de erro o que aconteceria se fosse 
utilizado um módulo de kernel.


### Funções Implementadas

O driver desenvolvido no projeto possui um conjunto de funções responsáveis 
pela comunicação entre o software e o co-processador implementado no FPGA. 
Essas funções foram separadas em grupos para deixar a organização do sistema 
mais simples e facilitar o controle das operações realizadas durante a execução.

Estão divididas em 3 grandes grupos. As funções de **inicialização** são 
responsáveis por preparar a comunicação com o hardware — o sistema realiza 
o acesso à Lightweight Bridge através do `/dev/mem`, faz o mapeamento dos 
registradores em memória e configura os endereços que serão utilizados pelo 
driver durante a execução.

- `mmap_lw` — abre `/dev/mem` e mapeia o endereço `0xFF200000` da Lightweight Bridge no espaço do processo
- `reset_coprocessador` — reseta o co-processador antes de qualquer envio de dado

As funções de **envio de dados** são responsáveis por transmitir os dados 
necessários para a inferência ao co-processador, como os pesos, bias, beta 
e os pixels da imagem. Para isso o driver monta as instruções no formato 
esperado pelo hardware e escreve os valores nos registradores correspondentes.

- `store_bias` — lê `b_q.bin` e envia 128 instruções com OP=011
- `store_beta` — lê `beta_q.bin` e envia 1280 instruções com OP=100
- `store_imagem` — lê `imagem.bin` e envia 784 instruções com OP=000
- `store_pesos` — lê `W_in_q.bin` e envia 100352 pares de instruções OP=001 + OP=010

As funções de **comunicação com o hardware** são responsáveis pelo controle 
direto dos PIOs, realizando o envio de instruções com e sem polling, além 
do disparo da inferência e leitura do resultado.

- `send_instruction` — envia instrução no formato de 32 bits e aguarda a flag Done subir
- `send_no_wait` — envia instrução sem aguardar Done, usada exclusivamente para Store Weights Addr
- `start_inferencia` — envia a instrução Start, aguarda Done e retorna o dígito predito

### Montagem da Instrução de 32 bits

### Protocolo de Envio — Enable e Polling

A comunicação entre o processador ARM e o co-processador no projeto é feita 
através de uma implementação simples de sincronização baseada nos sinais 
Enable e Done. O objetivo é garantir que cada instrução enviada pelo driver 
seja executada completamente antes da próxima começar.

O sinal Enable, controlado pelo bit 0 do registrador PIO_SIGNALS, funciona 
como um pulso de ativação. Primeiro o driver escreve a instrução no 
PIO_DATA_IN, depois coloca o Enable em nível lógico 1 para avisar ao 
hardware que existe uma nova instrução disponível. Em seguida o sinal retorna 
imediatamente para 0.

Esse retorno para 0 é obrigatório porque o co-processador só ativa o sinal 
Done após detectar o fim do pulso de Enable. Caso o Enable permaneça em 1, 
o processamento até pode ocorrer internamente, porém o Done nunca será 
acionado, fazendo o software ficar preso indefinidamente no loop de polling.

Após o pulso de Enable, o driver entra em um laço de polling lendo 
continuamente o registrador PIO_DATA_OUT. Nesse processo o bit 4 é sempre 
verificado, pois ele representa o sinal Done. Enquanto esse bit permanecer 
em 0, significa que o co-processador ainda está executando a instrução. 
Quando Done passa para 1, o driver entende que a operação terminou e pode 
continuar a execução normalmente.

O polling foi utilizado para garantir a sincronização entre software e 
hardware sem necessidade de interrupções.

Existe ainda um caso especial relacionado à instrução Store Weights Addr 
(OP=001). Segundo a documentação do co-processador, essa operação leva 
apenas alguns ciclos de clock e não ativa o sinal Done. Por esse motivo 
ela utiliza a função send_no_wait, que realiza apenas o pulso de Enable 
sem entrar no loop de polling. Caso fosse utilizado polling nessa instrução, 
o programa permaneceria travado esperando um Done que nunca seria ativado.

### Leitura dos Arquivos .bin

Antes de enviar os dados para o co-processador, no nosso projeto o programa precisa ler os 
arquivos .bin usando syscalls do Linux em Assembly ARM. O processo segue 
sempre três etapas: abrir o arquivo, ler os dados para um buffer na RAM e 
depois fechar o arquivo.

O open retorna um identificador chamado file descriptor, que é usado nas 
próximas operações. Em seguida, o read copia os bytes do arquivo para 
buffers declarados na memória do programa. Depois da leitura, o arquivo é 
fechado com close, liberando o recurso no sistema.

Cada arquivo possui um buffer próprio na RAM. Os arquivos de bias, beta e 
imagem são pequenos e podem ser carregados completamente. Já o arquivo de 
pesos (W_in_q.bin) é muito maior, então o programa lê apenas 2 bytes por 
vez dentro do loop de envio, evitando ocupar muita memória.



![Tabela de arquivos e buffers](imagens/tabela_arquivos.png)



Após a leitura, alguns valores ainda precisam ser convertidos antes de serem 
usados. Bias, beta e pesos são números de 16 bits com sinal, então o código 
inverte a ordem dos bytes (rev16) e faz extensão de sinal para 32 bits 
(sxth), já que os arquivos estão em big-endian e o ARM usa little-endian. 
A imagem não precisa desse tratamento porque cada pixel ocupa apenas 1 byte 
sem sinal.

### Fluxo de Execução

A primeira etapa do programa é fazer o mapeamento dos registradores da FPGA 
na memória do processador. Isso é feito usando /dev/mem e a função mmap(), 
permitindo que o software consiga acessar diretamente os PIOs do hardware. 
Depois desse mapeamento, o processador passa a conseguir ler e escrever nos 
registradores do co-processador como se fossem posições normais de memória.

A segunda etapa é o reset do co-processador para que não exista estado 
acumulativo de execuções anteriores que possa atrapalhar, tanto nos 
registradores como na memória interna. Isso é realizado a partir do sinal 
de reset, que é ativado e depois desativado, deixando o hardware pronto para 
receber novos dados.

O terceiro passo é o carregamento dos valores de bias para dentro do 
co-processador, com a leitura do arquivo b_q.bin, percorrendo os valores 
e enviando cada um para a memória interna da FPGA pelos PIOs.

O quarto passo é parecido com o terceiro, mas agora com o arquivo beta. O 
software abre o arquivo beta_q.bin, lê os dados e envia cada valor para 
a memória correspondente no hardware.

O quinto passo também é de envio, mas agora da imagem. Na store_imagem
acontece a leitura do arquivo imagem.bin e o envio dos pixels para a 
memória de imagem da FPGA. Como os pixels têm apenas 1 byte, não há 
necessidade de tratamento de sinal nessa etapa.

O sexto passo é a etapa mais pesada, por conta do carregamento de todos os 
pesos da rede neural. O software lê o arquivo W_in_q.bin aos poucos e 
envia os dados para a memória interna do co-processador. Ao contrário do 
quinto passo, aqui há necessidade de tratamento para cada peso com correções 
de sinal antes do envio.

O sétimo passo é quando, com todos os dados carregados, o programa dá o 
comando para iniciar a inferência. O co-processador executa as operações da 
rede neural internamente, realizando os cálculos das camadas e determinando 
qual saída possui o maior valor. Enquanto isso o processador fica aguardando 
o sinal de conclusão (Done).

O oitavo passo é quando a inferência termina. O resultado recebido possui 
32 bits, mas apenas os 4 bits menos significativos representam o dígito 
previsto. O programa então aplica uma operação lógica (AND 0xF) para 
remover os outros bits e manter somente o valor final da classificação.

O nono passo é quando, após receber o resultado, o programa converte o 
número para caractere ASCII e imprime o valor no terminal. É a parte em que 
o dígito reconhecido pela rede neural aparece para a visualização do usuário.

O décimo e último passo é quando o programa encerra sua execução e devolve 
o controle ao sistema operacional. Os recursos utilizados, como o acesso ao 
/dev/mem, são liberados pelo Linux.

---

## Modo de Uso

---

## Testes e Resultados

---

## Erros e Limitações

---

---

## Referências
