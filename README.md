# SPARQ

Biblioteca MATLAB para identificar trechos com ruído em gravações multicanal
de LFP. O uso comum é feito por uma interface gráfica interativa: o sinal
marcado ocupa a área principal e, após o processamento, um resumo compacto
mostra as porcentagens preservada e removida. A detecção é atualizada quando um
parâmetro é alterado, sem reiniciar o programa.

## Requisitos

Use MATLAB R2021a ou mais recente. A biblioteca aceita gravações somente em
arquivos `.mat`.

Para começar, baixe esta pasta completa e mantenha [`main.m`](main.m),
[`SPARQ_GUI.m`](SPARQ_GUI.m) e a pasta `+SPARQ` juntos.

## Como usar

1. Coloque as gravações `.mat` em uma pasta. Elas podem estar organizadas em
   subpastas.

2. Execute [`main.m`](main.m). Também é possível digitar `SPARQ_GUI` na janela
   de comandos do MATLAB.

3. Na interface, escolha a pasta e clique em **Carregar sessões**.

4. Escolha uma sessão na lista. Ela já entra no modo de seleção: no gráfico à
   esquerda, clique primeiro no início e depois no fim de um trecho sem ruído.
   O título e a mensagem inferior indicam qual clique está sendo aguardado.

5. Altere os parâmetros. A interface chama novamente o mesmo núcleo científico
   e atualiza o sinal marcado e o resumo percentual de preservação.

6. Visite cada sessão e marque sua própria referência limpa. Você pode salvar
   apenas a sessão atual ou clicar em **Salvar resultados de todas as sessões**.
   Cada sessão recebe uma pasta exclusiva em `SPARQ_results`, com o arquivo MAT
   e a subpasta `imagens`, sem alterar os arquivos brutos.

Para abrir a interface já apontando para uma pasta, use:

```matlab
app = SPARQ_GUI("DataFolder", "C:\dados\meu_experimento");
```

## Formato dos dados

Para um arquivo `.mat` simples, o padrão esperado é:

1. `LFP`, uma matriz numérica com canais nas linhas e amostras nas colunas.

2. `fs`, um número com a frequência de amostragem em hertz.

Se o arquivo usa outros nomes, preencha **Variável do sinal** e **Variável da
frequência** na interface antes de carregar as sessões.

Se a frequência não está salva no arquivo, deixe **Variável da frequência**
vazia e informe **Frequência fixa (Hz)**.

Se as amostras estão nas linhas e os canais nas colunas, selecione
`samples-by-channels` em **Orientação**. Caso contrário, mantenha
`channels-by-samples`.

Os campos `timeVariable` e `channelLabelsVariable` são opcionais. Quando eles
ficam vazios, a biblioteca cria o tempo e nomes simples para os canais.

**Escala do sinal** multiplica os valores ao carregar. **Unidade do sinal**
apenas registra a unidade dos valores resultantes. Por exemplo, para converter
dados em mV para µV, use escala `1000` e unidade `uV`.

Mantenha **Formato** como `auto`. Assim, a biblioteca também reconhece
automaticamente outros layouts MAT conhecidos,
inclusive quando um arquivo contém várias gravações.

## Opções que podem exigir ajuste

**Canais excluídos** informa os canais que não devem participar da detecção.
Por exemplo, `2 8` exclui os canais 2 e 8.

**Canais simultâneos** define quantos canais precisam
ultrapassar o limite ao mesmo tempo para que uma amostra seja considerada
ruído. Esse valor não pode ser maior que a quantidade de canais utilizados.

Na primeira execução, mantenha os valores iniciais. Os parâmetros medidos em
amostras podem precisar de ajuste quando a frequência de amostragem for
diferente da usada na calibração original.

## Resultados

Cada gravação processada gera um arquivo com nome terminado em `_clean.mat`.
Dentro dele, a variável `SPARQ_result` contém diretamente as saídas necessárias
para análises posteriores.

Para abrir o resultado:

```matlab
arquivo = load("caminho_para_o_resultado_clean.mat");
resultado = arquivo.SPARQ_result;
mascara = resultado.noiseMask;
```

`noiseMask` sempre é salva. Ela possui um valor para cada amostra original:

1. `0` significa que a amostra não foi identificada como ruído.

2. `1` significa que a amostra foi identificada como ruído.

Duas representações adicionais podem ser ativadas pelas caixas **Salvar sinal
concatenado** e **Salvar sinal com NaN**.

`concat` contém apenas as amostras não marcadas como ruído. Seu eixo deixa de
representar tempo contínuo. `nan` mantém o tamanho e o eixo temporal do sinal,
substituindo por `NaN` as amostras marcadas.

Quando uma dessas representações está habilitada, ela aparece diretamente em
`SPARQ_result.concat` e/ou `SPARQ_result.nan`. Os campos `channels` e
`signalUnits` identificam as linhas e a unidade dessas matrizes. O resultado em
memória retornado pela biblioteca continua completo em `result.cleanSignals`.

Na GUI, cada sessão é salva em `SPARQ_results/<sessão>` e sua subpasta
`imagens` recebe sempre os arquivos com sufixos `_raw.png`, `_thresholds.png`,
`_noise_windows.png` e `_saved_percentage.png`. As opções adicionais acrescentam
`_concat.png` e/ou `_nan.png`. O eixo do gráfico concatenado representa a ordem
das amostras preservadas, não um tempo contínuo; linhas pontilhadas indicam as
emendas. O fluxo de `main_batch.m` mantém a organização configurada para lotes.

## Executar novamente

Dentro da mesma execução, a referência de cada sessão permanece disponível ao
trocar de sessão. Para substituir uma referência já marcada, clique em
**Selecionar referência no sinal**.

Por segurança, um resultado existente não é substituído. Marque **Permitir
substituir resultado SPARQ** somente quando essa for a intenção. A proteção do
salvamento recusa qualquer tentativa de substituir o arquivo bruto ou um MAT
que não seja um resultado SPARQ reconhecido.

O antigo fluxo configurável em lote foi preservado em
[`main_batch.m`](main_batch.m) para automação e compatibilidade. Ele não é mais
o caminho recomendado para ajuste visual dos parâmetros.

## Uso responsável

Os parâmetros padrão são um ponto de partida. Eles não garantem uma detecção
adequada para toda montagem, frequência de amostragem ou laboratório. Antes
de usar os resultados em uma análise científica, confira os gráficos, a
referência escolhida, os canais excluídos e a máscara de ruído.

Para conhecer o fluxo sem usar dados reais, execute
[`demo/demo_genericSynthetic.m`](demo/demo_genericSynthetic.m).
