WITH latest_status AS (
    SELECT 
        dataset_id,
        table_name,
        status,
        logged_at,
        ROW_NUMBER() OVER (
            PARTITION BY dataset_id 
            ORDER BY logged_at DESC
        ) AS rn
    FROM IDENTIFIER(:catalog_name || '.' || :meta_schema || '._socrata_ingestion_queue')
)
SELECT 
    dataset_id,
    table_name
FROM latest_status
WHERE rn = 1 
  AND status = 'QUEUED'
  AND table_name IS NOT NULL
ORDER BY logged_at ASC
LIMIT 1000;