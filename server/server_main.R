shinyServer(function(input, output, session) {
  options(DT.options = list(
    pageLength = 20,
    dom = "Bt",
    buttons = c('copy', 'csv', 'pdf')
  ))
  load(file = "data/shiny_dat.rda")
  load(file = "data/export_med.Rdata")
  source("ui-dk.R", encoding = "UTF-8")
  
  
  
  # UPDATE RADIO BUTTONS ----------------------------------------------------
  output$varButtonChoices <- renderUI({
    # Gives a dynamic button UI. The buttons change depending on the selected
    # outcome Keep variables that have "count" in their name.
    #
    # When page loads, this UI element initally returns NULL to server fn(),
    # then it re-runs and returns the initial value - eg. "age". This means we
    # have to restrict the output that depends on this (which is nearly
    # everything) from running until a non-NULL value is supplied. This is
    # acheived by an if-statement in the validate() reactive
    var_names <- grep("count", names(subsetOutcome()), value = TRUE)
    variable_choices <-
      variable_ui[code_name %in% var_names, var_dk]
    names(var_names) <- variable_choices
    radioGroupButtons(
      inputId = "variable",
      label = choose_var,
      choices = var_names,
      justified = TRUE,
      direction = "vertical",
      individual = FALSE
    )
  })
  
  # TEXT RENDERING ----------------------------------------------------------
  output$outcome_title <- renderText({
    input$outcome
  })
  output$outcome_description <- renderText({
    outcome_descriptions[hjertetal_code == outcomeCode(), desc_dk]
  })
  
  variableTitle <- reactive({
    prettyVariable()[selectCountRate()]
  })
  output$variable_title <- renderText({
    if (validate())
      variableTitle()
  })
  output$plot_title <- renderText({
    if (validate())
      paste0(variableTitle(), " - ", input$outcome)
  })
  
  output$table1_title <- renderText({
    
    if (validate())
      prettyVariable()[1]
  })
  
  output$table2_title <- renderText({
    if (validate())
      paste0(prettyVariable()[2], " ", ui_rate_suffix)
  })
  
  output$variable_desc <- renderText({
    if (validate())
      variable_ui[code_name == selectedDataVars()[selectCountRate()], desc_dk]
  })
  
  
  
  # DYNAMIC VARIABLES/COLUMN NAMES ------------------------------------------
  
  outcomeCode <- reactive({
    # Connect the input in normal language to the hjertetal_code. This is so we
    # can change the description without having to rename allll the datasets.
    outcomes_all[name_dk == input$outcome, hjertetal_code]
  })
  
  
  outcomeGroup <- reactive({
    # Define which type of outcome are in the outputed dataset.
    if (any(outcome_names_treatment$hjertetal_code %in% outcomeCode())) {
      outcome_group <- "treatment"
    } else if (any(outcome_names_diag %in% input$outcome)) {
      outcome_group <- "diag"
    } else if (any(out_names_med %in% input$outcome)) {
      outcome_group <- "med"
    }
    outcome_group
  })
  
  prettyAggr_level <- reactive({
    # Outputs same character string that's used in the UI input field
    names(which(aggr_choices == input$aggr_level))
  })
  
  prettyVariable <- reactive({
    # Outputs character string formatted for user.
    data_var_names <- selectedDataVars()
    c(variable_ui[code_name == data_var_names[1], var_dk], variable_ui[code_name == data_var_names[2], var_dk])
  })
  
  
  # SUBSETTING ------------------------------------------------------
  selectCountRate <- function(){
    
    as.integer(input$count_rates)
  }
  subsetOutcome <- reactive({
    # Cache subset based on outcome, aggr level, and theme
    if (input$aggr_level != "national") {
      shiny_dat[[outcomeCode()]][[input$aggr_level]]
    } else {
      # No real reason to pick "age" - but need any dataset (not edu) that will be
      # aggregated later. Cannot use "edu" because it has only subset of age range.
      shiny_dat[[outcomeCode()]]$age
    }
    
  })
  
  selectedDataVars <- reactive({
    var_stripped <- gsub("count_|rate_", "", input$variable)
    grep(var_stripped, colnames(subsetOutcome()), value = TRUE)
  })
  subsetVars <- reactive({
    dat <- subsetOutcome()
    if (input$aggr_level != "national") {
      col_vars <- c("year", "sex", "grouping", selectedDataVars())
      dat <- dat[, ..col_vars]
      colnames(dat) <-
        c(ui_year, ui_sex, prettyAggr_level(), prettyVariable())
    } else {
      col_vars <- c("year", "sex", selectedDataVars())
      dat <- dat[, ..col_vars]
      colnames(dat) <-
        c(ui_year, ui_sex, prettyVariable())
    }
    dat[]
  })
  subsetYear <- function()
    ({
      # Subset the already partially subset data based on years
      
      dat <- subsetVars()[get(ui_year) == input$year, ]
      dat[]
    })
  
  
  # FORMATTING DATA FOR D3------------------------------------------------------
  outputCasesData <- reactive({
    # National level data shows all years
    # This is not a reactive, because then it somehow turns the "<10" strings
    # into 0s. The reactive wasn't being called when I thought it was
    if (input$aggr_level != "national") {
      dat <- subsetYear()
      dat[, (ui_year) := NULL]
    } else {
      subsetVars()
    }
    
  })
  
  outputCasesD3Line <- reactive({
    # Replace value.var with reactive that corresponds to the variable the user selected
    
    dat <-
      dcast(
        subsetVars(),
        get(ui_year) ~ get(ui_sex),
        value.var = prettyVariable()[selectCountRate()],
        fun.aggregate = sum
      )
    
    colnames(dat) <-
      c(ui_year, "female", "male") # TODO: needs to be language agnostic
    dat[, variable := prettyVariable()[selectCountRate()]]
    
  })
  
  outputCasesD3Bar <- reactive({
    # Restrict data to the user selected vairable, and give pretty column names
    
    count_rate <- prettyVariable()[selectCountRate()]
    keep_cols <- c(ui_sex, prettyAggr_level(), count_rate)
    dat <- subsetYear()[, ..keep_cols]
    dat <- dat[, (count_rate) := lapply(.SD, function(i) {
      # Any NA values need to be converted to 0s to be sent to d3
      i[is.na(i)] <- 0
      i
    }),
    .SDcols = count_rate]
    
    # Order so that males come first - makes sure the coloring matches
    dat[order(-get(ui_sex)), ]
    
  })
  
  
  plot_d3_bar <- reactive({
    if (nrow(outputCasesD3Bar()) > 0  &
        input$aggr_level != "national") {
      sex_vars <- ui_sex_levels
      color = c("#bd6916", "#166abd")
      simpleD3Bar(data = outputCasesD3Bar(),
                  colors = c("#bd6916", "#166abd"),
                  legendData = data.frame(sex = sex_vars,
                                          color =  color))
    }
    
  })
  
  
  plot_d3_line <- reactive({
    if (input$aggr_level == "national") {
      browser()
      sex_vars <- ui_sex_levels
      color = c("#bd6916", "#166abd")
      simpleD3Line(data = outputCasesD3Line(),
                   colors = c("#bd6916", "#166abd"),
                   legendData = data.frame(sex = sex_vars,
                                           color =  color))
    }
  })
  
  
  
  # DATATABLES --------------------------------------------------------------
  outputCountDTTable <- reactive({
    # Organizes data for DataTable outputs. Needs to be characters
    dat <- copy(outputCasesData())
    group_var <- prettyAggr_level()
    dat[, prettyVariable()[2] := NULL]
    
    dat <-  dcast(
      dat,
      get(group_var) ~ get(ui_sex),
      value.var = prettyVariable()[1],
      fun.aggregate = sum
    )
    
    # Calculate margins
    dat[, Total := rowSums(dat[, .(female, male)], na.rm = TRUE)]
    totals <-
      dat[, colSums(dat[, .(female, male, Total)], na.rm = TRUE)]
    
    # Convert entire table to character to we can rbind() totals
    dat <- dat[, lapply(.SD, as.character)]
    # Rbind totals
    dat <- rbindlist(list(dat, as.list(c("Total", totals))))
    
    # Format data columns to either DK or EN settings
    col_names <- colnames(dat)[-1]
    dat[, (col_names) := dat[, lapply(.SD, function(i) {
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
    colnames(dat) <- c(group_var, ui_sex_levels, "Total")
    
    # Flag last row so can be targeted for formatting
    dat[, flag := 0]
    dat[nrow(dat), flag := 1]
    # Make sure "flag" variable is always first column, so we can
    # reference by col index in formatting fn()
    col_names <- colnames(dat)
    col_names <-
      c(col_names[length(col_names)], col_names[-length(col_names)])
    setcolorder(dat, neworder = col_names)
    
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
        buttons = list('csv'),
        initComplete = JS(
          # Table hearder background color
          "function(settings, json) {",
          "$(this.api().table().header()).css({'background-color': '#e7e7e7'});",
          "}"
        )
      )
    ) %>%
      formatStyle('Total',  fontWeight = 'bold') %>%
      formatStyle(group_var,  backgroundColor = "#e7e7e7") %>%
      formatStyle("flag",
                  target = "row",
                  fontWeight = styleEqual(c(0, 1), c("normal", "bold")))
    
  })
  
  outputRateDTTable <- reactive({
    dat <- copy(outputCasesData())
    group_var <- prettyAggr_level()
    dat[, prettyVariable()[1] := NULL]
    
    dat <-  dcast(
      dat,
      get(group_var) ~ get(ui_sex),
      value.var = prettyVariable()[2],
      fun.aggregate = sum
    )
    
    # Format data columns in either DK or EN numbers
    col_names <- colnames(dat)[-1]
    dat[, (col_names) := dat[, lapply(.SD, function(i) {
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
    
    colnames(dat) <- c(group_var, ui_sex_levels)
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
      formatStyle(group_var,  backgroundColor = "#e7e7e7")
  })
  
  # VALIDATE BEFORE PLOTING -------------------------------------------------
  validate <- reactive({
    all(!is.null(input$variable),
        input$outcome != "",
        input$year > 0,
        input$theme != "")
  })
  
  
  # CHANGE UI BASED ON INPUTS -----------------------------------------------
  observe({
    shinyjs::toggle(id = "year", condition = input$theme != "")
    shinyjs::toggle(id = "variable", condition = input$theme != "")
    shinyjs::toggle(id = "aggr_level", condition = input$theme != "")
  })
  
  
  choiceYears <- reactive({
    # User can only select years >=2009 when viewing regional data
    if (input$aggr_level == "region") {
      return(c(2009:2015))
    } else {
      return(c(2006:2015))
    }
    
  })
  observe({
    updateSelectInput(
      session = session,
      inputId = "year",
      choices = choiceYears(),
      selected = 2015
    )
    
  })
  
  observe({
    # Disable "year" when showing longitudinal data
    shinyjs::toggleState(id = "year",
                         condition = input$aggr_level != "national")
    
  })
  
  
  
  
  # RENDER FUNCTIONS --------------------------------------------------------
  
  # PLOT
  output$d3_plot_bar <- renderSimpleD3Bar({
    if (validate() & input$aggr_level != "national") {
      plot_d3_bar()
    }
  })
  
  output$d3_plot_line_html <- renderSimpleD3Line({
    if (validate()) {
      plot_d3_line()
    }
    
  })
  
  
  # DATATABLES:
  # AGE
  output$table <- renderDT({
    if (validate()) {
      outputCountDTTable()
    }
  })
  
  output$table_margins <- renderDT({
    if (validate()) {
      outputRateDTTable()
    }
  })
  
  
})
