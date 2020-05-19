shinyServer(function(input, output, session) {
  source("global.R")
  # session$onSessionEnded(stopApp)
  source(file.path("server", "server_main.R"), local = TRUE)$value
  # source(file.path("server", "about_server.R"), local = TRUE)$value
  
})