library(shiny)
library(bslib)
library(ggplot2)
library(dplyr)

ui <- page_fillable(
  theme = bs_theme(
    version = 5,
    bootswatch = "litera",
    base_font = "system-ui",
    heading_font = "system-ui"
  ),

  layout_sidebar(
    sidebar = sidebar(
      width = 340,
      h3("🧪 Mini Lab: Simulate + Explore"),
      sliderInput("n", "Sample size", min = 50, max = 2000, value = 400, step = 50),
      sliderInput("noise", "Noise", min = 0, max = 5, value = 1, step = 0.1),
      sliderInput("slope", "Slope", min = -5, max = 5, value = 1.2, step = 0.1),
      selectInput("shape", "Relationship", choices = c("Linear", "Quadratic", "Sine")),
      actionButton("regen", "🔄 Regenerate", class = "btn-primary w-100")
    ),

    card(
      full_screen = TRUE,
      card_header("📈 Scatter + Model"),
      plotOutput("plot", height = 650)
    )
  )
)

server <- function(input, output, session) {
  seed <- reactiveVal(1)
  observeEvent(input$regen, seed(sample.int(1e9, 1)), ignoreInit = TRUE)

  dat <- reactive({
    set.seed(seed())
    x <- rnorm(input$n)
    eps <- rnorm(input$n, sd = input$noise)
    y <- switch(
      input$shape,
      "Linear"    = input$slope * x + eps,
      "Quadratic" = input$slope * (x^2 - mean(x^2)) + eps,
      "Sine"      = input$slope * sin(2 * x) + eps
    )
    tibble(x = x, y = y)
  })

  output$plot <- renderPlot({
    df <- dat()
    ggplot(df, aes(x, y)) +
      geom_point(size = 2.6, alpha = 0.75) +
      geom_smooth(method = "lm", se = FALSE, linewidth = 1) +
      theme_minimal(base_size = 15)
  })
}

shinyApp(ui, server)
