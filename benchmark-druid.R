#! /usr/bin/env Rscript

if(!require("RDruid")) {
  cat(paste("Benchmark requires the RDruid package, please install using:",
            "install.packages(\"devtools\")",
            "devtools::install_github(\"RDruid\", \"druid-io\")\n", sep="\n"))
}

args <- commandArgs(TRUE)
if(length(args) < 1) {
  cat("Usage: benchmark-druid.R <broker/compute> [datasource] [outputname] [count]\n")
  quit(status=2)
}

suppressMessages(library(RDruid))
suppressMessages(library(microbenchmark))

# benchmark nodes (compute node for 1GB, broker for 100GB data set)
host <- args[1]
url <- druid.url(host)

datasource <- "tpch_lineitem"
engine <- "druid-benchmark.tsv"
n <- 100

if(!is.na(args[2])) datasource <- args[2]
if(!is.na(args[3])) engine <- args[3]
if(!is.na(args[4])) n <- as.numeric(args[4])

cat(sprintf("Running benchmarks against [%s] on [%s], running each query [%d] times.\n", datasource, host, n))

i <- interval(fromISO("1992-01-01T00:00:00"), fromISO("1999-01-01T00:00:00"))

count_star_interval <- function(datasource) {
  druid.query.timeseries(
    url = url,
    dataSource   = datasource,
    intervals    = interval(ymd(19920103),ymd(19981130)),
    aggregations = list(druid.count()),
    granularity = granularity("all"),
    context=list(useCache=F, populateCache=F),
    verbose = TRUE,
    benchmark = TRUE
  )
}

sum_price <- function(datasource) {
  druid.query.timeseries(
    url = url,
    dataSource   = datasource,
    intervals    = i,
    aggregations = list(
      sum(metric("l_extendedprice"))
    ),
    granularity = granularity("all"),
    context=list(useCache=F, populateCache=F),
    verbose = TRUE,
    benchmark = TRUE
  )
}

sum_all <- function(datasource) {
  druid.query.timeseries(
    url = url,
    dataSource   = datasource,
    intervals    = i,
    aggregations = list(
      sum(metric("l_extendedprice")),
      sum(metric("l_discount")),
      sum(metric("l_quantity")),
      sum(metric("l_tax"))
    ),
    filter = NULL,
    granularity = granularity("all"),
    context=list(useCache=F, populateCache=F),
    verbose = TRUE,
    benchmark = TRUE
  )
}

sum_all_year <- function(datasource) {
  druid.query.timeseries(
    url = url,
    dataSource   = datasource,
    intervals    = i,
    aggregations = list(
      sum(metric("l_extendedprice")),
      sum(metric("l_discount")),
      sum(metric("l_quantity")),
      sum(metric("l_tax"))
    ),
    filter = NULL,
    granularity = granularity("P1Y"),
    context=list(useCache=F, populateCache=F),
    verbose = TRUE,
    benchmark = TRUE
  )
}


sum_all_filter <- function(datasource) {
  druid.query.timeseries(
    url = url,
    dataSource   = datasource,
    intervals    = i,
    aggregations = list(
      sum(metric("l_extendedprice")),
      sum(metric("l_discount")),
      sum(metric("l_quantity")),
      sum(metric("l_tax"))
    ),
    filter = dimension("l_shipmode") %~% ".*AIR.*",
    granularity = granularity("all"),
    context=list(useCache=F, populateCache=F),
    verbose = TRUE,
    benchmark = TRUE
  )
}

top_100_parts <- function(datasource) {
  druid.query.topN(
    url = url,
    dataSource   = datasource,
    intervals    = i,
    metric = "l_quantity",
    dimension = "l_partkey",
    n=100,
    aggregations = list(
      sum(metric("l_quantity"))
    ),
    filter = NULL,
    granularity = granularity("all"),
    context=list(useCache=F, populateCache=F),
    verbose = TRUE,
    benchmark = TRUE
  )
}

