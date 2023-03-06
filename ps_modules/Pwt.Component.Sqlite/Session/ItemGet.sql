SELECT
    "data"
FROM
    "Session"
WHERE
    "sessionId" = '{0}'
    AND "expiry" > datetime('now')