WITH latest_status AS (
    SELECT 
        dataset_id,
        portal_metadata_updated_at,
        status,
        logged_at,
        ROW_NUMBER() OVER (
            PARTITION BY dataset_id, task_type
            ORDER BY logged_at DESC
        ) AS rn
    FROM IDENTIFIER(:catalog_name || '.' || :meta_schema || '._socrata_ingestion_queue')
    WHERE task_type = 'METADATA'
)
SELECT 
    to_json(named_struct(
        'id', dataset_id,
        'up', COALESCE(portal_metadata_updated_at, '')
    )) AS payload
FROM latest_status
WHERE rn = 1 
  AND status = 'QUEUED'
ORDER BY logged_at ASC;