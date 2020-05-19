
# LIBRARIES ---------------------------------------------------------------
# devtools::install_github("rstudio/profvis", force = TRUE)
library(profvis)
library(shiny)
library(DT)
library(shinyWidgets)
library(data.table)
library(shinyBS)
library(shinyjs)
library(shinycssloaders)
# devtools::install_github('matthew-phelps/simpled3', force = TRUE)
library(simpled3)


# OBJECTS -----------------------------------------------------------------
shiny_dat <- readRDS(file = "data/shiny_dat.rds")
# dk_sp <- readRDS(file = "data/dk_sp_data.rds")
diag <- fread("data/definitions_diag.csv", encoding = "UTF-8")
opr <- fread("data/definitions_opr.csv", encoding = "UTF-8")
med <- fread("data/definitions_med.csv", encoding = "UTF-8")



# LANGUAGE UI ---------------------------------------------------------
lang = "dk"
if (lang == "dk") {
  thousands_sep <- "."
  dec_mark <- ","
} else {
  thousands_sep <- ","
  dec_mark <- "."
}

ui_file_path <- file.path(paste0("ui/ui-", lang, ".R"))
source(ui_file_path, encoding = "UTF-8")

year_max <- 2016


# FUNCTIONS ------------------------------------------------
formatNumbers <- function(dat, lang) {
  x <- copy(dat)
  col_names <- colnames(dat)[-1]
  x[, (col_names) := x[, lapply(.SD, function(i) {
    if (lang == "dk") {
      i[!is.na(i)] <-
        prettyNum(i[!is.na(i)], big.mark = ".", decimal.mark = ",")
    } else if (lang == "en") {
      i[!is.na(i)] <-
        prettyNum(i[!is.na(i)], big.mark = ",", decimal.mark = ".")
    }
    i[is.na(i)] <- "<10"
    i
  }),
  .SDcols = col_names]]
  
  x[]
}

makeCountDT <- function(dat, group_var, thousands_sep) {
  col_format <- c(ui_sex_levels, "Total")
  DT::datatable(
    data = dat,
    extensions = 'Buttons',
    rownames = FALSE,
    class = ' hover row-border',
    options = list(
      columnDefs = list(list(
        # Hides the "flag" column
        visible = FALSE, targets = 0
      )),
      buttons = list(
        list(
          extend = "collection",
          buttons = c("excel", "pdf"),
          exportOptions = list(columns = ":visible"),
          text = "Hente"
        )
      ),
      initComplete = JS(
        # Table hearder background color
        "function(settings, json) {",
        "$(this.api().table().header()).css({'background-color': '#e7e7e7'});",
        "}"
      )
    )
  ) %>%
    formatCurrency(col_format,
                   currency = "",
                   interval = 3,
                   mark = thousands_sep,
                   digits = 0) %>%
    formatStyle('Total',  fontWeight = 'bold') %>%
    formatStyle(group_var,  backgroundColor = "#e7e7e7") %>%
    formatStyle("flag",
                target = "row",
                fontWeight = styleEqual(c(0, 1), c("normal", "bold")))
}

makeRateDT <- function(dat, group_var, thousands_sep, digits, dec_mark) {
  col_format <- c(ui_sex_levels)
  DT::datatable(
    data = dat,
    extensions = 'Buttons',
    rownames = FALSE,
    class = 'hover row-border',
    options = list(
      buttons = list('csv'),
      initComplete = JS(
        "function(settings, json) {",
        "$(this.api().table().header()).css({'background-color': '#e7e7e7'});",
        "}"
      )
    )
  ) %>%
    formatCurrency(col_format,
                   currency = "",
                   interval = 3,
                   mark = thousands_sep,
                   digits = digits,
                   dec.mark = dec_mark) %>%
    formatStyle(group_var,  backgroundColor = "#e7e7e7")
}
