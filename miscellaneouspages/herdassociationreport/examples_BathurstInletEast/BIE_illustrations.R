require(TuktuData)
load("text/nwt_withcoastalareas.rda")
#setwd("./text/examples_BathurstInletEast/")

nwt_withcoastalareas |> head()

(nwt_withcoastalareas |> subset(Area == "BIE"))$Year |> table()


# focus on 2019 & 2021

IDs_2021 <- (nwt_withcoastalareas |> subset(Area == "BIE" & Year == 2021))$OriginalID

require(TuktuData)
data(nwt_raw)


nwt_bie_2021 <- nwt_raw |> subset(OriginalID %in% IDs_2021 & 
                                      Year %in% 2020:2022) |> 
    st_as_sf(coords = c("Lon", "Lat"), crs = 4326) |> 
    plyr::rename(c(OriginalID =  "ID"))

require(mapview)
require(webshot2)

ids <- unique(nwt_bie_2021$ID)
cols <- setNames(RColorBrewer::brewer.pal(max(3, length(ids)), "Set1"), ids)
nwt_bie_2021$color <- cols[as.character(nwt_bie_2021$ID)]


data("nwt_coastal_areas")

require(magick)
plotTracks <- function(sf, savefile = TRUE, 
                       file = "test.png", 
                       title = "test", 
                       dir = "images",
                       bb = st_bbox(nwt_bie_2021), cex = 2){
    lines <- sf |> group_by(ID, color) |>  
        summarize(do_union=FALSE) |> 
        st_cast("LINESTRING") |> mutate(ID = as.character(ID))
    
    points <- sf |> group_by(ID, color) |> slice_tail(n = 1) |> 
        mutate(ID = as.character(ID))
    
    m <- mapview(nwt_coastal_areas, 
                zcol = "Area",
                col.regions = RColorBrewer::brewer.pal(6, "Pastel1"),
                alpha.regions = 0.4,
                color = NA,
                legend = FALSE,
                map.types = "CartoDB.Positron") +  
        mapview(lines, zcol = "ID", 
                 color = unique(lines$color),
                 legend = FALSE) + 
        mapview(points, zcol = "ID", 
                col.regions = unique(points$color),
                legend = FALSE)
    m@map <- m@map |> leaflet::fitBounds(
        lng1 = bb[["xmin"]], lat1 = bb[["ymin"]],
        lng2 = bb[["xmax"]], lat2 = bb[["ymax"]]
    )
    
    if(savefile){
        fout <- paste0(dir, "/", file)
        mapshot2(m@map, file = fout)
        image_read(fout) |>
            image_annotate(title, size = 20*cex, color = "black",
                           boxcolor ="transparent", location = "+10+10") |>
            image_write(fout)
    } else 
        return(m)
}

plotTracks(nwt_bie_2021 |> subset(Year == 2021))

dir = "examples_BathurstInletEast/examples"

m_2020 <- plotTracks(nwt_bie_2021 |> subset(Year == 2020 & lubridate::month(Time) >= 6), 
                     savefile = TRUE, dir = dir, 
                     title = "2020: Jun through Dec",
                     file = "m2020.png")
m_2021_partI <- plotTracks(nwt_bie_2021 |> subset(Year == 2021 & lubridate::month(Time) < 6), 
                           savefile = TRUE, dir = dir, 
                           title = "2021: Jan through May",
                           file = "m2021a.png")
m_2021_partII <- plotTracks(nwt_bie_2021 |> 
                           subset(Year == 2021 & 
                                           lubridate::month(Time) >= 6 & month(Time) < 10),
                           savefile = TRUE, dir = dir, 
                           title = "2021: Jun through Sep",
                           file = "m2021b.png")
m_2021_partIII <- plotTracks(nwt_bie_2021 |> 
                           subset(Year == 2021 & 
                                           lubridate::month(Time) >= 10),
                           savefile = TRUE, dir = dir, 
                           title = "2021: Oct through Dec",
                           file = "m2021c.png")

m_2022 <- plotTracks(nwt_bie_2021 |> 
                                 subset(Year == 2022 & 
                                            lubridate::month(Time) < 6),
                             savefile = TRUE, dir = dir, 
                             title = "2022: Jan through May",
                             file = "m2022.png")

m_2020
m_2021_partI
m_2021_partII
m_2021_partIII

months <- seq(as.Date("2020-06-01"), as.Date("2021-12-01"), by = "month")
#months <- seq(as.Date("2021-07-01"), as.Date("2021-08-01"), by = "month")

for(d in months){
    d <- as.Date(d)
    subset <- nwt_bie_2021 |> filter(Time  >= d, Time  < d %m+% months(1))
    if(nrow(subset) == 0) next
    fname <- format(d, "BIE_%Y%m.png")
    plotTracks(subset, file = fname, title = format(d, "%B %Y"))
}


img <- image_read("images/test.png")
image_info(img)[, c("width", "height")]
{
png("examples_BathurstInletEast/examples/legend.png", width = 1000, height = 700, res = 150)
par(mar = c(0,0,0,0), xpd = NA)
plot.new()
legend("center", pch = 15, pt.cex = 3, 
       col = cols, legend = names(cols), bty = "n", cex = 2,
       ncol = 1)
mtext(side = 3, line = -2, cex = 3, "Animal ID")
dev.off()
}
# collect all images together

files <- list.files("images", full.names = TRUE)
imgs <- lapply(files, image_read)

# arrange into rows of 4
rows <- lapply(split(imgs, ceiling(seq_along(imgs)/4)), function(row){
    image_append(do.call(c, row), stack = FALSE)
})

final <- image_append(do.call(c, rows), stack = TRUE) |>
    image_border("white", "10x10")

image_write(final, "BIE_all.png")
