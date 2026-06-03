# infodengeintramunicipal

`infodengeintramunicipal` reúne funções em R para preparar, classificar e
visualizar dados epidemiológicos em escala intramunicipal no fluxo do
InfoDengue. O pacote cobre tarefas como leitura de dados de notificação,
normalização de bairros, completude de séries semanais, associação espacial
entre bairros e distritos, cálculo de alerta epidemiológico, gráficos e mapas.

## O que mudou na API nova

A principal mudança é a criação de funções com sufixo `_novo`. Elas refatoram
partes do fluxo antigo para reduzir dependência de objetos globais e deixar os
parâmetros importantes explícitos na chamada da função.

Na prática, isso significa:

- `params` agora é passado como argumento em `calcular_alerta_novo()`,
  `calcular_alerta_cidade()` e `classificar_alerta()`.
- `breaks_1ano`, `weeks_2_plot`, `limiar_epidemico`, `df_mun` e `df_mun_ok`
  deixam de ser buscados no ambiente global pelas funções novas de gráficos e
  mapas.
- O código novo fica mais fácil de testar, reproduzir e reutilizar em boletins
  de municípios diferentes.
- As funções antigas continuam disponíveis para compatibilidade com scripts já
  existentes.

Use as funções `_novo` em novos pipelines. Mantenha as funções antigas apenas
quando precisar reproduzir código legado sem alterar a estrutura original.

## Instalação

```r
install.packages("remotes")
remotes::install_github("baruquerodrigues/infodengeintramunicipal")
```

Para instalar a partir de uma cópia local do pacote:

```r
install.packages("devtools")
devtools::install(".")
```

Carregue o pacote com:

```r
library(infodengeintramunicipal)
```

## Fluxo recomendado com a API nova

Um fluxo típico usa as funções novas nesta ordem:

1. Ler ou preparar os dados de notificação.
2. Normalizar nomes de bairros.
3. Completar a grade bairro x semana epidemiológica.
4. Classificar bairros em distritos, quando houver malhas `sf`.
5. Calcular Rt e nível de alerta.
6. Gerar gráficos e mapas usando parâmetros explícitos.

```r
library(dplyr)
library(infodengeintramunicipal)

semana_atual <- 202405
ano_atual <- 2024
week_atual <- 5

breaks_1ano <- criar_breaks_1ano(
  ano_fim = ano_atual,
  semana_fim = week_atual
)
```

## Leitura de dados

`ler_dados_dengue_novo()` lê um arquivo DBF, filtra notificações do município
informado em `ID_MUNICIP` e `ID_MN_RESI`, e retorna apenas as colunas
selecionadas.

```r
dados <- ler_dados_dengue_novo(
  caminho = "dados_dengue.dbf",
  codigo_municipio = "420910",
  colunas = c(
    "NU_NOTIFIC", "NU_ANO", "SEM_NOT", "ID_BAIRRO",
    "NM_BAIRRO", "ID_MN_RESI", "CLASSI_FIN", "DT_SIN_PRI"
  )
)
```

Se `colunas` não for informado, a função usa um conjunto padrão de colunas de
notificação.

## Normalização e completude semanal

`normalizar_bairro()` continua sendo usada para padronizar nomes de bairros.
Depois da agregação semanal, use `completar_dados_bairros_novo()` para garantir
que todas as combinações de bairro, semana e arbovirose existam na base.

```r
bairros_unicos <- dados |>
  mutate(nm_bairro_ref = normalizar_bairro(NM_BAIRRO)) |>
  pull(nm_bairro_ref) |>
  unique()

df_bairros_agregado <- dados |>
  mutate(nm_bairro_ref = normalizar_bairro(NM_BAIRRO)) |>
  mutate(arbo = "dengue", sem_not = as.numeric(SEM_NOT)) |>
  count(arbo, nm_bairro_ref, sem_not, name = "notificações")

df_bairros <- df_bairros_agregado |>
  completar_dados_bairros_novo(
    bairros_unicos = bairros_unicos,
    se_var = "sem_not",
    nm_bairr_var = "nm_bairro_ref",
    group_var = "arbo",
    max_semana_epidemiologica = semana_atual,
    count_var = "notificações"
  )
```

