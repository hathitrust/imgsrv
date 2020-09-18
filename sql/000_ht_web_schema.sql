CREATE DATABASE IF NOT EXISTS `ht_web`;

USE `ht_web`;

# ************************************************************
# Sequel Pro SQL dump
# Version 5446
#
# https://www.sequelpro.com/
# https://github.com/sequelpro/sequelpro
#
# Host: 127.0.0.1 (MySQL 5.5.5-10.1.44-MariaDB-0+deb9u1)
# Database: ht_web
# Generation Time: 2020-08-11 21:39:52 +0000
# ************************************************************


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
SET NAMES utf8mb4;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;


# Dump of table ht_sessions
# ------------------------------------------------------------

DROP TABLE IF EXISTS `ht_sessions`;

CREATE TABLE `ht_sessions` (
  `id` varchar(32) NOT NULL DEFAULT '',
  `a_session` longblob,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;


DROP TABLE IF EXISTS `ht_counts`;
CREATE TABLE `ht_counts` (
  `userid` varchar(256) NOT NULL DEFAULT '',
  `accesscount` int(11) NOT NULL DEFAULT '0',
  `last_access` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `warned` tinyint(1) NOT NULL DEFAULT '0',
  `certified` tinyint(1) NOT NULL DEFAULT '0',
  `auth_requested` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`userid`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

# Dump of table pt_exclusivity
# ------------------------------------------------------------

DROP TABLE IF EXISTS `pt_exclusivity`;

CREATE TABLE `pt_exclusivity` (
  `item_id` varchar(32) NOT NULL DEFAULT '',
  `owner` varchar(256) NOT NULL DEFAULT '',
  `affiliation` varchar(128) NOT NULL DEFAULT '',
  `expires` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`item_id`,`owner`,`affiliation`),
  KEY `affiliation_check` (`item_id`,`affiliation`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 ROW_FORMAT=DYNAMIC;


# Dump of table slip_host_control
# ------------------------------------------------------------

DROP TABLE IF EXISTS `slip_host_control`;

CREATE TABLE `slip_host_control` (
  `run` smallint(3) NOT NULL DEFAULT '0',
  `host` varchar(32) NOT NULL DEFAULT '',
  `num_producers` smallint(2) NOT NULL DEFAULT '0',
  `num_running` smallint(2) NOT NULL DEFAULT '0',
  `enabled` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`run`,`host`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

LOCK TABLES `slip_host_control` WRITE;
/*!40000 ALTER TABLE `slip_host_control` DISABLE KEYS */;

INSERT INTO `slip_host_control` (`run`, `host`, `num_producers`, `num_running`, `enabled`)
VALUES
  (1,'bar',4,0,0),
  (1,'foo',4,0,0),
  (2,'bar',4,0,0),
  (2,'foo',4,0,0),
  (10,'grog',24,0,0),
  (10,'macc-ht-ingest-000',24,0,0),
  (10,'macc-ht-ingest-001',24,0,0),
  (10,'macc-ht-ingest-002',24,0,0),
  (10,'macc-ht-ingest-003',24,0,0),
  (11,'grog',24,0,0),
  (11,'macc-ht-ingest-000',24,0,0),
  (11,'macc-ht-ingest-001',24,0,0),
  (11,'macc-ht-ingest-002',24,0,0),
  (11,'macc-ht-ingest-003',24,0,0),
  (12,'earlgrey-1',24,0,1),
  (12,'earlgrey-2',24,0,1),
  (12,'earlgrey-3',24,0,1),
  (12,'earlgrey-4',24,0,1),
  (12,'grog',24,0,1),
  (20,'grog',1,1,1),
  (21,'assam',1,0,1),
  (21,'bancha',1,0,1),
  (21,'grog',0,0,1),
  (21,'hic',0,0,1),
  (21,'hic-jessie',0,0,1),
  (21,'ht-web-testing',0,0,1),
  (21,'koolaid-10',0,0,1),
  (21,'koolaid-11',1,0,1),
  (21,'koolaid-12',0,0,1),
  (21,'lassi',1,0,1),
  (21,'macc-ht-web-000',0,0,1),
  (21,'macc-ht-web-001',0,0,1),
  (21,'macc-ht-web-002',0,0,1),
  (21,'macc-ht-web-003',0,0,1),
  (21,'macc-ht-web-004',0,0,1),
  (21,'macc-ht-web-005',0,0,1),
  (21,'macc-ht-web-006',0,0,1),
  (21,'macc-ht-web-007',0,0,1),
  (21,'macc-ht-web-008',0,0,1),
  (21,'macc-ht-web-009',0,0,1),
  (21,'macc-ht-web-010',0,0,1),
  (21,'macc-ht-web-011',0,0,1),
  (21,'moxie-1',0,0,1),
  (21,'moxie-2',0,0,1),
  (21,'moxie-3',0,0,1),
  (21,'sharbat',1,0,1),
  (22,'assam',1,0,1),
  (22,'bancha',1,0,1),
  (22,'ictc-ht-web-000',0,0,1),
  (22,'ictc-ht-web-001',0,0,1),
  (22,'ictc-ht-web-002',0,0,1),
  (22,'ictc-ht-web-003',0,0,1),
  (22,'ictc-ht-web-004',0,0,1),
  (22,'ictc-ht-web-005',0,0,1),
  (22,'ictc-ht-web-006',0,0,1),
  (22,'ictc-ht-web-007',0,0,1),
  (22,'ictc-ht-web-008',0,0,1),
  (22,'ictc-ht-web-009',0,0,1),
  (22,'ictc-ht-web-010',0,0,1),
  (22,'ictc-ht-web-011',0,0,1),
  (22,'koolaid-11',1,0,1),
  (22,'lassi',1,0,1),
  (22,'rootbeer-1',0,0,1),
  (22,'rootbeer-2',0,0,1),
  (22,'rootbeer-3',0,0,1),
  (22,'sharbat',1,0,1),
  (60,'grog',24,1,1),
  (61,'grog',10,1,1),
  (61,'macc-ht-ingest-000',10,0,1),
  (61,'macc-ht-ingest-001',10,1,1),
  (61,'macc-ht-ingest-002',10,0,1),
  (61,'macc-ht-ingest-003',10,1,1),
  (63,'earlgrey-1',24,1,1),
  (63,'earlgrey-2',24,2,1),
  (63,'earlgrey-3',24,0,1),
  (63,'earlgrey-4',24,4,1),
  (63,'grog',0,0,1),
  (101,'grog',10,0,1),
  (101,'macc-ht-ingest-000',10,0,1),
  (101,'macc-ht-ingest-001',10,1,1),
  (101,'macc-ht-ingest-002',10,0,1),
  (101,'macc-ht-ingest-003',10,0,1);

/*!40000 ALTER TABLE `slip_host_control` ENABLE KEYS */;
UNLOCK TABLES;


# Dump of table slip_shard_control
# ------------------------------------------------------------

DROP TABLE IF EXISTS `slip_shard_control`;

CREATE TABLE `slip_shard_control` (
  `run` smallint(3) NOT NULL DEFAULT '0',
  `shard` smallint(2) NOT NULL DEFAULT '0',
  `enabled` tinyint(1) NOT NULL DEFAULT '0',
  `selected` tinyint(1) NOT NULL DEFAULT '0',
  `num_producers` smallint(2) NOT NULL DEFAULT '0',
  `allocated` smallint(2) NOT NULL DEFAULT '0',
  `build` tinyint(1) NOT NULL DEFAULT '0',
  `optimiz` tinyint(1) NOT NULL DEFAULT '0',
  `checkd` tinyint(1) NOT NULL DEFAULT '0',
  `build_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `optimize_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `checkd_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `release_state` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`run`,`shard`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

LOCK TABLES `slip_shard_control` WRITE;
/*!40000 ALTER TABLE `slip_shard_control` DISABLE KEYS */;

INSERT INTO `slip_shard_control` (`run`, `shard`, `enabled`, `selected`, `num_producers`, `allocated`, `build`, `optimiz`, `checkd`, `build_time`, `optimize_time`, `checkd_time`, `release_state`)
VALUES
  (10,1,0,0,8,0,0,0,0,'0000-00-00 00:00:00','0000-00-00 00:00:00','0000-00-00 00:00:00',0),
  (10,2,0,0,8,0,0,0,0,'0000-00-00 00:00:00','0000-00-00 00:00:00','0000-00-00 00:00:00',0),
  (10,3,0,0,8,0,0,0,0,'0000-00-00 00:00:00','0000-00-00 00:00:00','0000-00-00 00:00:00',0),
  (10,4,0,0,8,0,0,0,0,'0000-00-00 00:00:00','0000-00-00 00:00:00','0000-00-00 00:00:00',0),
  (10,5,0,0,8,0,0,0,0,'0000-00-00 00:00:00','0000-00-00 00:00:00','0000-00-00 00:00:00',0),
  (10,6,0,0,8,0,0,0,0,'0000-00-00 00:00:00','0000-00-00 00:00:00','0000-00-00 00:00:00',0),
  (10,7,0,0,8,0,0,0,0,'0000-00-00 00:00:00','0000-00-00 00:00:00','0000-00-00 00:00:00',0),
  (10,8,0,0,8,0,0,0,0,'0000-00-00 00:00:00','0000-00-00 00:00:00','0000-00-00 00:00:00',0),
  (10,9,0,0,8,0,0,0,0,'0000-00-00 00:00:00','0000-00-00 00:00:00','0000-00-00 00:00:00',0),
  (10,10,0,0,8,0,0,0,0,'0000-00-00 00:00:00','0000-00-00 00:00:00','0000-00-00 00:00:00',0),
  (10,11,0,0,8,0,0,0,0,'0000-00-00 00:00:00','0000-00-00 00:00:00','0000-00-00 00:00:00',0),
  (10,12,0,0,8,0,0,0,0,'0000-00-00 00:00:00','0000-00-00 00:00:00','0000-00-00 00:00:00',0),
  (11,1,0,0,8,0,0,0,0,'2020-08-11 04:59:13','2020-08-11 05:11:16','2020-08-11 05:13:01',1),
  (11,2,0,0,8,0,0,0,0,'2020-08-11 04:59:13','2020-08-11 05:10:47','2020-08-11 05:13:01',1),
  (11,3,0,0,8,0,0,0,0,'2020-08-11 04:59:13','2020-08-11 05:10:52','2020-08-11 05:13:01',1),
  (11,4,0,0,8,0,0,0,0,'2020-08-11 04:59:13','2020-08-11 05:11:17','2020-08-11 05:13:01',1),
  (11,5,0,0,8,0,0,0,0,'2020-08-11 04:59:13','2020-08-11 05:11:18','2020-08-11 05:13:01',1),
  (11,6,0,0,8,0,0,0,0,'2020-08-11 04:59:13','2020-08-11 05:11:45','2020-08-11 05:13:01',1),
  (11,7,0,0,8,0,0,0,0,'2020-08-11 04:59:13','2020-08-11 05:11:09','2020-08-11 05:13:01',1),
  (11,8,0,0,8,0,0,0,0,'2020-08-11 04:59:13','2020-08-11 05:11:22','2020-08-11 05:13:01',1),
  (11,9,0,0,8,0,0,0,0,'2020-08-11 04:59:13','2020-08-11 05:09:33','2020-08-11 05:13:01',1),
  (11,10,0,0,8,0,0,0,0,'2020-08-11 04:59:13','2020-08-11 05:10:36','2020-08-11 05:13:01',1),
  (11,11,0,0,8,0,0,0,0,'2020-08-11 04:59:13','2020-08-11 05:10:50','2020-08-11 05:13:01',1),
  (11,12,0,0,8,0,0,0,0,'2020-08-11 04:59:13','2020-08-11 05:11:31','2020-08-11 05:13:01',1),
  (12,1,1,0,8,2,0,1,0,'0000-00-00 00:00:00','2019-01-28 13:00:11','0000-00-00 00:00:00',0),
  (12,2,1,0,8,5,0,1,0,'0000-00-00 00:00:00','2019-01-28 13:33:14','0000-00-00 00:00:00',0),
  (12,3,1,0,8,5,0,1,0,'0000-00-00 00:00:00','2019-01-28 13:59:19','0000-00-00 00:00:00',0),
  (12,4,1,0,8,5,0,1,0,'0000-00-00 00:00:00','2019-01-28 14:27:41','0000-00-00 00:00:00',0),
  (12,5,1,0,8,0,0,1,0,'0000-00-00 00:00:00','2019-01-28 14:58:17','0000-00-00 00:00:00',0),
  (12,6,1,0,8,5,0,1,0,'0000-00-00 00:00:00','2019-01-28 15:25:50','0000-00-00 00:00:00',0),
  (12,7,1,0,8,2,0,1,0,'0000-00-00 00:00:00','2019-01-28 15:53:05','0000-00-00 00:00:00',0),
  (12,8,1,0,8,1,0,1,0,'0000-00-00 00:00:00','2019-01-28 16:23:53','0000-00-00 00:00:00',0),
  (12,9,1,0,8,0,0,1,0,'0000-00-00 00:00:00','2019-01-28 16:51:14','0000-00-00 00:00:00',0),
  (12,10,1,0,8,0,0,1,0,'0000-00-00 00:00:00','2019-01-28 17:18:08','0000-00-00 00:00:00',0),
  (12,11,1,0,8,2,0,1,0,'0000-00-00 00:00:00','2019-01-28 17:43:55','0000-00-00 00:00:00',0),
  (12,12,1,0,8,5,0,1,0,'0000-00-00 00:00:00','2019-01-28 18:24:53','0000-00-00 00:00:00',0),
  (12,13,1,0,6,0,0,0,0,'0000-00-00 00:00:00','0000-00-00 00:00:00','2016-05-03 00:00:00',0),
  (12,14,1,0,6,0,0,0,0,'0000-00-00 00:00:00','0000-00-00 00:00:00','2016-05-03 00:00:00',0),
  (12,15,1,0,6,0,0,0,0,'0000-00-00 00:00:00','0000-00-00 00:00:00','2016-05-03 00:00:00',0),
  (12,16,1,0,6,0,0,0,0,'0000-00-00 00:00:00','0000-00-00 00:00:00','2016-05-03 00:00:00',0),
  (12,17,1,0,6,0,0,0,0,'0000-00-00 00:00:00','0000-00-00 00:00:00','2016-05-03 00:00:00',0),
  (12,18,1,0,6,0,0,0,0,'0000-00-00 00:00:00','0000-00-00 00:00:00','2016-05-03 00:00:00',0),
  (20,1,1,0,1,0,0,0,0,'0000-00-00 00:00:00','0000-00-00 00:00:00','2016-05-03 00:00:00',0),
  (60,1,1,0,12,1,0,0,0,'0000-00-00 00:00:00','0000-00-00 00:00:00','0000-00-00 00:00:00',0),
  (60,2,1,0,12,0,0,0,0,'0000-00-00 00:00:00','0000-00-00 00:00:00','0000-00-00 00:00:00',0),
  (60,3,1,0,12,11,0,0,0,'0000-00-00 00:00:00','0000-00-00 00:00:00','0000-00-00 00:00:00',0),
  (60,4,1,0,12,10,0,0,0,'0000-00-00 00:00:00','0000-00-00 00:00:00','0000-00-00 00:00:00',0),
  (60,5,1,0,12,3,0,0,0,'0000-00-00 00:00:00','0000-00-00 00:00:00','0000-00-00 00:00:00',0),
  (60,6,1,0,12,8,0,0,0,'0000-00-00 00:00:00','0000-00-00 00:00:00','0000-00-00 00:00:00',0),
  (60,7,1,0,12,5,0,0,0,'0000-00-00 00:00:00','0000-00-00 00:00:00','0000-00-00 00:00:00',0),
  (60,8,1,0,12,5,0,0,0,'0000-00-00 00:00:00','0000-00-00 00:00:00','0000-00-00 00:00:00',0),
  (61,1,1,0,50,40,0,1,0,'0000-00-00 00:00:00','2020-02-07 05:46:53','0000-00-00 00:00:00',0),
  (63,1,1,0,96,4,0,0,0,'0000-00-00 00:00:00','0000-00-00 00:00:00','0000-00-00 00:00:00',0),
  (101,1,1,0,50,28,0,0,0,'0000-00-00 00:00:00','0000-00-00 00:00:00','0000-00-00 00:00:00',0);

/*!40000 ALTER TABLE `slip_shard_control` ENABLE KEYS */;
UNLOCK TABLES;

# Dump of table slip_errors
# ------------------------------------------------------------

DROP TABLE IF EXISTS `slip_errors`;

CREATE TABLE `slip_errors` (
  `run` smallint(3) NOT NULL DEFAULT '0',
  `shard` smallint(2) NOT NULL DEFAULT '0',
  `id` varchar(32) NOT NULL DEFAULT '',
  `pid` int(11) NOT NULL DEFAULT '0',
  `host` varchar(32) NOT NULL DEFAULT '',
  `error_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `reason` tinyint(1) DEFAULT NULL,
  PRIMARY KEY (`run`,`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;



# Dump of table slip_indexed
# ------------------------------------------------------------

DROP TABLE IF EXISTS `slip_indexed`;

CREATE TABLE `slip_indexed` (
  `run` smallint(3) NOT NULL DEFAULT '0',
  `shard` smallint(2) NOT NULL DEFAULT '0',
  `id` varchar(32) NOT NULL DEFAULT '',
  `time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `indexed_ct` smallint(3) NOT NULL DEFAULT '0',
  PRIMARY KEY (`run`,`shard`,`id`),
  KEY `id` (`id`),
  KEY `runshard` (`run`,`shard`),
  KEY `run` (`run`),
  KEY `run_indexed_ct` (`run`,`indexed_ct`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;



# Dump of table slip_queue
# ------------------------------------------------------------

DROP TABLE IF EXISTS `slip_queue`;

CREATE TABLE `slip_queue` (
  `run` smallint(3) NOT NULL DEFAULT '0',
  `shard` smallint(2) NOT NULL DEFAULT '0',
  `id` varchar(32) NOT NULL DEFAULT '',
  `pid` int(11) NOT NULL DEFAULT '0',
  `host` varchar(32) NOT NULL DEFAULT '',
  `proc_status` smallint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`run`,`shard`,`id`),
  KEY `run` (`run`),
  KEY `id` (`id`),
  KEY `pid` (`pid`),
  KEY `host` (`host`),
  KEY `proc_status` (`proc_status`),
  KEY `runstatus` (`run`,`proc_status`),
  KEY `runshardstatus` (`run`,`shard`,`proc_status`),
  KEY `runstatus_shard` (`run`,`proc_status`,`shard`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;



# Dump of table slip_rate_stats
# ------------------------------------------------------------

DROP TABLE IF EXISTS `slip_rate_stats`;

CREATE TABLE `slip_rate_stats` (
  `run` smallint(3) NOT NULL DEFAULT '0',
  `shard` smallint(2) NOT NULL DEFAULT '0',
  `time_a_100` int(11) NOT NULL DEFAULT '0',
  `rate_a_100` float NOT NULL DEFAULT '0',
  PRIMARY KEY (`run`,`shard`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;



# Dump of table slip_shard_stats
# ------------------------------------------------------------

DROP TABLE IF EXISTS `slip_shard_stats`;

CREATE TABLE `slip_shard_stats` (
  `run` smallint(3) NOT NULL DEFAULT '0',
  `shard` smallint(2) NOT NULL DEFAULT '0',
  `s_reindexed_ct` int(11) NOT NULL DEFAULT '0',
  `s_deleted_ct` int(11) NOT NULL DEFAULT '0',
  `s_errored_ct` int(11) NOT NULL DEFAULT '0',
  `s_num_docs` int(11) NOT NULL DEFAULT '0',
  `s_doc_size` bigint(20) NOT NULL DEFAULT '0',
  `s_doc_time` float NOT NULL DEFAULT '0',
  `s_idx_time` float NOT NULL DEFAULT '0',
  `s_tot_time` float NOT NULL DEFAULT '0',
  PRIMARY KEY (`run`,`shard`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;



# Dump of table slip_shared_queue
# ------------------------------------------------------------

DROP TABLE IF EXISTS `slip_shared_queue`;

CREATE TABLE `slip_shared_queue` (
  `id` varchar(32) NOT NULL DEFAULT '',
  `time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;



# Dump of table slip_timeouts
# ------------------------------------------------------------

DROP TABLE IF EXISTS `slip_timeouts`;

CREATE TABLE `slip_timeouts` (
  `run` smallint(3) NOT NULL DEFAULT '0',
  `id` varchar(32) NOT NULL DEFAULT '',
  `shard` smallint(2) NOT NULL DEFAULT '0',
  `pid` int(11) NOT NULL DEFAULT '0',
  `host` varchar(32) NOT NULL DEFAULT '',
  `timeout_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00'
) ENGINE=InnoDB DEFAULT CHARSET=latin1;




/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;
/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
