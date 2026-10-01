create warehouse if not exists data_wh with warehouse_size='x-small';

create database if not exists raw;
create schema if not exists raw.pol_trades;
create schema if not exists raw.testing;

create database if not exists staging;
create schema if not exists staging.pol_trades;
create schema if not exists staging.testing;

create database if not exists analytics;
create schema if not exists analytics.pol_trades;
create schema if not exists analytics.testing;
