USE `ht`;
GRANT USAGE ON *.* TO 'ht_web'@'%' IDENTIFIED BY 'ht_web';
GRANT SELECT ON `ht_rights`.* TO 'ht_web'@'%';
GRANT SELECT ON `ht_repository`.* TO 'ht_web'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE, LOCK TABLES ON `ht_web`.* TO 'ht_web'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE, LOCK TABLES ON `ht`.* TO 'ht_web'@'%';
