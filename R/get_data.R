
# Packages ----------------------------------------------------------------

# Load packages
library(rdbnomics)
library(dplyr)
library(countrycode)
library(stringr)
library(tidyr)
library(readr)


# Data --------------------------------------------------------------------


# Get World Bank (WDI) data:
# GDP growth (%, annual)
# Unemployment, total (% of total labor force, national estimate, annual)
# Inflation, consumer prices (%, annual)
# Deposit interest rate (%, annual)
# Official exchange rate (LCU per US$, period average, annual)
raw_data <- rdbnomics::rdb(
  api_link = paste0(
    "https://api.db.nomics.world/v22/series/WB/WDI?dimensions=%7B%22indicator%",
    "22%3A%5B%22NY.GDP.MKTP.KD.ZG%22%2C%22FP.CPI.TOTL.ZG%22%2C%22SL.UEM.TOTL.N",
    "E.ZS%22%2C%22FR.INR.DPST%22%2C%22PA.NUS.FCRF%22%5D%2C%22frequency%22%3A%5",
    "B%22A%22%5D%2C%22country%22%3A%5B%22ARG%22%2C%22AUS%22%2C%22BEL%22%2C%22B",
    "RA%22%2C%22CMR%22%2C%22CAN%22%2C%22CRI%22%2C%22HRV%22%2C%22DNK%22%2C%22EC",
    "U%22%2C%22GBR%22%2C%22FRA%22%2C%22DEU%22%2C%22GHA%22%2C%22IRN%22%2C%22JPN",
    "%22%2C%22KOR%22%2C%22MEX%22%2C%22MAR%22%2C%22NLD%22%2C%22POL%22%2C%22PRT%",
    "22%2C%22QAT%22%2C%22SAU%22%2C%22SEN%22%2C%22SRB%22%2C%22ESP%22%2C%22CHE%2",
    "2%2C%22TUN%22%2C%22USA%22%2C%22URY%22%2C%22EMU%22%5D%7D&observations=1"
    )
  )

# Data wrangling
macro_data <- raw_data |>
  dplyr::select(
    "country_code" = "country",
    "indexed_at",
    "period",
    "variable" = "series_name",
    "value"
    ) |>
  dplyr::mutate(
    country_name = dplyr::if_else(
      country_code == "EMU",
      "Área do Euro",
      countrycode::countrycode(
        sourcevar   = country_code,
        origin      = "iso3c",
        destination = "cldr.name.pt"
        )
      ),
    country_code = dplyr::if_else(
      country_code == "EMU",
      "EMU",
      countrycode::countrycode(
        sourcevar   = country_code,
        origin      = "iso3c",
        destination = "ioc"
        )
      ),
    variable = dplyr::case_when(
      stringr::str_detect(variable, "Inflation") ~ "Taxa de Inflação (%, CPI)",
      stringr::str_detect(variable, "Unemployment") ~ "Taxa de Desemprego (%)",
      stringr::str_detect(variable, "GDP") ~ "PIB (%, crescimento)",
      stringr::str_detect(variable, "Deposit") ~ "Taxa de Juros (%, depósito)",
      stringr::str_detect(variable, "Official") ~ "Taxa de Câmbio (UMC/US$, média)"
      ),
    .after = "country_code"
    ) |>
  dplyr::as_tibble()

# Euro area data (replace NA values for state members)
euro_area_data <- macro_data |>
  dplyr::filter(
    country_name == "Área do Euro",
    variable == "Taxa de Câmbio (UMC/US$, média)"
    ) |>
  dplyr::rename("value2" = "value") |>
  tidyr::uncount(9) |>
  dplyr::group_by(period) |>
  dplyr::mutate(
    country_name = c(
      "Alemanha", "Bélgica", "Croácia", "Dinamarca", "Espanha", "França",
      "Países Baixos", "Polônia", "Portugal"
      )
    ) |>
  dplyr::ungroup() |>
  dplyr::select("country_name", "period", "variable", "value2")

macro_data <- macro_data |>
  dplyr::left_join(
    y = euro_area_data,
    by = c("country_name", "period", "variable")
    ) |>
  dplyr::mutate(value = dplyr::coalesce(value, value2)) |>
  dplyr::select(-"value2") |>
  dplyr::filter(!country_name == "Área do Euro")

# Save as CSV file
if (!dir.exists("data")) { dir.create("data")}
readr::write_csv(x = macro_data, file = "data/macro_data.csv")