top_100_parts_details <- function(datasource) {
  druid.query.topN(
    url = url,
    dataSource   = datasource,
    intervals    = i,
    metric = "l_quantity",
    dimension = "l_partkey",
    n=100,
    aggregations = list(
      sum(metric("l_quantity")),
      sum(metric("l_extendedprice"))
    ),
    filter = NULL,
    granularity = granularity("all"),
    context=list(useCache=F, populateCache=F),
    verbose = TRUE,
    benchmark = TRUE
  )
}


top_100_parts_filter <- function(datasource) {
  druid.query.topN(
    url = url,
    dataSource   = datasource,
    intervals    = interval(ymd(19960115), ymd(19980315)),
    metric = "l_quantity",
    dimension = "l_partkey",
    n=100,
    aggregations = list(
      sum(metric("l_quantity")),
      sum(metric("l_extendedprice"))
    ),
    granularity = granularity("all"),
      context=list(useCache=F, populateCache=F),
      verbose = TRUE,
      benchmark = TRUE
  )
}

top_100_commitdate <- function(datasource) {
  druid.query.topN(
    url = url,
    dataSource   = datasource,
    intervals    = i,
    metric = "l_quantity",
    dimension = "l_commitdate",
    n=100,
    aggregations = list(
      sum(metric("l_quantity"))
    ),
    filter = NULL,
    granularity = granularity("all"),
    context=list(useCache=F, populateCache=F, minTopNThreshold=3500),
    verbose = TRUE,
    benchmark = TRUE
  )
}

group_by_shipmode <- function(datasource) {
  druid.query.groupBy(
    url = url,
    dataSource   = datasource,
    intervals    = interval(ymd(19960115), ymd(19980315)),
    metric = "l_quantity",
    dimension = "l_shipmode",
    aggregations = list(
      sum(metric("l_quantity")),
      sum(metric("l_extendedprice"))
    ),
    granularity = granularity("all"),
      context=list(useCache=F, populateCache=F),
      verbose = TRUE,
      benchmark = TRUE
  )
}

group_by_shipmode_v2 <- function(datasource) {
  druid.query.groupBy(
    url = url,
    dataSource   = datasource,
    intervals    = interval(ymd(19960115), ymd(19980315)),
    metric = "l_quantity",
    dimension = "l_shipmode",
    aggregations = list(
      sum(metric("l_quantity")),
      sum(metric("l_extendedprice"))
    ),
    granularity = granularity("all"),
      context=list(useCache=F, populateCache=F, groupByStrategy = 'v2'),
      verbose = TRUE,
      benchmark = TRUE
  )
}

res1 <- microbenchmark(count_star_interval(datasource), times=n)
res2 <- microbenchmark(sum_price(datasource), times=n)
res3 <- microbenchmark(sum_all(datasource), times=n)
res4 <- microbenchmark(sum_all_year(datasource), times=n)
res5 <- microbenchmark(sum_all_filter(datasource), times=n)
res6 <- microbenchmark(top_100_parts(datasource), times=n)
res7 <- microbenchmark(top_100_parts_details(datasource), times=n)
res8 <- microbenchmark(top_100_parts_filter(datasource), times=n)
res9 <- microbenchmark(top_100_commitdate(datasource), times=n)
# res10 <- microbenchmark(group_by_shipmode(datasource), times=n)
# res11 <- microbenchmark(group_by_shipmode_v2(datasource), times=n)

# results <- as.data.frame(rbind(res1, res2, res3, res4, res5, res6, res7, res8, res9, res10, res11))
results <- as.data.frame(rbind(res1, res2, res3, res4, res5, res6, res7, res8, res9))
results$time <- results$time / 1e9
results$query <- as.character(sub("\\(.*\\)", replacement="", results$expr))
druid <- results[c("query", "time")]

filename <- paste(engine, ".tsv", sep="")
cat(sprintf("Writing results to %s.\n", filename))
write.table(druid, filename, quote=F, sep="\t", col.names=F, row.names=F)
