testthat::test_that("generate_maps retorna uma lista de mapas usando globais legadas", {
  fixtures <- legacy_make_spatial_fixtures()

  dados <- fixtures$sp_bairros |>
    dplyr::slice(c(1, 2, 1, 2)) |>
    dplyr::mutate(
      sem_not = c(202401, 202401, 202402, 202402),
      arbo = "dengue",
      p_inc100k = c(10, 20, 15, 30)
    )

  legacy_assign_globals(list(
    weeks_2_plot = c(202401, 202402),
    df_mun_ok = tibble::tibble(sem_not = c(202401, 202402), arbo = c("dengue", "dengue")),
    df_mun = tibble::tibble(
      sem_not = c(202401, 202401, 202402, 202402),
      arbo = c("dengue", "dengue", "dengue", "dengue")
    )
  ))

  resultado <- generate_maps(
    data = dados,
    weeks_2_plotdistrito_nome = c(202401, 202402),
    arbo = "dengue"
  )

  testthat::expect_length(resultado, 2)
  testthat::expect_true(all(vapply(resultado, inherits, logical(1), "ggplot")))
})

testthat::test_that("generate_maps usa shape auxiliar quando fornecido", {
  fixtures <- legacy_make_spatial_fixtures()

  dados <- fixtures$sp_bairros |>
    dplyr::slice(c(1, 2, 1, 2)) |>
    dplyr::mutate(
      sem_not = c(202401, 202401, 202402, 202402),
      arbo = "dengue",
      p_inc100k = c(10, 20, 15, 30)
    )

  shape <- fixtures$sp_distritos |>
    dplyr::mutate(area_nome = distrito)

  legacy_assign_globals(list(
    weeks_2_plot = c(202401, 202402),
    df_mun_ok = tibble::tibble(sem_not = c(202401, 202402), arbo = c("dengue", "dengue")),
    df_mun = tibble::tibble(
      sem_not = c(202401, 202401, 202402, 202402),
      arbo = c("dengue", "dengue", "dengue", "dengue")
    )
  ))

  resultado <- generate_maps(
    data = dados,
    weeks_2_plotdistrito_nome = c(202401, 202402),
    arbo = "dengue",
    shape = shape,
    area = "area_nome"
  )

  testthat::expect_s3_class(resultado[[1]], "ggplot")
})

testthat::test_that("generate_maps filtra pelo argumento arbo sem ambiguidade", {
  fixtures <- legacy_make_spatial_fixtures()

  dados <- fixtures$sp_bairros |>
    dplyr::slice(c(1, 2)) |>
    dplyr::mutate(
      sem_not = c(202401, 202401),
      arbo = c("dengue", "chikon"),
      p_inc100k = c(10, 20)
    )

  legacy_assign_globals(list(
    weeks_2_plot = 202401,
    df_mun_ok = tibble::tibble(sem_not = 202401, arbo = "dengue"),
    df_mun = tibble::tibble(
      sem_not = c(202401, 202401),
      arbo = c("dengue", "chikon")
    )
  ))

  resultado <- generate_maps(
    data = dados,
    weeks_2_plotdistrito_nome = 202401,
    arbo = "dengue"
  )

  build <- ggplot2::ggplot_build(resultado[[1]])

  testthat::expect_equal(nrow(build$data[[1]]), 1)
})