A função nova verifica colunas obrigatórias, aceita `count_var` customizado e
retorna uma base vazia sem erro quando a entrada não tem linhas.

## Classificação espacial de bairros

`classificar_bairros_distrito_novo()` associa bairros a distritos usando
centróides e interseção espacial. Quando um bairro não intersecta diretamente
um distrito, o distrito mais próximo é atribuído.

As malhas devem ser objetos `sf`. A malha de distritos precisa conter a coluna
`distrito`; a de bairros precisa conter `nome_bairr` e `id_bairro`.

```r
bairros_distritos <- classificar_bairros_distrito_novo(
  sp_distritos = distritos_sf,
  sp_bairros = bairros_sf
)
```

O pacote também exporta blocos menores para uso avançado:

- `garantir_crs()`
- `calcular_centroides()`
- `intersectar_distritos()`
- `atribuir_distrito_proximo()`

## Cálculo de alerta epidemiológico

A API antiga de alerta dependia de um objeto global chamado `params`. Na API
nova, `params` é sempre informado explicitamente.

Os dados de entrada devem conter, no mínimo:

- uma coluna de identificação da unidade, por exemplo `id_bairro` ou
  `id_distrito_nome`;
- `sem_not`, com a semana epidemiológica;
- `casos`, com a contagem usada pelo `AlertTools::Rt()`.

```r
params_modelo <- list(
  codmodelo = "seu_modelo",
  limiar1 = 10,
  limiar2 = 20
)

alerta_bairro <- calcular_alerta_novo(
  id = 101,
  data = dados_alerta,
  coluna_id = "id_bairro",
  params = params_modelo,
  gtdist = "normal",
  meangt = 3,
  sdgt = 1
)
```

Para calcular todas as unidades de uma vez:

```r
alerta_cidade <- calcular_alerta_cidade(
  data = dados_alerta,
  coluna_id = "id_bairro",
  params = params_modelo
)
```

Também é possível executar o pipeline em partes:

```r
dados_unidade <- filtrar_unidade(dados_alerta, coluna_id = "id_bairro", id = 101)
dados_rt <- calcular_rt(dados_unidade)
dados_alerta <- classificar_alerta(dados_rt, params = params_modelo)
```

Para contar quantas semanas recentes ficaram em alerta alto (`nivel >= 3`):

```r
calcular_semanas_alerta_alto_novo(
  data = dados_alerta,
  semana_atual = semana_atual,
  bairro = "CENTRO",
  janela = 5
)
```

## Gráficos

As funções novas de gráficos recebem explicitamente a semana limite e os breaks
do eixo X. Isso substitui a antiga dependência de objetos globais como
`breaks_1ano`.

### Rt

`create_rt_plot_novo()` espera uma coluna de semana, por padrão `sem_not`, e uma
coluna `Rt`. A função retorna uma lista com `combined_plot` e
`individual_plots`.

```r
plots_rt <- create_rt_plot_novo(
  api_data = dados_rt,
  weeks_limit = semana_atual,
  title_suffix = "Rt por bairro",
  breaks_1ano = breaks_1ano,
  facet_by = "nm_bairro_ref",
  lwr = "Rt_lwr",
  upr = "Rt_upr"
)

plots_rt$combined_plot
```

`facet_by`, `lwr` e `upr` são opcionais.

### Receptividade climática

`create_receptivity_plot_novo()` espera, por padrão, as colunas `SE` e
`tempmin`. É possível trocar esses nomes com `se_col` e `temp_col`.

```r
plot_receptividade <- create_receptivity_plot_novo(
  api_data = dados_clima,
  weeks_limit = semana_atual,
  breaks_1ano = breaks_1ano,
  limiar_temp = 18,
  se_col = "SE",
  temp_col = "tempmin"
)
```

### Incidência com nowcasting

`create_incidence_plot_novo()` combina dados observados e nowcasting. Os dados
observados devem conter `ano_epi`, `total_Y` e `nivel`. Os dados de nowcasting
devem conter `ano_epi`, `Median`, `LI`, `LS` e `type`.

