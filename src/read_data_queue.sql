WITH latest_prior_execution AS (
    SELECT 
        dataset_id,
        status,
        portal_data_updated_at,
        ROW_NUMBER() OVER (PARTITION BY dataset_id, task_type ORDER BY logged_at DESC) AS row_num
    FROM IDENTIFIER(:catalog_name || '.' || :meta_schema || '._socrata_ingestion_queue')
    WHERE task_type = 'DATA'
      AND status != 'QUEUED'  -- Crucial: Ignore the newly inserted queue record
),
discovered_tasks AS (
    SELECT 
        dataset_id,
        portal_data_updated_at,
        ROW_NUMBER() OVER (PARTITION BY dataset_id ORDER BY logged_at DESC) AS row_num
    FROM IDENTIFIER(:catalog_name || '.' || :meta_schema || '._socrata_ingestion_queue')
    WHERE status = 'QUEUED'
      AND task_type = 'DATA'
)
SELECT 
    to_json(named_struct(
        'id', q.dataset_id,
        'up', CAST(q.portal_data_updated_at AS STRING)
    )) AS payload
FROM discovered_tasks q
LEFT JOIN latest_prior_execution ls 
    ON q.dataset_id = ls.dataset_id 
    AND ls.row_num = 1
WHERE 
    q.row_num = 1  -- Only evaluate the most recently queued task per dataset
    -- 1. Exclude quarantined datasets
    AND COALESCE(ls.status, '') != 'QUARANTINED'
    -- 2. Exclude deprecated or empty datasets
    AND COALESCE(ls.status, '') NOT IN ('DEPRECATED', 'EMPTY')
    -- 3. Only ingest if never successfully run, or if the new queue timestamp is newer
    AND (
        ls.portal_data_updated_at IS NULL 
        OR q.portal_data_updated_at > ls.portal_data_updated_at
        OR ls.status = 'FAILED'  -- Retries prior failures if not quarantined
    );