# DatabricksSocrataPipeline

A Databricks Asset Bundle (DAB) pipeline designed to discover, ingest, and apply metadata for Socrata datasets into Databricks Delta tables.

---

## Architecture & Workflow

The pipeline runs as a multi-stage workflow defined via Databricks Asset Bundles:

1. **Discovery (`src/socrata_discovery.ipynb`)**  
   Discovers available datasets and metadata from the target Socrata endpoint and registers pending ingestion tasks into work queues.

2. **Ingestion (`src/socrata_ingest_single_table.ipynb`)**  
   Reads task entries using queue extraction logic (`src/read_data_queue.sql`, `src/read_queue.sql`) and ingests table partitions or whole datasets directly into Delta Lake.

3. **Metadata Enrichment (`src/socrata_apply_metadata.ipynb`)**  
   Leverages `src/read_metadata_queue.sql` to apply column tags, descriptions, schema definitions, and table properties fetched from Socrata to the target Unity Catalog tables.

---

## Repository Structure

```text
├── .github/
│   └── workflows/
│       └── deploy.yml            # CI/CD deployment pipeline for Databricks Asset Bundles
├── resources/
│   └── socrata_job.yml           # Databricks job/task orchestration definitions
├── src/
│   ├── read_data_queue.sql       # Query logic to fetch items from data ingestion queue
│   ├── read_metadata_queue.sql   # Query logic to fetch items from metadata queue
│   ├── read_queue.sql            # General queue reading script
│   ├── socrata_apply_metadata.ipynb   # Applies column and table metadata to Delta tables
│   ├── socrata_discovery.ipynb        # Scans Socrata endpoints and enqueues targets
│   └── socrata_ingest_single_table.ipynb # Ingests individual Socrata tables
│   └── check_pipeline_failures.ipynb # Emails for failure
├── databricks.yml                # Databricks Asset Bundle bundle configuration
├── pyproject.toml                # Project packaging and Python dependencies
├── uv.lock                       # Pinned lockfile for dependencies
└── README.md                     # Project documentation