# ============================================
# 1. Library installation
# ============================================
install.packages("factoextra")
install.packages("cluster")
install.packages("fpc")
install.packages("mclust")
install.packages("dplyr")
install.packages("ggplot2")
install.packages("forecast")

library(factoextra)
library(cluster)
library(fpc)
library(mclust)
library(dplyr)
library(ggplot2)
library(forecast)

# ============================================
# 2. Read and sampling data
# ============================================
uber <- read.csv("homework 1/data/uber-data.csv")

str(uber)
summary(uber)

# Select 30,000 trips for analysis
set.seed(42)
sample_idx <- sample(nrow(uber), 30000)

uber_sample <- uber[sample_idx, ]

# Coordinates used for clustering
coords <- uber_sample[, c("Lon", "Lat")]

# Approximate conversion from degrees to km
lat0 <- mean(coords$Lat) * pi / 180

coords_km <- data.frame(
  x = (coords$Lon - mean(coords$Lon)) *
    111.32 * cos(lat0),
  y = (coords$Lat - mean(coords$Lat)) *
    111.32
)

# Geographical scatter plot
plot(
  coords$Lon, coords$Lat,
  pch = 16,
  cex = 0.3,
  col = rgb(0, 0, 1, 0.2),
  xlab = "Longitude",
  ylab = "Latitude",
  main = "Uber Trip Locations"
)

# ============================================
# 3. Hopkins Statistic
# ============================================

hop <- get_clust_tendency(
  coords_km,
  n = 300,
  graph = FALSE,
  seed = 42
)

hop$hopkins_stat

# ============================================
# 4 Optimal k(clusters) using K-means,Calinski-Harabasz and Gap statistics
# ============================================

# ============================================
# 4.1 Silhouette and Calinski-Harabasz
# ============================================
set.seed(42)
sil_idx <- sample(nrow(coords_km), 2000)
sil_dist <- dist(coords_km[sil_idx, ])

results <- data.frame(
  k = 2:15,
  km_sil = NA_real_, km_ch = NA_real_,
  clara_sil = NA_real_, clara_ch = NA_real_
)

set.seed(42)

for (i in seq_along(results$k)) {
  
  k <- results$k[i]
  
  km <- kmeans(coords_km, centers = k, nstart = 25)
  
  cl <- clara(coords_km, k = k,
              samples = 20, sampsize = 1000,
              rngR = TRUE)
  
  results[i, 2:5] <- c(
    mean(silhouette(km$cluster[sil_idx], sil_dist)[, "sil_width"]),
    calinhara(coords_km, km$cluster),
    mean(silhouette(cl$clustering[sil_idx], sil_dist)[, "sil_width"]),
    calinhara(coords_km, cl$clustering)
  )
}

round(results, 3)

# ============================================
# 4.2 Graphical comparison
# ============================================
par(mfrow = c(1, 2))

matplot(results$k, results[, c("km_sil", "clara_sil")],
        type = "b", pch = c(16, 17), lty = 1,
        col = c("blue", "red"),
        xlab = "Number of clusters (k)",
        ylab = "Average Silhouette",
        main = "Silhouette Comparison")

legend("topright", c("K-Means", "CLARA"),
       col = c("blue", "red"), pch = c(16, 17), lty = 1)

matplot(results$k, results[, c("km_ch", "clara_ch")],
        type = "b", pch = c(16, 17), lty = 1,
        col = c("blue", "red"),
        xlab = "Number of clusters (k)",
        ylab = "CH Index",
        main = "Calinski-Harabasz Comparison")

legend("topleft", c("K-Means", "CLARA"),
       col = c("blue", "red"), pch = c(16, 17), lty = 1)

par(mfrow = c(1, 1))

# ============================================
# 4.3 Gap Statistic
# ============================================
set.seed(42)
coords_gap <- coords_km[sample(nrow(coords_km), 3000), ]

set.seed(42)
fviz_nbclust(coords_gap, kmeans,
             method = "gap_stat",
             k.max = 15, nboot = 50,
             nstart = 25)

set.seed(42)
fviz_nbclust(
  coords_gap,
  cluster::clara,
  method = "gap_stat",
  k.max = 15,
  nboot = 10,
  samples = 5,
  sampsize = 300,
  rngR = TRUE
)
# ============================================
# 5. Evaluation of K-means and CLARA
# ============================================
k_final <- 3

# k-means evaluation
set.seed(42)
km_final <- kmeans(
  coords_km,
  centers = k_final,
  nstart = 25
)

# clara evaluation
set.seed(42)
clara_final <- clara(
  coords_km,
  k = k_final,
  samples = 20,
  sampsize = 1000,
  rngR = TRUE
)

# size of clusters that we done
table(km_final$cluster)
table(clara_final$clustering)

# how many percentage clusters took from overall sample
round(prop.table(table(km_final$cluster)) * 100, 2)
round(prop.table(table(clara_final$clustering)) * 100, 2)

