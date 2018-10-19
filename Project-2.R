library(leaflet)
library(leaflet.extras)
library(rgdal)
library(httr)
library(readr)
library(shiny)
library(shinydashboard)
library(reshape2)
library(dplyr)
library(plotly)
library(shinythemes)


#For the map I am going to use a geojson map 
kaggle.api <- "https://www.kaggle.com/api/v1/datasets/download/crawford/boston-public-schools/Public_Schools.csv"
kaggle.auth <- function() {
  source("credentials2.R")
  httr::authenticate(username, key)
}
response <- httr::GET(kaggle.api, kaggle.auth())
#data<-writeOGR(Bostonschools,driver="GEOJSON")
Bostonschools<- read_csv(response$content) 
bostonschoolsmap<-readOGR("Public_Schools.geojson")
schooldistrict<-readOGR("Boston_Neighborhoods.shp")

citylist<-unique(bostonschoolsmap$CITY)

schoollist<-unique(bostonschoolsmap$SCH_TYPE)

zipcodelist<-unique(bostonschoolsmap$ZIPCODE)
populationlist<-unique(bostonschoolsmap$PL)
# Define UI for application
ui <- navbarPage("Public Schools in Boston",
                 theme = shinytheme("darkly"),
                 tabPanel("Map",
                          sidebarLayout(
                            sidebarPanel(
                              selectInput("cityselect",
                                          "City",
                                          levels(citylist),
                                          selected = c(""),
                                          selectize = T,
                                          multiple = T),
                              selectInput("schooltypeselect",
                                          "School Type",
                                          levels(schoollist),
                                          selected = c(""),
                                          selectize = T,
                                          multiple = T),
                              selectInput("zipcodeselect",
                                          "Zip Code",
                                          levels(zipcodelist),
                                          selected = c("ES"),
                                          selectize = T,
                                          multiple = T),
                              selectInput("populationselect",
                                          "Population",
                                          levels(populationlist),
                                          selected = c(""),
                                          selectize = T,
                                          multiple = T)
                            ),
                            mainPanel(
                              # Map Output
                              leafletOutput("leaflet")
                              )
                          )
                 ),
                 
                 tabPanel("Schools Plots",
                          fluidRow(
                            column(5, plotlyOutput("Plot1")),
                            column(7, plotlyOutput("Plot2"))
                          )
                 ),
                 tabPanel("Table",
                          fluidPage(
                            wellPanel(DT::dataTableOutput("table"))
                          )
                 )
)

# Define server logic required to draw a histogram
server <- function(input, output) {

  bostonmapsInputs <- reactive({
    bostonschoolsmap <- bostonschoolsmap %>%
      
    if (length(input$populationselect) > 0) {
      bostonschoolsmap <- subset(bostonschoolsmap, PL %in% input$populationselect)
    }
    
    if (length(input$cityselect) > 0) {
      bostonschoolsmap <- subset(bostonschoolsmap, CITY %in% input$citySelect)
    }
    if (length(input$schooltypeselect) > 0) {
      bostonschoolsmap <- subset(bostonschoolsmap, SCH_TYPE %in% input$schooltypeselect)
    }
    if (length(input$zipcodeselect) > 0) {
      bostonschoolsmap <- subset(bostonschoolsmap, ZIPCODE %in% input$zipcodeselect)
    }
    
    return(bostonschoolsmap)
  })
  
  bostonInputs <- reactive({
    Bostonschools <- Bostonschools%>%
    if (length(input$populationselect) > 0) {
      Bostonschools <- subset(Bostonschools, PL %in% input$populationselect)
    }
    
    if (length(input$cityselect) > 0) {
      Bostonschools <- subset(Bostonschools, CITY %in% input$citySelect)
    }
    if (length(input$schooltypeselect) > 0) {
      Bostonschools <- subset(Bostonschools, SCH_TYPE %in% input$schooltypeselect)
    }
    if (length(input$zipcodeselect) > 0) {
      Bostonschools <- subset(Bostonschools, ZIPCODE %in% input$zipcodeselect)
    }
    
    return(Bostonschools)
  })
  
  output$leaflet <- renderLeaflet({
    bostonmaps <- bostonmapsInputs()
    # Build Map
    leaflet()%>%
      addProviderTiles("OpenStreetMap.Mapnik")%>%
      addPolygons(data=schooldistrict,
                  weight=2,
                  color="red")%>%
      addMarkers(data=bostonschoolsmap, popup = ~paste0(SCH_NAME))
      
  })
  #I am goin to create the plots
  #The first pplot is going to show the number of schools per type of school
  output$Plot1 <- renderPlotly({
    Bostonschools<- bostonInputs()
    ggplot(data =  Bostonschools, aes(x =SCH_TYPE)) + 
      geom_histogram(stat="count") + 
      labs(title= "Number of schools per type",
           x= "Number of schools", y= "school type")
  })
  # The second plot is going to show the number of schools 
  output$Plot2 <- renderPlotly({
    Bostonschools<- bostonInputs()
    ggplot(data =  Bostonschools, aes(x =PL)) + 
      geom_histogram(stat="count") + 
      labs(title= "Number of schools per City",
           x= "Number of schools", y= "City")
  })
  
  output$Table <- DT::renderDataTable({
    subset(bostonInputs(), select = c("SCH_TYPE","SCH_NAME","ZIPCODE","ADDRESS","CITY"))
  })
}

# Run the application 
shinyApp(ui = ui, server = server)