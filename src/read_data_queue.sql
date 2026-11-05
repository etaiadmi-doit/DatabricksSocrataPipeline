WITH latest_status AS (
    SELECT 
        dataset_id,
        table_name,
        task_type,
        status,
        portal_data_updated_at,
        portal_metadata_updated_at,
        logged_at,
        ROW_NUMBER() OVER (
            PARTITION BY dataset_id, COALESCE(task_type, 'DATA')
            ORDER BY logged_at DESC
        ) AS rn
    FROM IDENTIFIER(:catalog_name || '.' || :meta_schema || '._socrata_ingestion_queue')
    WHERE COALESCE(task_type, 'DATA') = 'DATA'
)
SELECT 
    dataset_id,
    table_name,
    COALESCE(portal_data_updated_at, '') AS portal_data_updated_at,
    COALESCE(portal_metadata_updated_at, '') AS portal_metadata_updated_at
FROM latest_status
WHERE rn = 1 
  AND status = 'QUEUED'
  AND table_name IS NOT NULL
ORDER BY logged_at ASC
LIMIT 1000;