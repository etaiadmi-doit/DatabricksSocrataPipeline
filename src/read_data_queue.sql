WITH latest_status AS (
    SELECT 
        dataset_id,
        table_name,
        title,
        portal_data_updated_at,
        portal_metadata_updated_at,
        status,
        logged_at,
        ROW_NUMBER() OVER (
            PARTITION BY dataset_id, task_type
            ORDER BY logged_at DESC
        ) AS rn
    FROM IDENTIFIER(:catalog_name || '.' || :meta_schema || '._socrata_ingestion_queue')
    WHERE task_type = 'DATA'
)
SELECT 
    to_json(named_struct(
        'id', dataset_id,
        'tbl', table_name,
        'ttl', title,
        'd_up', COALESCE(portal_data_updated_at, ''),
        'm_up', COALESCE(portal_metadata_updated_at, '')
    )) AS payload
FROM latest_status
WHERE rn = 1 
  AND status = 'QUEUED'
  AND table_name IS NOT NULL
ORDER BY logged_at ASC
LIMIT 1000;