--sql configure information module

M_sql_conf = {}

--host
M_sql_conf.host = "127.0.0.1"
--port
M_sql_conf.port = 5432
--database
M_sql_conf.database="qj_micro_db"
--user
M_sql_conf.user = "qj_box"
--password
M_sql_conf.password = "7Gbox!sz1818#"
--compact
M_sql_conf.compact=false
--timeout
M_sql_conf.timeout = 3000
--connect pool
M_sql_conf.pool = 100

--third sql
M_sql_conf.sql = "postgres"

return M_sql_conf

