#' Gerar mapas semanais sem depender de globais
#'
#' Refatora `generate_maps()` para receber explicitamente as semanas e as bases
#' usadas no calculo da proporcao de casos alocados.
#'
#' @param data Objeto `sf` com dados epidemiologicos.
#' @param weeks_2_plot Vetor de semanas a plotar.
#' @param lim_range Limites da escala de cores.
#' @param value_col Coluna do valor mapeado.
#' @param arbo Arbovirus filtrado.
#' @param geom_col Coluna de geometria.
#' @param shape Objeto `sf` opcional com limites adicionais.
#' @param area Coluna opcional de agrupamento de linhas em `shape`.
#' @param allocated_data Data frame opcional com casos alocados.
#' @param total_data Data frame opcional com casos totais.
#'
#' @return Lista de objetos `ggplot`.
#' @export
generate_maps_novo <- function(data, weeks_2_plot, lim_range = NULL,
                               value_col = "p_inc100k", arbo,
                               geom_col = "geometry", shape = NULL,
                               area = NULL, allocated_data = NULL,
                               total_data = NULL) {
  weeks_2_plot <- as.numeric(as.character(weeks_2_plot))
  arbo_filter <- arbo

  data <- data %>%
    dplyr::mutate(
      sem_not = as.numeric(as.character(.data$sem_not)),
      !!rlang::sym(value_col) := as.numeric(as.character(.data[[value_col]]))
    )

  if (is.null(lim_range)) {
    filtered_data <- data %>%
      dplyr::filter(.data$sem_not %in% weeks_2_plot, .data$arbo == arbo_filter)

    lim_range <- range(dplyr::pull(filtered_data, !!rlang::sym(value_col)), na.rm = TRUE)
  }

  line_types <- c("dotted", "dashed", "solid")

  purrr::map(weeks_2_plot, function(week) {
    week_data <- data %>%
      dplyr::filter(.data$sem_not == week, .data$arbo == arbo_filter)

    week_sf <- week_data %>%
      sf::st_as_sf(sf_column_name = geom_col)

    percent_na <- NA_real_
    if (!is.null(allocated_data) && !is.null(total_data)) {
      allocated_data <- allocated_data %>%
        dplyr::mutate(sem_not = as.numeric(as.character(.data$sem_not)))

      total_data <- total_data %>%
        dplyr::mutate(sem_not = as.numeric(as.character(.data$sem_not)))

      n_alloc <- allocated_data %>%
        dplyr::filter(.data$sem_not == week, .data$arbo == arbo_filter) %>%
        nrow()

      n_total <- total_data %>%
        dplyr::filter(.data$sem_not == week, .data$arbo == arbo_filter) %>%
        nrow()

      percent_na <- if (n_total == 0) NA_real_ else 100 - (n_alloc / n_total * 100)
    }

    p <- ggplot2::ggplot() +
      ggplot2::geom_sf(
        data = week_sf,
        ggplot2::aes(fill = !!rlang::sym(value_col), geometry = !!rlang::sym(geom_col))
      ) +
      ggplot2::scale_fill_distiller(palette = "Blues", direction = 1, limits = lim_range)

    if (!is.null(shape)) {
      shape_plot <- shape
      if ("geom" %in% names(shape_plot) && !("geometry" %in% names(shape_plot))) {
        shape_plot <- shape_plot %>% dplyr::rename(geometry = .data$geom)
      }

      if (!is.null(area)) {
        area_levels <- unique(dplyr::pull(shape_plot, !!rlang::sym(area)))
        line_scale <- stats::setNames(
          line_types[seq_len(min(length(area_levels), length(line_types)))],
          area_levels[seq_len(min(length(area_levels), length(line_types)))]
        )

        p <- p +
          ggplot2::geom_sf(
            data = sf::st_as_sf(shape_plot),
            ggplot2::aes(geometry = .data$geometry, linetype = !!rlang::sym(area)),
            linewidth = 0.5,
            alpha = 0,
            color = "black"
          ) +
          ggplot2::scale_linetype_manual(values = line_scale)
      } else {
        p <- p +
          ggplot2::geom_sf(
            data = sf::st_as_sf(shape_plot),
            ggplot2::aes(geometry = .data$geometry),
            linewidth = 1,
            alpha = 0,
            color = "black",
            linetype = "solid"
          )
      }
    }

    subtitle <- if (is.na(percent_na)) {
      NULL
    } else {
      paste("Porcentagem de casos perdidos:", round(percent_na, 2), "%")
    }

    p +
      ggpubr::theme_pubclean(base_size = 10) +
      ggplot2::theme(
        axis.text = ggplot2::element_blank(),
        axis.ticks = ggplot2::element_blank(),
        legend.key.width = grid::unit(1, "cm")
      ) +
      ggplot2::labs(
        title = paste("Semana de Notificação:", week),
        subtitle = subtitle
      )
  })
}
