#!/bin/bash

psql "host=127.0.0.1 port=5432 user=qj_box password=123456 dbname=qj_micro_db" -f ./7g_box_table.sql