# check centroids and medoids
round(km_final$centers, 2)
round(clara_final$medoids, 2)

# k-mean plot
plot(coords_km, col = km_final$cluster,
     pch = 15, cex = 0.3,
     main = "K-Means - 3 Clusters",
     xlab = "X (km)", ylab = "Y (km)")

points(km_final$centers, pch = 1,
       cex = 1, lwd = 2, col = "orange")

# CLARA plot
plot(coords_km, col = clara_final$clustering,
     pch = 15, cex = 0.3,
     main = "CLARA - 3 Clusters",
     xlab = "X (km)", ylab = "Y (km)")

points(clara_final$medoids, pch = 8,
       cex = 1, lwd = 2, col = "orange")

# cluster assignments for later analysis
uber_sample$km_cluster <- km_final$cluster
uber_sample$clara_cluster <- clara_final$clustering

# ============================================
# 6. Comparing both solution using Adjusted Rand Index
# ============================================
ari <- adjustedRandIndex(
  km_final$cluster,
  clara_final$clustering
)

round(ari, 3)

# ============================================
# 7. Analyse clusters by time
# ============================================
# timestamps to New York time
uber_sample$datetime <- as.POSIXct(
  uber_sample$Date.Time,
  format = "%m/%d/%Y %H:%M:%S",
  tz = "America/New_York"
)

# take hours from date
uber_sample$hour <- as.integer(
  format(uber_sample$datetime, "%H")
)

# hourly activity and geographical center
hourly_centers <- uber_sample %>%
  group_by(km_cluster, hour) %>%
  summarise(
    trips = n(),
    center_lon = mean(Lon),
    center_lat = mean(Lat),
    .groups = "drop"
  )

# hourly trip activity visualisation graph
ggplot(hourly_centers,
       aes(x = hour, y = trips,
           color = factor(km_cluster))) +
  geom_line(linewidth = 1) +
  geom_point(size = 1.5) +
  scale_x_continuous(breaks = seq(0, 23, 2)) +
  labs(
    title = "Hourly Uber Trips by K-Means Cluster",
    x = "Hour of Day",
    y = "Number of Trips",
    color = "Cluster"
  ) +
  theme_minimal()
# hourly geographic centers graph
ggplot(hourly_centers,
       aes(x = center_lon, y = center_lat)) +
  geom_point(
    aes(color = hour, size = trips),
    alpha = 0.8
  ) +
  facet_wrap(~ km_cluster, scales = "free") +
  scale_color_viridis_c() +
  scale_size(range = c(2, 7)) +
  labs(
    title = "Hourly Geographic Centers by Cluster",
    x = "Longitude",
    y = "Latitude",
    color = "Hour",
    size = "Trips"
  ) +
  theme_minimal()

# ============================================
# 8. Cluster analysis by date
# ============================================
# date by new york time
uber_sample$date <- as.Date(
  uber_sample$datetime,
  tz = "America/New_York"
)

# date range
range(uber_sample$date)

# calculate daily trip counts and geographical centers
daily_centers <- uber_sample %>%
  group_by(km_cluster, date) %>%
  summarise(
    trips = n(),
    center_lon = mean(Lon),
    center_lat = mean(Lat),
    .groups = "drop"
  )

ggplot(daily_centers,
       aes(x = date, y = trips,
           color = factor(km_cluster))) +
  geom_line(linewidth = 1) +
  geom_point(size = 1.5) +
  scale_x_date(date_breaks = "3 days",
               date_labels = "%d %b") +
  labs(
    title = "Daily Uber Trips by K-Means Cluster",
    x = "Date",
    y = "Number of Trips",
    color = "Cluster"
  ) +
  theme_minimal()

ggplot(daily_centers,
       aes(x = center_lon, y = center_lat)) +
  geom_point(
    aes(color = date, size = trips),
    alpha = 0.8
  ) +
  facet_wrap(~ km_cluster, scales = "free") +
  labs(
    title = "Daily Geographic Centers by Cluster",
    x = "Longitude",
    y = "Latitude",
    color = "Date",
    size = "Trips"
  ) +
  theme_minimal()
# ============================================
# 9. Forecasting
# ============================================

# ============================================
# 9.1 Prepare daily data
# ============================================

# 2014 september dates
dates <- seq(
  as.Date("2014-09-01"),
  as.Date("2014-09-30"),
  by = "day"
)

# daily trip counts for each K-Means cluster
daily_counts <- table(
  factor(uber_sample$date, levels = dates),
  factor(uber_sample$km_cluster, levels = 1:3)
)


# descriptive statistics
cluster_summary <- data.frame(
  Cluster = 1:3,
  Mean_Daily = round(colMeans(daily_counts), 2),
  SD_Daily = round(apply(daily_counts, 2, sd), 2),
  Min_Daily = apply(daily_counts, 2, min),
  Max_Daily = apply(daily_counts, 2, max),
  CV = round(
    100 * apply(daily_counts, 2, sd) /
      colMeans(daily_counts),
    2
  )
)