```r
plot_inc <- create_incidence_plot_novo(
  nowcast_data = mun_nowcast,
  observed_data = mun_observados,
  weeks_limit = semana_atual,
  breaks_1ano = breaks_1ano,
  limiar_epidemico = 72,
  title_suffix = "Curva de incidência de dengue",
  include_zoom = TRUE,
  convert_to_incidence = TRUE,
  pop = 616317
)
```

Quando `convert_to_incidence = TRUE`, o argumento `pop` é obrigatório.

## Mapas semanais

`generate_maps_novo()` gera uma lista de mapas, um para cada semana em
`weeks_2_plot`. A função espera um objeto com geometria `sf`, a coluna
`sem_not`, a coluna `arbo` e a variável mapeada, por padrão `p_inc100k`.

```r
mapas <- generate_maps_novo(
  data = dados_sf,
  weeks_2_plot = c(202403, 202404, 202405),
  arbo = "dengue",
  value_col = "p_inc100k",
  allocated_data = df_mun_ok,
  total_data = df_mun
)
```

`allocated_data` e `total_data` são opcionais. Quando informados, a função usa
essas bases para calcular a porcentagem de casos não alocados exibida no
subtítulo do mapa.

Também é possível adicionar uma camada espacial auxiliar:

```r
mapas <- generate_maps_novo(
  data = dados_sf,
  weeks_2_plot = c(202403, 202404, 202405),
  arbo = "dengue",
  shape = distritos_sf,
  area = "distrito"
)
```

## Guia rápido de migração

| Antes | Agora | Mudança principal |
| --- | --- | --- |
| `ler_dados_dengue()` | `ler_dados_dengue_novo()` | código do município e colunas são argumentos |
| `completar_dados_bairros()` | `completar_dados_bairros_novo()` | coluna de contagem configurável e melhor tratamento de bases vazias |
| `classificar_bairros_distrito()` | `classificar_bairros_distrito_novo()` | fluxo espacial dividido em helpers exportados |
| `calcular_alerta()` | `calcular_alerta_novo()` | `params` deixa de ser global |
| chamada manual por unidade | `calcular_alerta_cidade()` | itera sobre todas as unidades da coluna escolhida |
| `calcular_semanas_alerta_alto()` | `calcular_semanas_alerta_alto_novo()` | considera semanas até `semana_atual` e ignora `NA` em `nivel` |
| `create_rt_plot()` | `create_rt_plot_novo()` | `breaks_1ano` vira argumento |
| `create_receptivity_plot()` | `create_receptivity_plot_novo()` | `weeks_limit`, `breaks_1ano` e nomes de colunas são explícitos |
| `create_incidence_plot()` | `create_incidence_plot_novo()` | `weeks_limit`, `breaks_1ano` e `limiar_epidemico` são explícitos |
| `generate_maps()` | `generate_maps_novo()` | `weeks_2_plot`, `allocated_data` e `total_data` são argumentos |

## Funções novas exportadas

- `ler_dados_dengue_novo()`
- `completar_dados_bairros_novo()`
- `classificar_bairros_distrito_novo()`
- `garantir_crs()`
- `calcular_centroides()`
- `intersectar_distritos()`
- `atribuir_distrito_proximo()`
- `filtrar_unidade()`
- `calcular_rt()`
- `classificar_alerta()`
- `calcular_alerta_novo()`
- `calcular_alerta_cidade()`
- `calcular_semanas_alerta_alto_novo()`
- `create_rt_plot_novo()`
- `create_receptivity_plot_novo()`
- `create_incidence_plot_novo()`
- `generate_maps_novo()`

## Desenvolvimento

Para atualizar documentação e rodar a suíte de testes:

```r
install.packages(c("devtools", "testthat", "roxygen2"))
devtools::document()
devtools::test()
devtools::check()
```

O pacote ainda mantém a API legada para compatibilidade, mas o caminho
recomendado para novos usuários é começar pelas funções `_novo`.
