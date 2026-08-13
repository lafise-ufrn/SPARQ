# SPARQ

Biblioteca MATLAB para identificar trechos com ruído em gravações multicanal
de LFP. O uso comum é feito pelo script [`main.m`](main.m). Não é necessário
chamar diretamente as funções internas da biblioteca.

## Requisitos

Use MATLAB R2021a ou mais recente. A biblioteca aceita gravações somente em
arquivos `.mat`.

Para começar, baixe esta pasta completa e mantenha `main.m` e a pasta
`+SPARQ` juntos. O próprio `main.m` adiciona a biblioteca ao caminho do
MATLAB.

## Como usar

1. Coloque as gravações `.mat` em uma pasta. Elas podem estar organizadas em
   subpastas.

2. Abra [`main.m`](main.m) no MATLAB.

3. Edite somente o bloco `EDITE AQUI`.

4. Clique em **Run**.

5. Para cada gravação nova, escolha no gráfico um trecho sem ruído. Clique
   primeiro no início e depois no fim desse trecho.

6. Ao terminar, consulte `batch.report` no Workspace. Os resultados ficam na
   pasta `SPARQ_results`, dentro da pasta de dados.

Se `config.dataFolder = ""`, o MATLAB abre uma janela para escolher a pasta.
Para informar a pasta diretamente, use por exemplo:

```matlab
config.dataFolder = "C:\dados\meu_experimento";
```

## Formato dos dados

Para um arquivo `.mat` simples, o padrão esperado é:

1. `LFP`, uma matriz numérica com canais nas linhas e amostras nas colunas.

2. `fs`, um número com a frequência de amostragem em hertz.

Se o arquivo usa outros nomes, informe esses nomes em `main.m`:

```matlab
config.loader.lfpVariable = "nome_da_matriz";
config.loader.samplingRateVariable = "nome_da_frequencia";
```

Se a frequência não está salva no arquivo, informe o valor diretamente:

```matlab
config.loader.samplingRateVariable = "";
config.loader.samplingRateHz = 1000;
```

Se as amostras estão nas linhas e os canais nas colunas, use:

```matlab
config.loader.dataOrientation = "samples-by-channels";
```

Caso contrário, mantenha `"channels-by-samples"`.

Os campos `timeVariable` e `channelLabelsVariable` são opcionais. Quando eles
ficam vazios, a biblioteca cria o tempo e nomes simples para os canais.

`signalScale` multiplica os valores ao carregar. `signalUnits` apenas registra
a unidade dos valores resultantes. Por exemplo, para converter dados em mV
para µV:

```matlab
config.loader.signalScale = 1000;
config.loader.signalUnits = "uV";
```

Mantenha `config.inputFormat = "auto"`. Assim, a biblioteca também reconhece
automaticamente outros layouts MAT conhecidos,
inclusive quando um arquivo contém várias gravações.

## Opções que podem exigir ajuste

`config.excludedChannels` informa os canais que não devem participar da
detecção. Por exemplo, `[2 8]` exclui os canais 2 e 8.

`config.detection.minSimultaneousChannels` define quantos canais precisam
ultrapassar o limite ao mesmo tempo para que uma amostra seja considerada
ruído. Esse valor não pode ser maior que a quantidade de canais utilizados.

Na primeira execução, mantenha os outros parâmetros de detecção como `[]`.
Isso usa os valores padrão. Os parâmetros medidos em amostras podem precisar
de ajuste quando a frequência de amostragem for diferente da usada na
calibração original.

## Resultados

Cada gravação processada gera um arquivo com nome terminado em `_clean.mat`.
Dentro dele existe somente a variável `SPARQ_result`, já organizada para uso
direto em análises.

Para abrir o resultado:

```matlab
arquivo = load("caminho_para_o_resultado_clean.mat");
resultado = arquivo.SPARQ_result;
mascara = resultado.noiseMask;
```

Por padrão, `SPARQ_result` contém somente:

1. `noiseMask`, um vetor lógico com um valor para cada amostra original.

2. `samplingRateHz`, necessário para converter amostras em segundos.

3. `schemaVersion`, necessário para identificar o formato do resultado.

Em `noiseMask`:

1. `0` significa que a amostra não foi identificada como ruído.

2. `1` significa que a amostra foi identificada como ruído.

Duas representações adicionais podem ser ativadas em `main.m`:

```matlab
config.output.includeConcat = true;
config.output.includeNaN = true;
```

Quando ativada, `nan` mantém o número original de amostras e substitui por
`NaN` aquelas marcadas como ruído. Quando ativada, `concat` contém somente as
amostras em que `noiseMask` vale `0`, na mesma ordem em que aparecem na
gravação. O índice de uma coluna de `concat` não representa tempo contínuo.

Se `nan` ou `concat` for ativada, o resultado também contém `channels`, com o
índice original de cada linha salva, e `signalUnits`, com a unidade dos
valores.

Em `batch.report`, consulte principalmente `Status`, `OutputFile` e
`ErrorMessage`. Uma falha em uma gravação não impede o processamento das
demais.

## Executar novamente

A seleção do trecho limpo fica salva em cache. Por isso, a biblioteca não pede
os mesmos cliques em toda execução.

Para escolher novamente as referências, altere temporariamente:

```matlab
config.forceNewReferences = true;
```

Para substituir arquivos de resultado que já existem, use:

```matlab
config.overwriteResults = true;
```

Essas opções não alteram nem apagam os arquivos brutos.

Mantenha `config.plot.enabled = true` quando ainda for necessário selecionar
uma referência visual.

## Uso responsável

Os parâmetros padrão são um ponto de partida. Eles não garantem uma detecção
adequada para toda montagem, frequência de amostragem ou laboratório. Antes
de usar os resultados em uma análise científica, confira os gráficos, a
referência escolhida, os canais excluídos e a máscara de ruído.

Para conhecer o fluxo sem usar dados reais, execute
[`demo/demo_genericSynthetic.m`](demo/demo_genericSynthetic.m).