print(cluster_summary)
# ============================================
# 9.2 Train and compare forecasting models
# ============================================
# function for mean abs error
mae <- function(actual, predicted) {
  mean(abs(actual - as.numeric(predicted)))
}

# prepare storage for result
results_mae <- data.frame(
  Cluster = 1:3,
  Naive = NA_real_,
  Seasonal_Naive = NA_real_,
  ETS = NA_real_,
  ARIMA = NA_real_
)

trains <- vector("list", 3)
fits <- vector("list", 3)
predictions <- vector("list", 3)

for (cl in 1:3) {
  
  # daily trip counts
  trips <- as.numeric(daily_counts[, cl])
  
  # training September 1-23 (23 days)
  train <- ts(trips[1:23], frequency = 7)
  
  # testing September 24-30 (7 days)
  test <- trips[24:30]
  
  # naive forecasting
  f_naive <- naive(train, h = 7)
  
  # seasonal naive forecasting
  f_snaive <- snaive(train, h = 7)
  
  # exponential smoothing
  fit_ets <- forecast::ets(train)
  f_ets <- forecast::forecast(fit_ets, h = 7)
  
  # ARIMA forecasting
  fit_arima <- forecast::auto.arima(train, seasonal = TRUE)
  f_arima <- forecast::forecast(fit_arima, h = 7)
  
  # Calculate MAE for all four methods
  results_mae[cl, 2:5] <- c(
    mae(test, f_naive$mean),
    mae(test, f_snaive$mean),
    mae(test, f_ets$mean),
    mae(test, f_arima$mean)
  )
  
  # save training data
  trains[[cl]] <- train
  
  # save fitted models
  fits[[cl]] <- list(
    Naive = f_naive,
    Seasonal_Naive = f_snaive,
    ETS = fit_ets,
    ARIMA = fit_arima
  )
  
  # save actual values and forecasts
  predictions[[cl]] <- data.frame(
    Date = dates[24:30],
    Actual = test,
    Naive = as.numeric(f_naive$mean),
    Seasonal_Naive = as.numeric(f_snaive$mean),
    ETS = as.numeric(f_ets$mean),
    ARIMA = as.numeric(f_arima$mean)
  )
}

# compare forecasting accuracy
print(round(results_mae, 2))
# ============================================
# 9.3 Visualize the best forecasts
# ============================================
# best model selected based on MAE results
best_models <- c(
  "Seasonal_Naive",
  "Seasonal_Naive",
  "ETS"
)

for (cl in 1:3) {
  
  p <- predictions[[cl]]
  model <- best_models[cl]
  
  # actual observation
  plot(
    p$Date, p$Actual,
    type = "b",
    pch = 16,
    col = "black",
    ylim = range(c(p$Actual, p[[model]])),
    xlab = "Date",
    ylab = "Number of Trips",
    main = paste("Cluster", cl, "- Actual vs Forecast")
  )
  
  # predicted observation
  lines(
    p$Date, p[[model]],
    type = "b",
    pch = 17,
    col = "blue"
  )
  
  legend(
    "topleft",
    legend = c("Actual", model),
    col = c("black", "blue"),
    pch = c(16, 17),
    lty = 1
  )
}
# ============================================
# 9.4 ACF and PACF analysis
# ============================================
for (cl in 1:3) {
  
  par(mfrow = c(1, 2))
  
  # autocorrelation function
  acf(
    trains[[cl]],
    main = paste("ACF - Cluster", cl)
  )
  
  # partial autocorrelation function
  pacf(
    trains[[cl]],
    main = paste("PACF - Cluster", cl)
  )
}

par(mfrow = c(1, 1))
# ============================================
# 9.5 Inspect selected forecasting models
# ============================================
# ARIMA models selected automatically
for (cl in 1:3) {
  
  cat("\nCluster", cl, "- ARIMA model\n")
  print(fits[[cl]]$ARIMA)
}

# ETS model for Cluster 3
summary(fits[[3]]$ETS)

# ============================================
# 9.6 Residual diagnostics
# ============================================
# check residuals of the selected models
for (cl in 1:3) {
  
  model <- fits[[cl]][[best_models[cl]]]
  
  cat("\nResidual diagnostics - Cluster", cl, "\n")
  
  checkresiduals(model)
}

# Ljung-Box tests using 8 lags
for (cl in 1:3) {
  
  model <- fits[[cl]][[best_models[cl]]]
  errors <- na.omit(residuals(model))
  
  lb_test <- Box.test(
    errors,
    lag = 8,
    type = "Ljung-Box",
    fitdf = 0
  )
  
  cat(
    "Cluster", cl,
    "- Ljung-Box p-value:",
    round(lb_test$p.value, 4), "\n"
  )
}
