SET QUERY_TAGS['data_origin'] = 'open_data_portal';
SET QUERY_TAGS['pipeline'] = 'open_data_portal';


WITH latest_data_status AS (
    SELECT 
        dataset_id,
        status,
        ROW_NUMBER() OVER (
            PARTITION BY dataset_id
            ORDER BY logged_at DESC
        ) AS rn
    FROM IDENTIFIER(:catalog_name || '.' || :meta_schema || '._socrata_ingestion_queue')
    WHERE task_type IN ('DATA', 'DEPRECATED')
      AND status != 'QUEUED'
),
latest_status AS (
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
        'id', m.dataset_id,
        'up', COALESCE(m.portal_metadata_updated_at, '')
    )) AS payload
FROM latest_status m
LEFT JOIN latest_data_status d
    ON m.dataset_id = d.dataset_id
    AND d.rn = 1
WHERE m.rn = 1 
  AND m.status = 'QUEUED'
  AND COALESCE(d.status, '') NOT IN ('EMPTY', 'FAILED', 'DEPRECATED', 'QUARANTINED')
  AND NOT EXISTS (
      SELECT 1
      FROM IDENTIFIER(:catalog_name || '.' || :meta_schema || '._socrata_ingestion_rules') r
      WHERE r.is_active = true
        AND UPPER(TRIM(r.action)) = 'EXCLUDE'
        AND LOWER(TRIM(r.rule_type)) = 'dataset_id'
        AND LOWER(TRIM(r.rule_value)) = LOWER(TRIM(m.dataset_id))
  )
ORDER BY m.logged_at ASC;