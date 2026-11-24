SET statement_tag = 'data_origin=open_data_portal';

WITH latest_status AS (
    SELECT 
        dataset_id,
        status,
        ROW_NUMBER() OVER (PARTITION BY dataset_id ORDER BY logged_at DESC) AS rn
    FROM IDENTIFIER(:catalog_name || '.' || :meta_schema || '._socrata_ingestion_queue')
    WHERE task_type = 'DATA'
      AND status != 'QUEUED'
),
latest_success AS (
    SELECT 
        dataset_id,
        MAX(portal_data_updated_at) AS last_success_updated_at
    FROM IDENTIFIER(:catalog_name || '.' || :meta_schema || '._socrata_ingestion_queue')
    WHERE status = 'SUCCESS'
      AND (task_type = 'DATA' OR task_type IS NULL)
    GROUP BY dataset_id
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
LEFT JOIN latest_status ls 
    ON q.dataset_id = ls.dataset_id 
    AND ls.rn = 1
LEFT JOIN latest_success lsucc
    ON q.dataset_id = lsucc.dataset_id
WHERE 
    q.row_num = 1
    AND COALESCE(ls.status, '') NOT IN ('QUARANTINED', 'DEPRECATED', 'EMPTY')
    AND NOT EXISTS (
        SELECT 1
        FROM IDENTIFIER(:catalog_name || '.' || :meta_schema || '._socrata_ingestion_rules') r
        WHERE r.is_active = true
          AND UPPER(TRIM(r.action)) = 'EXCLUDE'
          AND LOWER(TRIM(r.rule_type)) = 'dataset_id'
          AND LOWER(TRIM(r.rule_value)) = LOWER(TRIM(q.dataset_id))
    )
    AND (
        lsucc.last_success_updated_at IS NULL 
        OR q.portal_data_updated_at > lsucc.last_success_updated_at
        OR ls.status = 'FAILED'
    );