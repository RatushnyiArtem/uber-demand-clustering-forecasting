# Dataset setup

This project uses the September 2014 Uber pickup records from FiveThirtyEight's public dataset:

https://github.com/fivethirtyeight/uber-tlc-foil-response/tree/master/uber-trip-data

Download `uber-raw-data-sep14.csv` (1,028,136 rows) and save it as:

```text
data/uber-data.csv
```

Alternatively, from the repository root:

```bash
curl -L "https://raw.githubusercontent.com/fivethirtyeight/uber-tlc-foil-response/master/uber-trip-data/uber-raw-data-sep14.csv" -o data/uber-data.csv
```

The original CSV contains `Date/Time`, `Lat`, `Lon`, and `Base` columns. When loaded using R's default `read.csv()`, `Date/Time` becomes `Date.Time`, as expected by the analysis.

The raw dataset is intentionally excluded from version control to avoid redistributing a large external file. Please consult the source repository for its provenance and usage terms.
