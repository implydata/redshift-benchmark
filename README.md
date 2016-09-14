# Druid / Redshift Benchmarking

## Results

![Results](/results/Rplots.png)

## Methodology

### Redshift Setup

#### Launch a new Redshift cluster with:
* **Node type:** dc1.8xlarge (32 vCPU, 244 GB, 2.56TB SSD)
* **Number of compute nodes:** 2
* **Encrypt database:** none

#### Create table
```
CREATE TABLE lineitem(
L_OrderKey integer not null,
L_PartKey integer not null,
L_SuppKey integer not null,
L_LineNumber integer not null,
L_Quantity integer not null,
L_ExtendedPrice float not null,
L_Discount float not null,
L_Tax float not null,
L_ReturnFlag char(1) not null,
L_LineStatus char(1) not null,
L_ShipDate date not null sortkey,
L_CommitDate date not null,
L_ReceiptDate date not null,
L_ShipInstruct char(25) not null,
L_ShipMode char(10) not null,
L_Comment varchar(44) not null
);
```

#### Load data from manifest file
```
copy lineitem from 's3://path/to/redshift-tpch100.manifest' credentials '...' delimiter '|' gzip manifest;
```

#### Verify load
* Check all rows were loaded (600037902):
```
select count(*) from lineitem;
```
* Check that appropriate compression was applied to the columns:
```
select "column", type, encoding from pg_table_def where tablename = 'lineitem';
```
* Check for even slice distribution:
```
select trim(name) as table, slice, sum(num_values) as rows, min(minvalue), max(maxvalue) from svv_diskusage where name = 'lineitem' and col =0 group by name, slice order by name, slice;
```

### Druid Setup

#### Launch a new Imply cluster with:
* **Data node type:** 2 x i2.8xlarge (32 vCPU, 244 GB, 6.4TB SSD - chosen to be comparable to dc1.8xlarge, the disk is not fully utilized)
* **Broker node type:** r3.8xlarge (32 vCPU, 244 GB, 640GB SSD)
* **Master node type:** m4.xlarge (4 vCPU, 16 GB - not involved in query path)

#### Load data using batch ingestion
```
curl -XPOST -H'Content-Type:application/json' -d @tpch-batch.json http://{OVERLORD_IP}:8090/druid/indexer/v1/task
```
#### Set datasource to single replication
Using the coordinator console (`http://{COORDINATOR_IP}:8081`) set the `replicant` value for `tpch_lineitem` to **1**
#### Verify load
* Check all rows were loaded (600037902):

POST the following query to `http://{BROKER_IP}:8082/druid/v2/?pretty`
```
{
  "queryType": "timeseries", 
  "dataSource": "tpch_lineitem", 
  "intervals": [ "1990/2000" ], 
  "granularity": "all", 
  "aggregations": [{"type": "longSum", "fieldName": "count", "name": "count"}]
}
```

## Redshift Queries

*Execute the following queries using your favorite SQL client. You'll need to download the appropriate Redshift JDBC driver from here: http://docs.aws.amazon.com/redshift/latest/mgmt/configure-jdbc-connection.html*

*When running the queries, exclude the first execution of each query from the result set as it includes the time required to compile the query.*

count_star_interval
```
SELECT COUNT(*) FROM LINEITEM WHERE L_SHIPDATE BETWEEN '1992-01-03' AND '1998-11-30';
```
sum_price
```
SELECT SUM(L_EXTENDEDPRICE) FROM LINEITEM;
```
sum_all
```
SELECT SUM(L_EXTENDEDPRICE),SUM(L_DISCOUNT),SUM(L_TAX),SUM(L_QUANTITY) FROM LINEITEM;
```
sum_all_year
```
SELECT YEAR(L_SHIPDATE), SUM(L_EXTENDEDPRICE),SUM(L_DISCOUNT),SUM(L_TAX),SUM(L_QUANTITY) FROM LINEITEM GROUP BY YEAR(L_SHIPDATE);
```
sum_all_filter
```
SELECT SUM(L_EXTENDEDPRICE),SUM(L_DISCOUNT),SUM(L_TAX),SUM(L_QUANTITY) FROM LINEITEM WHERE L_SHIPMODE LIKE '%AIR%';
```
top_100_parts
```
SELECT L_PARTKEY, SUM(L_QUANTITY) FROM LINEITEM GROUP BY L_PARTKEY ORDER BY SUM(L_QUANTITY) DESC LIMIT 100;
```
top_100_parts_details
```
SELECT L_PARTKEY, SUM(L_QUANTITY), SUM(L_EXTENDEDPRICE), MIN(L_DISCOUNT), MAX(L_DISCOUNT) FROM LINEITEM GROUP BY L_PARTKEY ORDER BY SUM(L_QUANTITY) DESC LIMIT 100;
```
top_100_parts_filter
```
SELECT L_PARTKEY, SUM(L_QUANTITY), SUM(L_EXTENDEDPRICE), MIN(L_DISCOUNT), MAX(L_DISCOUNT) FROM LINEITEM WHERE L_SHIPDATE BETWEEN '1996-01-15' AND '1998-03-15' GROUP BY L_PARTKEY ORDER BY SUM(L_QUANTITY) DESC LIMIT 100;
```
top_100_commitdate
```
SELECT L_COMMITDATE, SUM(L_QUANTITY) FROM LINEITEM GROUP BY L_COMMITDATE ORDER BY SUM(L_QUANTITY) DESC LIMIT 100;
```

## Druid Queries

The `benchmark-druid.R` script can be used to execute queries against Druid. To install/configure R on OSX:
* Install R: http://cran.ms.unimelb.edu.au/bin/macosx/
* Install dependencies:
```
$ R
> options(repos='http://cran.rstudio.com/')
> options(download.file.method = "wget")
> install.packages(c('devtools', 'microbenchmark'))
> library("devtools")
> install_github("druid-io/RDruid")
```

To run the benchmark script:
```
Rscript ./benchmark-druid.R {BROKER_IP} tpch_lineitem results/tpch_lineitem_druid {iterations}
```