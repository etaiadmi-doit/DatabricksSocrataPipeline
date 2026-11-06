WITH latest_status AS (
    SELECT 
        dataset_id,
        table_name,
        task_type,
        status,
        portal_metadata_updated_at,
        logged_at,
        ROW_NUMBER() OVER (
            PARTITION BY dataset_id, task_type
            ORDER BY logged_at DESC
        ) AS rn
    FROM IDENTIFIER(:catalog_name || '.' || :meta_schema || '._socrata_ingestion_queue')
    WHERE task_type = 'METADATA'
)
SELECT 
    dataset_id,
    table_name,
    COALESCE(portal_metadata_updated_at, '') AS portal_metadata_updated_at
FROM latest_status
WHERE rn = 1 
  AND status = 'QUEUED'
  AND table_name IS NOT NULL
ORDER BY logged_at ASC
LIMIT 100;