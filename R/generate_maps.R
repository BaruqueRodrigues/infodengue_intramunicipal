#' Gerar mapas semanais de incidência epidemiológica
#'
#' Cria uma lista de mapas (`ggplot`) para diferentes semanas epidemiológicas,
#' representando indicadores de incidência espacial (ex.: casos por 100 mil
#' habitantes). Cada mapa corresponde a uma semana e pode incluir camadas
#' adicionais de limites administrativos (ex.: distritos ou regiões).
#'
#' A função permite definir automaticamente o intervalo da escala de cores
#' com base nos dados disponíveis para as semanas selecionadas.
#'
#' @param data Data frame ou objeto `sf` contendo os dados espaciais e
#' epidemiológicos. Deve incluir as colunas `sem_not`, `arbo` e a variável
#' especificada em `value_col`.
#' @param weeks_2_plot Vetor numérico contendo as semanas epidemiológicas
#' que devem ser representadas nos mapas.
#' @param lim_range Vetor numérico de comprimento 2 definindo os limites
#' mínimo e máximo da escala de cores. Se `NULL`, os limites são calculados
#' automaticamente a partir dos dados.
#' @param value_col String com o nome da coluna que contém o valor a ser
#' representado no mapa (ex.: incidência ou proporção).
#' @param arbo String indicando o arbovírus a ser filtrado
#' (ex.: `"dengue"` ou `"chikon"`).
#' @param geom_col String com o nome da coluna de geometria utilizada
#' para gerar os mapas.
#' @param shape Objeto `sf` opcional contendo limites administrativos
#' adicionais a serem desenhados sobre o mapa (ex.: regiões ou distritos).
#' @param area String opcional indicando a coluna em `shape` usada para
#' diferenciar áreas por tipo de linha (`linetype`).
#'
#' @return
#' Uma lista de objetos `ggplot`, onde cada elemento corresponde a um
#' mapa de incidência para uma semana epidemiológica.
#'
#' @details
#' A função:
#'
#' * Filtra os dados para o arbovírus especificado.
#' * Gera um mapa por semana epidemiológica usando `purrr::map`.
#' * Aplica uma escala contínua de cores (`scale_fill_distiller`).
#' * Opcionalmente adiciona limites administrativos usando `geom_sf`.
#'
#' Os mapas gerados podem ser posteriormente organizados em painéis
#' utilizando funções auxiliares como `create_map_panel()`.
#'
#' @examples
#' \dontrun{
#' generate_maps(
#'   data = df_distritos,
#'   weeks_2_plot = c(202401, 202402, 202403),
#'   value_col = "inc",
#'   arbo = "dengue"
#' )
#'
#' generate_maps(
#'   data = df_bairros,
#'   weeks_2_plot = c(202401, 202402, 202403),
#'   value_col = "inc",
#'   arbo = "dengue",
#'   shape = df_rpas,
#'   area = "rpa_nome"
#' )
#' }
#'
#' @export
generate_maps <- function(data, weeks_2_plotdistrito_nome, lim_range = NULL,
                          value_col = "p_inc100k", arbo = arbo, geom_col = "geometry",
                          shape = NULL, area = NULL) {
  arbo_filter <- arbo

  # Calcular limites automaticamente se não fornecidos
  if (is.null(lim_range)) {
    filtered_data <- data %>% filter(sem_not %in% weeks_2_plot & arbo == arbo_filter)
    lim_range <- range(pull(filtered_data, !!sym(value_col)), na.rm = TRUE)
  }

  # Definir os padrões de linha desejados
  line_types <- c("dotted", "dashed", "solid")

  # Gerar mapas usando map() para maior eficiência
  plots_list <- map(weeks_2_plot, ~ {
    week_data <- data %>% filter(sem_not == .x & arbo == arbo_filter)

    # Calcular porcentagem de não alocados (se aplicável)
    percent_na <- 100 - (df_mun_ok %>% filter(sem_not == .x & arbo == arbo_filter) %>% nrow() /
                           df_mun %>% filter(sem_not == .x & arbo == arbo_filter) %>% nrow() * 100)


    # Criar plot base
    p <- ggplot() +
      geom_sf(data = week_data %>% st_as_sf(), aes(fill = !!sym(value_col), geometry = !!sym(geom_col))) +
      scale_fill_distiller(palette = "Blues", direction = 1, limits = lim_range)

    # Adicionar camada de distritos com os padrões de linha especificados
    if (!is.null(shape)) {
      if ("geom" %in% names(shape) && !("geometry" %in% names(shape))) {
        shape <- shape %>% rename(geometry = geom)
      }

      if (!is.null(area)) {
        # Verificar quantos níveis únicos existem na coluna area
        area_levels <- unique(pull(shape, !!sym(area)))
        n_levels <- length(area_levels)

        # Criar um mapeamento de linhas para cada nível
        line_scale <- setNames(
          line_types[1:min(n_levels, length(line_types))],
          area_levels[1:min(n_levels, length(line_types))]
        )

        p <- p +
          geom_sf(data = shape %>% st_as_sf(),
                  aes(geometry = geometry, linetype = !!sym(area)),
                  linewidth = 0.5, alpha = 0, color = "black") +
          scale_linetype_manual(values = line_scale)
      } else {
        # Sem cor específica (apenas contorno)
        p <- p +
          geom_sf(data = shape %>% st_as_sf(),
                  aes(geometry = geometry),
                  linewidth = 1, alpha = 0, color = "black", linetype = "solid")
      }
    }

    # Aplicar tema e labels
    p <- p +
      theme_pubclean(base_size = 10) +
      theme(axis.text = element_blank(),
            axis.ticks = element_blank(),
            legend.key.width = unit(1, "cm")) +  # Aumenta espaço para visualizar linhas
      labs(title = paste("Semana de Notificação:", .x),
           subtitle = paste("Porcentagem de casos perdidos:", round(percent_na, 2), "%"))

    return(p)
  })

  return(plots_list)
}
