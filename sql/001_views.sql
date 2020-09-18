CREATE DATABASE IF NOT EXISTS `ht`;
USE `ht`;

-- ht_repository views
CREATE OR REPLACE SQL SECURITY INVOKER VIEW `ht_users` AS SELECT * FROM `ht_repository`.`ht_users`;
CREATE OR REPLACE SQL SECURITY INVOKER VIEW `ht_institutions` AS SELECT * FROM `ht_repository`.`ht_institutions`;
CREATE OR REPLACE SQL SECURITY INVOKER VIEW `access_stmts_map` AS SELECT * FROM `ht_repository`.`access_stmts_map`;
CREATE OR REPLACE SQL SECURITY INVOKER VIEW `access_stmts` AS SELECT * FROM `ht_repository`.`access_stmts`;


-- rights views
CREATE OR REPLACE SQL SECURITY INVOKER VIEW `access_profiles` AS SELECT * FROM `ht_rights`.`access_profiles`;
CREATE OR REPLACE SQL SECURITY INVOKER VIEW `attributes` AS SELECT * FROM `ht_rights`.`attributes`;
CREATE OR REPLACE SQL SECURITY INVOKER VIEW `reasons` AS SELECT * FROM `ht_rights`.`reasons`;
CREATE OR REPLACE SQL SECURITY INVOKER VIEW `sources` AS SELECT * FROM `ht_rights`.`sources`;
CREATE OR REPLACE SQL SECURITY INVOKER VIEW `rights_current` AS SELECT * FROM `ht_rights`.`rights_current`;
CREATE OR REPLACE SQL SECURITY INVOKER VIEW `rights_current` AS SELECT * FROM `ht_rights`.`rights_current`;

-- ht_web views
CREATE OR REPLACE SQL SECURITY INVOKER VIEW `ht_sessions` AS SELECT * FROM `ht_web`.`ht_sessions`;
CREATE OR REPLACE SQL SECURITY INVOKER VIEW `ht_counts` AS SELECT * FROM `ht_web`.`ht_counts`;
CREATE OR REPLACE SQL SECURITY INVOKER VIEW `pt_exclusivity` AS SELECT * FROM `ht_web`.`pt_exclusivity`;
CREATE OR REPLACE SQL SECURITY INVOKER VIEW `slip_host_control` AS SELECT * FROM `ht_web`.`slip_host_control`;
CREATE OR REPLACE SQL SECURITY INVOKER VIEW `slip_shard_control` AS SELECT * FROM `ht_web`.`slip_shard_control`;
CREATE OR REPLACE SQL SECURITY INVOKER VIEW `slip_errors` AS SELECT * FROM `ht_web`.`slip_errors`;
CREATE OR REPLACE SQL SECURITY INVOKER VIEW `slip_indexed` AS SELECT * FROM `ht_web`.`slip_indexed`;
CREATE OR REPLACE SQL SECURITY INVOKER VIEW `slip_queue` AS SELECT * FROM `ht_web`.`slip_queue`;
CREATE OR REPLACE SQL SECURITY INVOKER VIEW `slip_rate_stats` AS SELECT * FROM `ht_web`.`slip_rate_stats`;
CREATE OR REPLACE SQL SECURITY INVOKER VIEW `slip_shard_stats` AS SELECT * FROM `ht_web`.`slip_shard_stats`;
CREATE OR REPLACE SQL SECURITY INVOKER VIEW `slip_shared_queue` AS SELECT * FROM `ht_web`.`slip_shared_queue`;
CREATE OR REPLACE SQL SECURITY INVOKER VIEW `slip_timeouts` AS SELECT * FROM `ht_web`.`slip_timeouts`;
CREATE OR REPLACE SQL SECURITY INVOKER VIEW `slip_queue` AS SELECT * FROM `ht_web`.`slip_queue`;

