USE `ht`;
GRANT USAGE ON *.* TO 'ht_web'@'%' IDENTIFIED BY 'ht_web';
GRANT SELECT, INSERT, UPDATE, DELETE, LOCK TABLES ON `ht`.* TO 'ht_web'@'%';