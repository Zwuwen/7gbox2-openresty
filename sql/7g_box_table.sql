create user qj_box with password '7Gbox@sz1818#';
create database qj_micro_db owner qj_box;
grant all on database qj_micro_db to qj_box;
\c qj_micro_db qj_box;

create table micro_svr_tbl (
	dev_type text primary key not null,
	dev_type_ex text,
	url_prefix text not null,
	online int not null
);

create table dev_status_tbl (
	dev_id int not null primary key,
	online int not null,
	attribute text,
	last_online_time timestamp(0),
	auto_mode int not null default(0),
	linkage_rule int not null default(0)
);

create table dev_info_tbl (
	dev_id serial primary key not null,
	dev_type text not null,
	interface_type text not null,
	manufacturer_id int not null,
	sn text,
	ability_method text,
	ability_attribute text
);

create table config_ip_tbl (
	dev_id int not null primary key,
	ip text not null,
	port int,
	mac text,
	usr text,
	passwd text
);

create table config_rs485_tbl (
	dev_id int not null primary key,
	port int not null,
	addr text not null,
	baund int not null,
	parity int not null,
	data int not null,
	stop int not null
);

create table run_rule_tbl(
	rule_uuid text primary key  not null,
	id serial not null,
	dev_type text not null,
	dev_id int not null,
	dev_channel int not null,
	method text not null,
	priority int not null,
	rule_param json not null,
	start_time time not null,
	end_time time not null,
	start_date date not null,
	end_date date not null,
	running int not null default(0)
);
create table program_info_tbl (
	program_id text not null primary key,
	program_url text not null,
	program_md5 text not null,
	download_time timestamp(0)
);