-- Optional identifiers do not replace the numeric parking/storage counts.
alter table public.units
 add column parking_number text not null default '' check (char_length(parking_number)<=120),
 add column storage_number text not null default '' check (char_length(storage_number)<=120);
